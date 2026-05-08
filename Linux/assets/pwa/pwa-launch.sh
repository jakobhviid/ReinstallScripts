#!/usr/bin/env bash
# Brave PWA launcher.
#
# Wraps `brave-browser --app=URL` with the two flags every PWA window
# needs on a GNOME/Wayland system:
#
#   1. --ozone-platform=x11
#      Native Wayland Brave ignores `--class` in --app= mode (sets the
#      Wayland app_id to the URL host instead), which breaks GNOME's
#      window-to-.desktop matching → the dock falls back to a generic
#      icon. XWayland propagates --class as the X11 WM_CLASS class
#      string, which GNOME matches to the .desktop whose filename equals
#      that class. Bonus: the window picks up mutter's standard SSD
#      title bar instead of Chromium's super-thin client-side bar.
#
#      The .desktop filename for each PWA must equal its WMClass (e.g.
#      `WebApp-ProtonMail.desktop` paired with `--class=WebApp-ProtonMail`)
#      because GNOME's window-tracker prefers a filename match over the
#      `StartupWMClass=` field.
#
#   2. --force-dark-mode (only when system is in dark mode)
#      On Linux, Chromium's prefers-color-scheme reporting is
#      explicitly controlled by --force-dark-mode — there's no
#      OS-detection code path for X11. (See chromestatus 5109758977638400.)
#      Wayland Chromium since 114 reads xdg-desktop-portal directly,
#      which is why a regular browser tab on mail.proton.me sees dark
#      while a --ozone-platform=x11 PWA window does not. Read the
#      current setting at launch time so flipping the system between
#      light/dark gets reflected without re-deploying.
#
# Usage: pwa-launch <wmclass> <url> [extra-brave-args...]

set -eu

if [[ $# -lt 2 ]]; then
    echo "usage: pwa-launch <wmclass> <url> [extra-args...]" >&2
    exit 64
fi

wmclass=$1
url=$2
shift 2

color_scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'") || color_scheme=""
extra=()
if [[ "$color_scheme" == "prefer-dark" ]]; then
    extra+=(--force-dark-mode)
fi

exec brave-browser \
    --ozone-platform=x11 \
    "${extra[@]}" \
    --app="$url" \
    --class="$wmclass" \
    --name="$wmclass" \
    "$@"
