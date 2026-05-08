#!/usr/bin/env bash
# Brave PWA launcher.
#
# Wraps `brave-browser --app=URL` with the two things our deployed
# .desktop entries rely on:
#
#   1. --ozone-platform=x11
#      Native Wayland Brave ignores `--class` in --app= mode (sets the
#      app_id to the URL host), which breaks GNOME's StartupWMClass
#      matching → the dock falls back to a generic icon. XWayland
#      propagates --class as the X11 WM_CLASS class string, and GNOME
#      matches that to our .desktop. Bonus: the window picks up
#      mutter's standard SSD title bar instead of Chromium's super-thin
#      client-side bar.
#
#   2. GTK_THEME passthrough
#      Chromium's X11 code path does not query xdg-desktop-portal for
#      the color scheme — it reads the GTK theme name. If GTK_THEME
#      isn't set in the environment, the page sees prefers-color-scheme:
#      light even when the system is in dark mode. We read the user's
#      current GTK theme from gsettings at launch time (so flipping the
#      desktop between light/dark gets reflected in PWAs without a
#      redeploy) and pass it through.
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

theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'") || theme=""
if [[ -n "$theme" ]]; then
    export GTK_THEME="$theme"
fi

exec brave-browser \
    --ozone-platform=x11 \
    --app="$url" \
    --class="$wmclass" \
    --name="$wmclass" \
    "$@"
