#!/usr/bin/env bash
set -uo pipefail

# Fedora Workstation setup script.
# Re-runnable, idempotent, add-only. Desired state lives in the arrays below;
# edit them and commit to change what a fresh install looks like.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/install.sh"
source "$SCRIPT_DIR/lib/repos.sh"
source "$SCRIPT_DIR/lib/config.sh"

# ─── Package Lists ────────────────────────────────────────────────────────────

DNF_PACKAGES=(
    "podman-docker"
    "podman-compose"
    "brave-browser"
    "1password"
    "code"
    "proton-vpn-gnome-desktop"
    "zsh"
    "distrobox"
    "piper"
    "claude-desktop"
    "nautilus-gsconnect"
    "file-roller-nautilus"
    "papers-nautilus"
    "gnome-tweaks"
    "sushi"
    "ffmpegthumbnailer"
    "htop"
    "unrar"
    "gnome-shell-extension-appindicator"
    "gnome-shell-extension-blur-my-shell"
    "gnome-shell-extension-caffeine"
    "gnome-shell-extension-dash-to-panel"
    "gnome-shell-extension-dash-to-dock"
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
    "CoverflowAltTab@palatis.blogspot.com"
    "tilingshell@ferrarodomenico.com"
    "compiz-alike-magic-lamp-effect@hermes83.github.com"
    "hotedge@jonathan.jdoda.ca"
    "restartto@tiagoporsch.github.io"
    "copyous@boerdereinar.dev"
)

CLI_TOOLS=(
    "brew"
    "zsh-setup"
    "claude"
)

# ─── Fedora-specific bootstrap ────────────────────────────────────────────────

setup_rpmfusion() {
    if ! rpm -q rpmfusion-free-release &>/dev/null; then
        info "Installing RPM Fusion repositories"
        sudo dnf install -y \
          "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
          "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
        ok "RPM Fusion installed"
    fi
}

setup_multimedia_codecs() {
    info "Setting up multimedia codecs"

    if ! rpm -q ffmpeg &>/dev/null; then
        sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
    fi

    sudo dnf install -y \
      gstreamer1-plugins-bad-freeworld \
      gstreamer1-plugins-ugly \
      gstreamer1-plugins-good-extras \
      gstreamer1-libav \
      libva libva-utils \
      lame lame-libs

    sudo dnf group install -y multimedia

    ok "Multimedia codecs installed"
}

# ─── Fedora-only post-install config ──────────────────────────────────────────

run_config_speaker_eq() {
    mkdir -p ~/.config/pipewire/pipewire.conf.d/
    local dest=~/.config/pipewire/pipewire.conf.d/speaker-eq.conf
    if [[ -f "$SCRIPT_DIR/assets/speaker-eq.conf" ]] && ! diff -q "$SCRIPT_DIR/assets/speaker-eq.conf" "$dest" &>/dev/null; then
        info "Installing speaker EQ"
        cp "$SCRIPT_DIR/assets/speaker-eq.conf" "$dest"
        systemctl --user restart pipewire pipewire-pulse
        sleep 1
        local node_id
        node_id=$(wpctl status 2>/dev/null | grep 'effect_input.speaker_eq' | head -1 | grep -o '[0-9]\+' | head -1)
        if [[ -n "$node_id" ]]; then
            wpctl set-default "$node_id"
        fi
        ok "Speaker EQ active"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    info "Fedora Workstation Setup"

    # Preflight
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [[ "${ID:-}" != "fedora" || "${VARIANT_ID:-workstation}" != "workstation" ]]; then
            warn "Not running on Fedora Workstation (ID=${ID:-?} VARIANT_ID=${VARIANT_ID:-?})."
            confirm "Continue anyway?" || exit 1
        fi
    fi

    setup_rpmfusion
    setup_multimedia_codecs

    mapfile -t dnf_to_install   < <(filter_to_install is_rpm_installed     "${DNF_PACKAGES[@]}")
    mapfile -t flatpak_to_install < <(filter_to_install is_flatpak_installed "${FLATPAK_PACKAGES[@]}")
    mapfile -t gext_to_install  < <(filter_to_install is_gext_installed    "${GNOME_EXTENSIONS[@]}")
    mapfile -t cli_to_install   < <(filter_to_install is_cli_installed     "${CLI_TOOLS[@]}")

    echo
    info "Plan:"
    printf '  %-22s %s\n' "DNF:"                "${dnf_to_install[*]:-(nothing to install)}"
    printf '  %-22s %s\n' "Flatpaks:"           "${flatpak_to_install[*]:-(nothing to install)}"
    printf '  %-22s %s\n' "GNOME extensions:"   "${gext_to_install[*]:-(nothing to install)}"
    printf '  %-22s %s\n' "CLI tools:"          "${cli_to_install[*]:-(nothing to install)}"
    printf '  %-22s %s\n' "Configs:"            "brave policy, 1password, desktop overrides, PWAs, autostart, audio, speaker EQ"
    echo

    confirm "Proceed?" || { warn "Cancelled."; exit 0; }

    # DNF — expand grouped keys
    if [[ ${#dnf_to_install[@]} -gt 0 ]]; then
        local -a dnf_pkgs=()
        local group pkg
        for group in "${dnf_to_install[@]}"; do
            for pkg in $group; do
                ensure_repo "$pkg"
                dnf_pkgs+=("$pkg")
            done
        done
        info "Installing system packages"
        sudo dnf install -y "${dnf_pkgs[@]}"
        ok "System packages installed"
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

    # Default shell
    if [[ -x /usr/bin/zsh ]] && [[ "$(basename "$SHELL")" != "zsh" ]]; then
        info "Setting Zsh as default shell"
        chsh -s /usr/bin/zsh
        ok "Zsh set as default shell (takes effect on next login)"
    fi

    # ── Config steps — always applied, self-skip missing sources ──────────────
    if rpm -q brave-browser &>/dev/null; then
        run_config_brave_policy
    fi
    if rpm -q 1password &>/dev/null; then
        run_config_1password
    fi
    run_config_audio
    run_config_speaker_eq
    run_config_desktop_overrides
    run_config_pwa
    run_config_autostart

    echo
    ok "All done!"
}

main "$@"
