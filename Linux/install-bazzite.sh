#!/usr/bin/env bash
set -uo pipefail

# Bazzite / Silverblue setup script.
# Re-runnable, idempotent, add-only. Desired state lives in the arrays below;
# edit them and commit to change what a fresh install looks like.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/install.sh"
source "$SCRIPT_DIR/lib/repos.sh"
source "$SCRIPT_DIR/lib/config.sh"

# ─── Package Lists ────────────────────────────────────────────────────────────

RPM_PACKAGES=(
    "podman-compose"
    "brave-browser"
    "1password"
    "code"
    "proton-vpn-gnome-desktop"
    "gnome-shell-extension-dash-to-panel"
    "gnome-shell-extension-dash-to-dock"
    "zsh"
    "piper"
    "claude-desktop"
)

FLATPAK_PACKAGES=(
    "com.discordapp.Discord"
    "org.gnome.baobab"
    "com.mattjakeman.ExtensionManager"
    "com.github.tchx84.Flatseal"
    "org.gimp.GIMP"
    "org.libreoffice.LibreOffice"
    "io.missioncenter.MissionCenter"
    "com.nextcloud.desktopclient.nextcloud"
    "org.gnome.World.PikaBackup"
    "io.github.fabrialberio.pinapp"
    "dev.dergs.Tonearm"
    "io.github.flattool.Warehouse"
    "io.gitlab.news_flash.NewsFlash"
    "it.mijorus.gearlever"
    "io.gitlab.adhami3310.Converter"
    "io.github.alainm23.planify"
    "com.bilingify.readest"
    "com.github.johnfactotum.Foliate"
    "com.calibre_ebook.calibre"
    "com.github.Matoking.protontricks"
    "com.vysp3r.ProtonPlus"
    "fr.handbrake.ghb"
    "im.riot.Riot"
    "io.github.wartybix.Constrict"
    "org.fedoraproject.MediaWriter"
    "org.gnome.Firmware"
    "org.localsend.localsend_app"
    "org.signal.Signal"
    "org.zotero.Zotero"
)

GNOME_EXTENSIONS=(
    "tilingshell@ferrarodomenico.com"
    "copyous@boerdereinar.dev"
    "hide-minimized@danigm.net"
    "quick-settings-audio-panel@rayzeq.github.io"
    "quicksettings-audio-devices-renamer@marcinjahn.com"
)

CLI_TOOLS=(
    "brew"
    "zsh-setup"
    "claude"
)

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    info "Bazzite Setup"

    # Preflight
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [[ "${ID:-}" != "bazzite" && "${VARIANT_ID:-}" != "bazzite" ]]; then
            warn "Not running on Bazzite (ID=${ID:-?} VARIANT_ID=${VARIANT_ID:-?})."
            confirm "Continue anyway?" || exit 1
        fi
    fi

    mapfile -t rpm_to_install   < <(filter_to_install is_rpm_installed     "${RPM_PACKAGES[@]}")
    mapfile -t flatpak_to_install < <(filter_to_install is_flatpak_installed "${FLATPAK_PACKAGES[@]}")
    mapfile -t gext_to_install  < <(filter_to_install is_gext_installed    "${GNOME_EXTENSIONS[@]}")
    mapfile -t cli_to_install   < <(filter_to_install is_cli_installed     "${CLI_TOOLS[@]}")

    echo
    info "Plan:"
    printf '  %-22s %s\n' "RPM (rpm-ostree):"   "${rpm_to_install[*]:-(nothing to install)}"
    printf '  %-22s %s\n' "Flatpaks:"           "${flatpak_to_install[*]:-(nothing to install)}"
    printf '  %-22s %s\n' "GNOME extensions:"   "${gext_to_install[*]:-(nothing to install)}"
    printf '  %-22s %s\n' "CLI tools:"          "${cli_to_install[*]:-(nothing to install)}"
    printf '  %-22s %s\n' "Configs:"            "brave policy, 1password, desktop overrides, PWAs, autostart, audio, GNOME shell, Ptyxis"
    echo

    confirm "Proceed?" || { warn "Cancelled."; exit 0; }

    local needs_reboot=false

    # RPM via rpm-ostree — expand grouped keys (e.g. "libgda libgda-sqlite")
    if [[ ${#rpm_to_install[@]} -gt 0 ]]; then
        local -a rpm_pkgs=()
        local group pkg
        for group in "${rpm_to_install[@]}"; do
            for pkg in $group; do
                ensure_repo "$pkg"
                rpm_pkgs+=("$pkg")
            done
        done
        info "Layering system packages"
        sudo rpm-ostree install --idempotent "${rpm_pkgs[@]}"
        needs_reboot=true
        ok "System packages layered"
    fi

    # Flatpaks
    if [[ ${#flatpak_to_install[@]} -gt 0 ]]; then
        info "Installing Flatpaks"
        flatpak install -y --noninteractive flathub "${flatpak_to_install[@]}"
        ok "Flatpaks installed"
    fi

    # GNOME extensions
    if [[ ${#gext_to_install[@]} -gt 0 ]]; then
        ensure_gext
        local ext
        for ext in "${gext_to_install[@]}"; do
            info "Installing extension $ext"
            gext install "$ext"
        done
    fi

    # CLI tools
    if [[ ${#cli_to_install[@]} -gt 0 ]]; then
        local tool
        for tool in "${cli_to_install[@]}"; do
            info "Installing $tool"
            install_cli_tool "$tool"
        done
    fi

    # ── Config steps — always applied, self-skip missing sources ──────────────
    if is_rpm_installed brave-browser; then
        run_config_brave_policy
    fi
    if is_rpm_installed 1password; then
        run_config_1password
    fi
    run_config_audio
    run_config_desktop_overrides
    run_config_pwa
    run_config_autostart
    run_config_gnome_shell
    run_config_ptyxis

    echo
    ok "All done!"

    if $needs_reboot; then
        echo
        warn "rpm-ostree changes require a reboot before layered packages become live."
        warn "Re-run this script after reboot so config steps can touch the newly installed apps."
        if confirm "Reboot now?"; then
            systemctl reboot
        fi
    fi
}

main "$@"
