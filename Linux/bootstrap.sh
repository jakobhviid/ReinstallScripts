#!/usr/bin/env bash
set -euo pipefail

# Prereq installer for Linux. Run once on a fresh machine; idempotent.
# After this, every other action lives behind `just`.
#
# Works whether you invoke it from bash or zsh (it runs as bash via the
# shebang). The post-install eval line printed at the end works in either
# shell too.
#
# What this does:
#   1. Installs Homebrew (if missing).
#   2. Loads brew into this script's PATH.
#   3. Adds brew shellenv eval to ~/.bashrc and ~/.zshrc (idempotent), so
#      future shells pick up brew automatically.
#   4. Installs `just` (if missing).
#
# What this does NOT do:
#   - Carry brew into your *current* terminal. Subprocesses can't modify
#     their parent shell's environment. After this finishes, RESTART YOUR
#     TERMINAL (or run the eval line printed at the end) before invoking
#     `just`. Without that, `just` will not be on your PATH yet.
#   - Install brew's build prereqs (gcc, make, etc.). On Bazzite they ship
#     with the OS. On other distros, install them yourself first if brew's
#     install script complains.

brew_path=""
if command -v brew &>/dev/null; then
    brew_path="$(command -v brew)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    brew_path="/home/linuxbrew/.linuxbrew/bin/brew"
fi

if [[ -z "$brew_path" ]]; then
    echo "▸ Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        brew_path="/home/linuxbrew/.linuxbrew/bin/brew"
    else
        echo "✗ Homebrew install completed but brew binary not found at /home/linuxbrew/.linuxbrew/bin/brew." >&2
        exit 1
    fi
else
    echo "✓ Homebrew already installed at $brew_path"
fi

# Load brew into this script's environment.
eval "$("$brew_path" shellenv)"

# Persist brew shellenv to user's shell rcs (idempotent).
ensure_rc_line() {
    local rc="$1" shell_arg="$2"
    [[ -f "$rc" ]] || return 0
    if ! grep -q 'linuxbrew' "$rc" 2>/dev/null; then
        printf '\neval "$(%s shellenv %s)"\n' "$brew_path" "$shell_arg" >> "$rc"
        echo "  added brew shellenv to $rc"
    fi
}
ensure_rc_line "$HOME/.bashrc" bash
ensure_rc_line "$HOME/.zshrc"  zsh
# .bashrc may not exist on a fresh box — create it for bash login coverage
if [[ ! -f "$HOME/.bashrc" ]]; then
    printf 'eval "$(%s shellenv bash)"\n' "$brew_path" > "$HOME/.bashrc"
    echo "  created $HOME/.bashrc with brew shellenv"
fi

if brew list just &>/dev/null; then
    echo "✓ just already installed"
else
    echo "▸ Installing just..."
    brew install just
fi

cat <<EOF

✓ Bootstrap complete.

  >>> RESTART YOUR TERMINAL before running 'just'. <<<

  Subprocesses can't modify your current shell's PATH. A new terminal
  picks up the brew shellenv from ~/.bashrc or ~/.zshrc automatically.
  If you can't open a new terminal, run this in the current one:

      eval "\$($brew_path shellenv)"

  Works in bash or zsh. Then, e.g.:

      cd Linux && just install chronos-redux
EOF
