# shellcheck shell=bash
# Logging helpers + y/N confirmation prompt.
# Sourced by install-bazzite.sh and install-fedora-workstation.sh.

info()  { printf '\033[1;34m▸ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
err()   { printf '\033[1;31m✗ %s\033[0m\n' "$*"; }

# confirm "Prompt" — default No. Returns 0 if user types y/Y (anything starting with y).
confirm() {
    local ans
    read -rp "$1 [y/N] " ans
    [[ "$ans" =~ ^[Yy] ]]
}
