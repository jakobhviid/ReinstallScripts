#!/usr/bin/env bash
set -euo pipefail

# Prereq installer for Mac. Run once on a fresh machine; idempotent.
# After this, every other action lives behind `just`.
#
# What this does:
#   1. Installs Homebrew (if missing). Brew's official installer also
#      updates ~/.zprofile (Apple Silicon) or ~/.bash_profile (Intel) on
#      its own, so future shells pick up brew automatically.
#   2. Loads brew into this script's PATH.
#   3. Installs `just` (if missing).
#
# What this does NOT do:
#   - Carry brew into your *current* terminal. Subprocesses can't modify
#     their parent shell's environment. After this finishes, RESTART YOUR
#     TERMINAL (or run the eval line printed at the end) before invoking
#     `just`. Without that, `just` will not be on your PATH yet.

brew_path=""
if command -v brew &>/dev/null; then
    brew_path="$(command -v brew)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
    brew_path="/opt/homebrew/bin/brew"
elif [[ -x /usr/local/bin/brew ]]; then
    brew_path="/usr/local/bin/brew"
fi

if [[ -z "$brew_path" ]]; then
    echo "▸ Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -x /opt/homebrew/bin/brew ]]; then
        brew_path="/opt/homebrew/bin/brew"
    elif [[ -x /usr/local/bin/brew ]]; then
        brew_path="/usr/local/bin/brew"
    else
        echo "✗ Homebrew install completed but brew binary not found at the expected paths." >&2
        exit 1
    fi
else
    echo "✓ Homebrew already installed at $brew_path"
fi

# Load brew into this script's environment.
eval "$("$brew_path" shellenv)"

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
  picks up brew automatically (the official installer wired it into
  your shell rc). If you can't open a new terminal, run:

      eval "\$($brew_path shellenv)"

  Then, e.g.:

      cd Mac && just install chronos
EOF
