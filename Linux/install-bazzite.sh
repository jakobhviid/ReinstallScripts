#!/usr/bin/env bash
set -uo pipefail

# Bazzite setup script — phase-aware.
#
# Phase 1 (auto-detected: machine NOT yet rebased to bazzite-custom image):
#   1. Install vendored cosign public key to /etc/pki/containers/
#   2. Add registries.d entry + policy.json trust rule for the signed image
#   3. Layer proton-vpn-gnome-desktop and rebase signed in one rpm-ostree call
#   4. Prompt to reboot
#
# Phase 2 (auto-detected: already on the bazzite-custom image):
#   1. Bootstrap brew + just if missing
#   2. brew bundle install --file=brewfiles/Brewfile.<machine>
#   3. Install GNOME extensions via gext
#   4. just zsh (templates ~/.zshrc, tmux, starship, git identity, plugins)
#   5. Per-user run_config_* (1Password keybinding/desktop, app icon
#      overrides, PWAs, autostart, LocalSend dark titlebar, GNOME shell +
#      Ptyxis dconf snapshots)
#
# Why split? The custom image at ghcr.io/jakobhviid/bazzite-{custom,nvidia-custom}
# bakes most of what this script used to do at the system layer (browsers,
# 1Password, Claude Desktop, dash-to-panel/dock, CLI baseline, brave policy,
# 1pw allowed-browsers, wireplumber renames, three unlock services, 33
# preinstalled flatpaks). After rebase, this script's job shrinks to: layer
# proton-vpn (which can't be image-baked due to a systemd scriptlet failure
# in the build container) + per-user state that can't go in an immutable
# image. See bazzite-custom/README.md gotcha #2 for the proton-vpn detail.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/install.sh"
source "$SCRIPT_DIR/lib/repos.sh"
source "$SCRIPT_DIR/lib/config.sh"

# Pick a machine: explicit arg wins; otherwise picker over machines that have
# a brewfile (Phase 2 needs one; Phase 1 doesn't, so for a fresh machine
# that doesn't have a brewfile yet, pass the name as arg explicitly).
if [[ -n "${1:-}" ]]; then
    MACHINE="$1"
else
    mapfile -t _choices < <(ls "$SCRIPT_DIR/brewfiles/Brewfile."* 2>/dev/null | xargs -n1 basename | sed 's/Brewfile\.//')
    if [[ ${#_choices[@]} -eq 0 ]]; then
        err "No Brewfiles found in $SCRIPT_DIR/brewfiles/ — pass a machine name as arg for Phase 1, or add a Brewfile.<machine> for Phase 2"
        exit 1
    fi
    MACHINE=$(pick_machine "Pick a machine (number or name): " "${_choices[@]}")
    if [[ -z "$MACHINE" ]]; then
        err "No machine selected, exiting."
        exit 1
    fi
fi
BREWFILE="$SCRIPT_DIR/brewfiles/Brewfile.${MACHINE}"

# True if the current rpm-ostree deployment's origin is on one of our
# bazzite-custom image variants. Pattern matches just the URL path because
# rpm-ostree normalizes the URI scheme — you may rebase via
# `ostree-image-signed:registry:…` but status records it back as
# `ostree-image-signed:docker://…`. So anchoring the match on `registry:`
# (as the original code did) never matched a real rebased deployment, which
# made install-bazzite.sh re-trigger Phase 1 on every run.
is_on_custom_image() {
    local current
    current=$(rpm-ostree status --json 2>/dev/null \
        | jq -r '.deployments[0].origin // ""' 2>/dev/null)
    case "$current" in
        *ghcr.io/jakobhviid/bazzite-custom:latest*) return 0 ;;
        *ghcr.io/jakobhviid/bazzite-nvidia-custom:latest*) return 0 ;;
        *) return 1 ;;
    esac
}

# Detect NVIDIA hardware and prompt for image variant. Hardware detection
# preselects the sensible default; user can override (e.g. test the non-NVIDIA
# image on NVIDIA hardware, or vice versa). Replaced an earlier hardcoded
# machine→image case statement — too brittle for future machines and didn't
# allow per-invocation override.
pick_image_variant() {
    local has_nvidia=0
    if lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -qi nvidia; then
        has_nvidia=1
    fi

    local default_image
    if (( has_nvidia )); then
        default_image="bazzite-nvidia-custom"
        info "Detected NVIDIA GPU — default image: bazzite-nvidia-custom" >&2
    else
        default_image="bazzite-custom"
        info "No NVIDIA GPU detected — default image: bazzite-custom" >&2
    fi

    pick_choice "Image variant: " "$default_image" \
        "bazzite-custom" "bazzite-nvidia-custom"
}

# ─── System Layer (rpm-ostree + GNOME extensions) ─────────────────────────────
#
# RPM_PACKAGES used to be 9 entries; the bazzite-custom image now bakes 8 of
# them in (browsers, 1Password, Claude Desktop, dash-to-panel/dock, zsh,
# podman-compose). Only proton-vpn-gnome-desktop remains: its post-install
# scriptlet calls systemctl which fails in a build container, killing the
# whole dnf transaction. Layered here on the live system instead.
RPM_PACKAGES=(
    "proton-vpn-gnome-desktop"
)

GNOME_EXTENSIONS=(
    "tilingshell@ferrarodomenico.com"
    "copyous@boerdereinar.dev"
    "hide-minimized@danigm.net"
    "quick-settings-audio-panel@rayzeq.github.io"
    "quicksettings-audio-devices-renamer@marcinjahn.com"
    "CoverflowAltTab@palatis.blogspot.com"
)

# ─── Phase 1: cosign trust + signed rebase + proton-vpn layer ─────────────────

phase1_image_setup() {
    local image_name="$1"
    local image_url="ghcr.io/jakobhviid/${image_name}"
    local pub_key_src="$SCRIPT_DIR/assets/bazzite-custom.pub"

    info "Phase 1: cosign trust + signed rebase to ${image_name}"

    [[ -f "$pub_key_src" ]] \
        || { err "Vendored cosign pubkey missing: $pub_key_src"; exit 1; }
    command -v jq &>/dev/null \
        || { err "jq is required for policy.json editing (Bazzite ships it by default)"; exit 1; }

    # 1. Cosign public key on disk
    info "Installing cosign public key to /etc/pki/containers/bazzite-custom.pub"
    sudo install -d -m 0755 /etc/pki/containers
    sudo install -m 0644 "$pub_key_src" /etc/pki/containers/bazzite-custom.pub

    # 2. registries.d entry telling skopeo/podman/rpm-ostree where to look
    #    for sigstore signatures for the ghcr.io/jakobhviid namespace
    info "Configuring /etc/containers/registries.d/ for sigstore signatures"
    sudo install -d -m 0755 /etc/containers/registries.d
    sudo tee /etc/containers/registries.d/ghcr-jakobhviid.yaml >/dev/null <<'EOF'
docker:
  ghcr.io/jakobhviid:
    use-sigstore-attachments: true
EOF

    # 3. policy.json trust rule — JSON-aware merge with backup
    info "Adding trust rule to /etc/containers/policy.json"
    info "  (backup at /etc/containers/policy.json.bak.bazzite-custom on first run)"
    sudo cp -n /etc/containers/policy.json /etc/containers/policy.json.bak.bazzite-custom

    local rule_entry new_policy
    rule_entry=$(jq -n --arg key "/etc/pki/containers/bazzite-custom.pub" '[{
        "type": "sigstoreSigned",
        "keyPath": $key,
        "signedIdentity": {"type": "matchRepository"}
    }]')

    new_policy=$(sudo jq --argjson rule "$rule_entry" '
        .transports.docker["ghcr.io/jakobhviid/bazzite-custom"] = $rule
      | .transports.docker["ghcr.io/jakobhviid/bazzite-nvidia-custom"] = $rule
    ' /etc/containers/policy.json)

    if ! echo "$new_policy" | jq . >/dev/null 2>&1; then
        err "Generated policy.json is invalid — aborting (original untouched, backup at .bak.bazzite-custom)"
        exit 1
    fi
    echo "$new_policy" | sudo tee /etc/containers/policy.json >/dev/null
    ok "Trust rule installed for both image variants"

    # 4. Add proton-vpn repo before the rebase so rpm-ostree can resolve it
    info "Adding proton-vpn-gnome-desktop repo for the layered package"
    ensure_repo proton-vpn-gnome-desktop

    # 5. Rebase to the signed image. Then layer proton-vpn separately with
    # --idempotent so re-runs (or pre-existing proton-vpn requests from a
    # previous installation) are no-ops instead of hard errors.
    # `rpm-ostree rebase --install <pkg>` doesn't have an --idempotent
    # equivalent, so we can't use the combined form here.
    info "Rebasing to ostree-image-signed:registry:${image_url}:latest"
    sudo rpm-ostree rebase "ostree-image-signed:registry:${image_url}:latest"

    info "Layering proton-vpn-gnome-desktop (idempotent — no-op if already requested)"
    sudo rpm-ostree install --idempotent proton-vpn-gnome-desktop

    echo
    ok "Phase 1 complete. Reboot required for the new deployment to become active."
    warn "After reboot, re-run this script to do the per-user Phase 2 setup."
    if confirm "Reboot now?"; then
        systemctl reboot
    fi
}

# ─── Phase 2: brew + gext + per-user dotfiles + run_config_* ──────────────────

phase2_userspace() {
    if [[ ! -f "$BREWFILE" ]]; then
        err "Brewfile not found: $BREWFILE"
        err "Phase 2 needs brewfiles/Brewfile.${MACHINE} — create one (start by copying chronos-redux as a template)"
        exit 1
    fi

    mapfile -t rpm_to_install   < <(filter_to_install is_rpm_installed     "${RPM_PACKAGES[@]}")
    mapfile -t gext_to_install  < <(filter_to_install is_gext_installed    "${GNOME_EXTENSIONS[@]}")

    local brew_action="present"
    is_cli_installed brew      || brew_action="install Homebrew"
    local zsh_action="present"
    is_cli_installed zsh-setup || zsh_action="run just zsh"

    echo
    info "Phase 2 Plan:"
    printf '  %-22s %s\n' "RPM (rpm-ostree):"   "${rpm_to_install[*]:-(nothing to install)}"
    printf '  %-22s %s\n' "GNOME extensions:"   "${gext_to_install[*]:-(nothing to install)}"
    printf '  %-22s %s\n' "Homebrew:"           "$brew_action"
    printf '  %-22s %s\n' "Brewfile:"           "$(basename "$BREWFILE")"
    printf '  %-22s %s\n' "Zsh setup:"          "$zsh_action"
    printf '  %-22s %s\n' "Configs:"            "1password (per-user), desktop overrides, PWAs, autostart, localsend, GNOME shell, Ptyxis"
    echo

    confirm "Proceed?" || { warn "Cancelled."; exit 0; }

    local needs_reboot=false

    # rpm-ostree — only proton-vpn-gnome-desktop now (image bakes the rest).
    # Layering after Phase 1 is a no-op since Phase 1 already layered it; this
    # keeps the code path correct for users who skipped Phase 1 (e.g. manually
    # rebased) and never installed proton-vpn.
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

    # Bootstrap brew + just via bootstrap.sh (single source of truth).
    if ! is_cli_installed brew; then
        info "Bootstrapping Homebrew + just"
        "$SCRIPT_DIR/bootstrap.sh"
        # Load brew into this script's env so subsequent brew calls work.
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
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

    # ── Per-user config steps — image handles brave policy, audio renames,
    # ── and the three unlock services already; this is just the per-user state.
    if is_rpm_installed 1password; then
        run_config_1password
    fi
    run_config_desktop_overrides
    run_config_pwa
    run_config_autostart
    run_config_localsend
    run_config_gnome_shell
    run_config_ptyxis

    echo
    ok "Phase 2 complete!"

    if $needs_reboot; then
        echo
        warn "rpm-ostree changes require a reboot before layered packages become live."
        if confirm "Reboot now?"; then
            systemctl reboot
        fi
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    info "Bazzite Setup (machine: $MACHINE)"

    # Preflight — Bazzite check (loose: Fedora Silverblue would also work for Phase 2)
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [[ "${ID:-}" != "bazzite" && "${VARIANT_ID:-}" != "bazzite" ]]; then
            warn "Not running on Bazzite (ID=${ID:-?} VARIANT_ID=${VARIANT_ID:-?})."
            confirm "Continue anyway?" || exit 1
        fi
    fi

    if ! is_on_custom_image; then
        warn "Not on the custom image yet — running Phase 1 (trust setup + signed rebase + proton-vpn layer + reboot)."
        local image_name
        image_name=$(pick_image_variant)
        info "Target image: ghcr.io/jakobhviid/${image_name}:latest"
        phase1_image_setup "$image_name"
    else
        local current_image
        current_image=$(rpm-ostree status --json 2>/dev/null \
            | jq -r '.deployments[0].origin // ""' 2>/dev/null \
            | grep -oE 'bazzite-(nvidia-)?custom' | head -1)
        info "Already on ${current_image:-the custom image} — running Phase 2 (userspace setup)."
        phase2_userspace
    fi
}

main
