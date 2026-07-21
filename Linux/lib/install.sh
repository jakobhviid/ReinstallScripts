# shellcheck shell=bash
# Package detection + install helpers.
# Depends on common.sh (info/ok/warn/err) being sourced first.
# Depends on caller having set SCRIPT_DIR (for install_zsh_setup → justfile).

# ─── Detection ────────────────────────────────────────────────────────────────

is_rpm_installed() {
    local pkg
    for pkg in $1; do
        rpm -q "$pkg" &>/dev/null || return 1
    done
}
is_flatpak_installed() { flatpak info "$1" &>/dev/null 2>&1; }
is_gext_installed()    { gnome-extensions list 2>/dev/null | grep -qF "$1"; }
is_cli_installed() {
    case "$1" in
        brew)      command -v brew &>/dev/null || [[ -d /home/linuxbrew/.linuxbrew ]] ;;
        zsh-setup) [[ -f "$HOME/.zshrc" ]] && command -v brew &>/dev/null && brew list starship &>/dev/null ;;
    esac
}

# filter_to_install <check_fn> <key>... — prints keys (one per line) that aren't already installed.
# Preserves input order. Used to build install lists + summary counts without the old TUI.
filter_to_install() {
    local check_fn="$1"
    shift
    local key
    for key in "$@"; do
        "$check_fn" "$key" || echo "$key"
    done
}

# ─── GNOME extensions CLI ─────────────────────────────────────────────────────

ensure_gext() {
    if ! command -v gext &>/dev/null; then
        if command -v pipx &>/dev/null; then
            info "Installing gnome-extensions-cli (gext) via pipx"
            pipx install gnome-extensions-cli
        else
            info "Installing gnome-extensions-cli (gext) via pip"
            pip install --user gnome-extensions-cli
        fi
        export PATH="$HOME/.local/bin:$PATH"
    fi
}

# ─── Casks whose .desktop launcher we customize ───────────────────────────────
#
# run_config_desktop_overrides (lib/config.sh) rewrites the launcher these
# ublue casks deposit into ~/.local/share/applications/ — Icon= for both, plus
# Exec= for 1Password. brew records that launcher as a cask artifact, so once
# we've edited it a later `brew bundle` upgrade/reinstall of the cask aborts
# ("…has been modified; use --force"). We pre-empt that by resetting each
# affected cask to a pristine state *before* brew bundle runs, so bundle sees
# clean artifacts and installs/upgrades normally; run_config_desktop_overrides
# then re-applies our edits afterwards.
#
# Only casks already installed are reset — on a fresh machine they don't exist
# yet, brew bundle installs them clean (nothing has modified the launcher yet),
# and there's nothing to force. Full tap-qualified tokens; the leaf name is
# what `brew list --cask` expects.
DESKTOP_CUSTOMIZED_CASKS=(
    "ublue-os/tap/visual-studio-code-linux"
    "ublue-os/tap/1password-gui-linux"
)

reset_desktop_customized_casks() {
    command -v brew &>/dev/null || return 0
    local cask leaf
    for cask in "${DESKTOP_CUSTOMIZED_CASKS[@]}"; do
        leaf="${cask##*/}"
        if brew list --cask "$leaf" &>/dev/null; then
            info "Force-reinstalling $leaf (resets customized .desktop so brew bundle won't choke)"
            brew reinstall --cask --force "$cask" \
                || warn "brew reinstall of $cask failed — brew bundle may need --force"
        fi
    done
}

# ─── CLI tool install/uninstall ───────────────────────────────────────────────

install_zsh_setup() {
    if ! command -v brew &>/dev/null; then
        err "Homebrew is required for Zsh setup. Install 'brew' first."
        return 1
    fi

    brew install just
    just -f "$SCRIPT_DIR/justfile" zsh

    ok "Zsh setup complete (restart your terminal to activate)"
}

install_cli_tool() {
    case "$1" in
        zsh-setup)
            install_zsh_setup
            ;;
    esac
}

uninstall_cli_tool() {
    case "$1" in
        brew)
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
            ;;
        zsh-setup)
            warn "Zsh setup removal: manually clean ~/.zshrc and ~/.config/starship.toml"
            ;;
    esac
}
