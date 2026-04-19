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
        claude)    command -v claude &>/dev/null ;;
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
        brew)
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            if [[ -d /home/linuxbrew/.linuxbrew ]]; then
                eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
                if ! grep -q 'linuxbrew' ~/.bashrc 2>/dev/null; then
                    printf '\neval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"\n' >> ~/.bashrc
                fi
                if [[ -f ~/.zshrc ]] && ! grep -q 'linuxbrew' ~/.zshrc 2>/dev/null; then
                    printf '\neval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"\n' >> ~/.zshrc
                fi
            fi
            ;;
        zsh-setup)
            install_zsh_setup
            ;;
        claude)
            brew install claude-code
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
        claude)
            brew uninstall claude-code 2>/dev/null || true
            ;;
    esac
}
