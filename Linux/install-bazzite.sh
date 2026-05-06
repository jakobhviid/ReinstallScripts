#!/usr/bin/env bash
set -uo pipefail

# Bazzite / Silverblue setup script.
# Re-runnable, idempotent, add-only. The system layer (rpm-ostree packages,
# custom RPM repos, GNOME extensions) lives in the arrays below; the userspace
# layer (formulae, casks, taps, flatpaks) lives in Brewfile.<machine> and is
# applied via `brew bundle`.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/install.sh"
source "$SCRIPT_DIR/lib/repos.sh"
source "$SCRIPT_DIR/lib/config.sh"

MACHINE="${1:-chronos-redux}"
BREWFILE="$SCRIPT_DIR/brewfiles/Brewfile.${MACHINE}"

# ─── System Layer (rpm-ostree + GNOME extensions) ─────────────────────────────

RPM_PACKAGES=(
    "podman-compose"
    "brave-browser"
    "1password"
    "proton-vpn-gnome-desktop"
    "gnome-shell-extension-dash-to-panel"
    "gnome-shell-extension-dash-to-dock"
    "zsh"
    "claude-desktop"
    "zen-browser"
)

GNOME_EXTENSIONS=(
    "tilingshell@ferrarodomenico.com"
    "copyous@boerdereinar.dev"
    "hide-minimized@danigm.net"
    "quick-settings-audio-panel@rayzeq.github.io"
    "quicksettings-audio-devices-renamer@marcinjahn.com"
    "CoverflowAltTab@palatis.blogspot.com"
)

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    info "Bazzite Setup (machine: $MACHINE)"

    # Preflight
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [[ "${ID:-}" != "bazzite" && "${VARIANT_ID:-}" != "bazzite" ]]; then
            warn "Not running on Bazzite (ID=${ID:-?} VARIANT_ID=${VARIANT_ID:-?})."
            confirm "Continue anyway?" || exit 1
        fi
    fi

    if [[ ! -f "$BREWFILE" ]]; then
        err "Brewfile not found: $BREWFILE"
        err "Pass machine name as first arg: $0 <machine>"
        exit 1
    fi

    mapfile -t rpm_to_install   < <(filter_to_install is_rpm_installed     "${RPM_PACKAGES[@]}")
    mapfile -t gext_to_install  < <(filter_to_install is_gext_installed    "${GNOME_EXTENSIONS[@]}")

    local brew_action="present"
    is_cli_installed brew      || brew_action="install Homebrew"
    local zsh_action="present"
    is_cli_installed zsh-setup || zsh_action="run just zsh"

    echo
    info "Plan:"
    printf '  %-22s %s\n' "RPM (rpm-ostree):"   "${rpm_to_install[*]:-(nothing to install)}"
    printf '  %-22s %s\n' "GNOME extensions:"   "${gext_to_install[*]:-(nothing to install)}"
    printf '  %-22s %s\n' "Homebrew:"           "$brew_action"
    printf '  %-22s %s\n' "Brewfile:"           "$(basename "$BREWFILE")"
    printf '  %-22s %s\n' "Zsh setup:"          "$zsh_action"
    printf '  %-22s %s\n' "Configs:"            "brave policy, 1password, desktop overrides, PWAs, autostart, localsend, audio, unlock services, GNOME shell, Ptyxis"
    echo

    confirm "Proceed?" || { warn "Cancelled."; exit 0; }

    local needs_reboot=false

    # rpm-ostree — expand grouped keys (e.g. "libgda libgda-sqlite")
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

    # Bootstrap brew if missing
    if ! is_cli_installed brew; then
        info "Installing Homebrew"
        install_cli_tool brew
    fi

    # Brewfile — userspace formulae, casks, taps, flatpaks
    info "Applying Brewfile ($MACHINE)"
    brew bundle --file="$BREWFILE"
    ok "Brewfile applied"

    # GNOME extensions
    if [[ ${#gext_to_install[@]} -gt 0 ]]; then
        ensure_gext
        local ext
        for ext in "${gext_to_install[@]}"; do
            info "Installing extension $ext"
            gext install "$ext"
        done
    fi

    # Zsh setup (config templating + git identity + tmux/tpm)
    if ! is_cli_installed zsh-setup; then
        info "Setting up Zsh"
        install_cli_tool zsh-setup
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
    run_config_localsend
    run_config_unlock_services
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

main
