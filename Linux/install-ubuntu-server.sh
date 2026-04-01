#!/usr/bin/env bash
set -uo pipefail

# Ubuntu Server — Zsh setup script
# Installs Zsh, Homebrew, and the full plugin/config stack.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { printf '\033[1;34m▸ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
err()   { printf '\033[1;31m✗ %s\033[0m\n' "$*"; }

# ─── Install Zsh ──────────────────────────────────────────────────────────────

if ! command -v zsh &>/dev/null; then
    info "Installing Zsh"
    sudo apt update && sudo apt install -y zsh
fi

# ─── Install Homebrew ─────────────────────────────────────────────────────────

if ! command -v brew &>/dev/null; then
    info "Installing Homebrew"
    sudo apt install -y build-essential curl git
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -d /home/linuxbrew/.linuxbrew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        if ! grep -q 'linuxbrew' ~/.bashrc 2>/dev/null; then
            printf '\neval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"\n' >> ~/.bashrc
        fi
    fi
fi

# ─── Install just and run Zsh setup ─────────────────────────────────────────

info "Installing just"
brew install just

info "Running Zsh setup via justfile"
just -f "$SCRIPT_DIR/justfile" zsh

ok "Setup complete — run 'exec zsh' to load changes"
