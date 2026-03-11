#!/usr/bin/env zsh
# Cleanup deprecated Homebrew taps across all machines
# These taps are now built into Homebrew and produce deprecation warnings.
#
# Affected machines (at time of creation):
#   - Helios: homebrew/bundle, homebrew/services
#
# Safe to run on any machine — untap silently skips taps that aren't present.

set -euo pipefail

deprecated_taps=(
    homebrew/bundle
    homebrew/services
)

echo "Removing deprecated Homebrew taps..."
for tap in "${deprecated_taps[@]}"; do
    if brew tap | grep -qx "$tap"; then
        echo "  Removing $tap..."
        brew untap "$tap"
    else
        echo "  $tap not present, skipping."
    fi
done
echo "Done."
