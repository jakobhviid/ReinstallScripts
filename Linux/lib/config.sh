# shellcheck shell=bash
# Post-install per-user configuration steps for Phase 2 of install-bazzite.sh.
# Depends on common.sh (info/ok/warn) and caller having set SCRIPT_DIR to the
# directory of the top-level install script (Linux/), so that references like
# "$SCRIPT_DIR/../shared/app-icons/" resolve.
#
# Functions removed in the bazzite-custom image rework — now handled by the
# image's system_files/ directly:
#   - run_config_brave_policy       → image bakes /etc/brave/policies/managed/brave-policy.json
#   - run_config_audio              → image bakes /usr/share/wireplumber/wireplumber.conf.d/rename-devices.conf
#   - run_config_unlock_services    → image bakes /usr/lib/systemd/user/{brave,vivaldi,nextcloud}-unlock.service
#                                     (auto-enabled per-user via /usr/lib/systemd/user-preset/)
# 1Password lives in brew (cask ublue-os/tap/1password-gui-linux), not in
# the image and not RPM-layered. Three lessons from a long debugging session
# that need to be load-bearing here, because the symptoms misled us repeatedly:
#
#   1. The user MUST NOT be a member of the `onepassword` group. The cask
#      creates the group and chowns BrowserSupport to root:onepassword setgid.
#      1P main app's IPC peer check accepts a connection only if the peer's
#      egid is `onepassword`, which is supposed to be reachable ONLY via
#      setgid exec. If the user is in the group, ordinary user processes
#      could trivially obtain that egid and the auth check is meaningless,
#      so 1P rejects the connection with PipeAuthError(NoCreds). Every
#      "fix" that did `usermod -aG onepassword $USER` (a common stale tip)
#      was the actual bug. The cask deliberately does NOT add the user.
#      → This function refuses to proceed if the user is a member.
#
#   2. /etc/1password/custom_allowed_browsers must be mode 0755 root:root.
#      1P's verification at op-browser-support/src/browser_verification/
#      linux.rs:86 is "writable only by root". Mode 0444 (no write for
#      anyone) FAILS this check — root needs the write bit. The cask
#      installs at 0644 (also valid). 1P's own log message says 0755.
#
#   3. The cask only installs NMH manifests for the major browsers it
#      ships defaults for (Brave, Chrome variants, Chromium, Edge, Vivaldi,
#      Vivaldi-snapshot, Firefox). Vivaldi, Zen, and Brave Origin also
#      need to be whitelisted in custom_allowed_browsers (1P's hardcoded
#      trusted basenames are only chrome/chromium-browser-privacy/msedge/
#      brave/firefox/firefox-bin/firefox-esr — note "brave" matches
#      brave-browser/brave-browser-stable but NOT brave-origin's binaries
#      /usr/bin/brave-origin and /usr/bin/brave-origin-stable). Zen
#      further needs a Firefox-style NMH manifest copied into
#      ~/.zen/native-messaging-hosts/ — the cask doesn't know about Zen
#      at all.
#
# This function therefore: validates the group state, adds the keybinding
# and dark-titlebar tweak (the "make it nice" part), appends vivaldi-bin,
# zen-bin, brave-origin, and brave-origin-stable to
# custom_allowed_browsers, and installs Zen's NMH manifest.

run_config_1password() {
    info "Configuring 1Password (per-user GNOME keybinding + dark titlebar + browser allowlist)"

    # Lesson 1: bail loudly if the user is in the onepassword group. This
    # silently breaks browser integration in a way that took a full session
    # to root-cause. Prefer noisy stop over silent re-introduction.
    if id -nG "$USER" | tr ' ' '\n' | grep -qx onepassword; then
        warn "User '$USER' is a member of the 'onepassword' group."
        warn "This BREAKS 1Password browser integration: 1P's IPC peer check"
        warn "rejects connections from peers whose egid is reachable without"
        warn "setgid exec. Remove with:  sudo gpasswd -d \"$USER\" onepassword"
        warn "Then log out + log back in. Skipping run_config_1password."
        return
    fi

    # Register our custom keybinding path in the global list WITHOUT clobbering
    # any other custom shortcuts the user has configured. Only add if missing.
    local kb_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password/"
    local current
    current=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
    if [[ "$current" != *"$kb_path"* ]]; then
        if [[ "$current" == "@as []" || "$current" == "[]" ]]; then
            gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$kb_path']"
        else
            gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "${current%]}, '$kb_path']"
        fi
    fi

    # Per-keybinding name/command/binding can be set unconditionally — they're
    # under our own sub-schema and don't affect anyone else's shortcuts.
    # Resolve the binary's absolute path: GNOME shell's PATH is the system
    # default (/usr/local/sbin:/usr/local/bin:/usr/bin) — it does NOT include
    # /home/linuxbrew/.linuxbrew/bin, so the bare name `1password` won't
    # resolve when GNOME spawns the keybinding command. Using $(command -v)
    # captures wherever brew installed it, making the binding portable across
    # machines (and across future brew prefix changes — re-run the script
    # to re-resolve).
    local op_bin
    op_bin=$(command -v 1password)
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$kb_path" \
      name "1Password Quick Search"
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$kb_path" \
      command "$op_bin --quick-access"
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$kb_path" \
      binding "<Alt><Shift>2"

    # Fix dark titlebar and enable native Wayland on the user-local .desktop.
    # The cask drops 1password.desktop directly into ~/.local/share/applications
    # with Exec pointing at the brew prefix (e.g. /home/linuxbrew/.linuxbrew/bin
    # /1password). Path-flexible regex captures whatever Exec= points at and
    # rewrites it with the env wrapper + flags.
    if [[ -f ~/.local/share/applications/1password.desktop ]]; then
        sed -i -E 's|^Exec=([^ ]*1password) %U|Exec=env GTK_THEME=Adwaita:dark \1 --enable-features=UseOzonePlatform --ozone-platform=wayland %U|' \
          ~/.local/share/applications/1password.desktop
    fi

    # Lesson 3a: Vivaldi (vivaldi-bin), Zen (zen-bin), and Brave Origin
    # (brave-origin + brave-origin-stable) are not in 1P's hardcoded
    # trusted-browser basename list. Append them to the cask-installed
    # custom_allowed_browsers (skip the block entirely if the cask file
    # isn't present — means brew install hasn't run yet).
    #
    # Brave Origin is the privacy/Shields-only Brave build, baked into
    # bazzite-custom alongside brave-browser. The desktop file's Exec
    # points at /usr/bin/brave-origin-stable; 1P's check looks at the
    # parent process basename. Adding both `brave-origin` (canonical
    # name + symlink) and `brave-origin-stable` (the actual binary)
    # covers either resolution path.
    local cab=/etc/1password/custom_allowed_browsers
    if [[ -f "$cab" ]]; then
        local need_append=()
        for entry in vivaldi-bin zen-bin brave-origin brave-origin-stable; do
            if ! sudo grep -qxF "$entry" "$cab"; then
                need_append+=("$entry")
            fi
        done
        if (( ${#need_append[@]} > 0 )); then
            info "Adding to $cab: ${need_append[*]}"
            # Cask ships the file without a trailing newline, so a naive
            # `tee -a` concatenates with the last line. Ensure trailing
            # newline first, then append each entry on its own line.
            if [[ -n "$(sudo tail -c1 "$cab")" ]]; then
                printf '\n' | sudo tee -a "$cab" >/dev/null
            fi
            printf '%s\n' "${need_append[@]}" | sudo tee -a "$cab" >/dev/null
        fi
        # Lesson 2: 1P requires "writable only by root" — mode 0755 (or 0644)
        # owner root:root. Mode 0444 fails because root lacks the write bit.
        sudo chown root:root "$cab"
        sudo chmod 0755 "$cab"
    else
        warn "$cab not found — skipping browser allowlist update."
        warn "If you want Vivaldi/Zen browser integration, install"
        warn "1Password GUI first (brew install --cask ublue-os/tap/1password-gui-linux),"
        warn "then re-run this script."
    fi

    # Lesson 3b: Zen needs a Firefox-style NMH manifest (allowed_extensions,
    # not allowed_origins). Cask doesn't write one. Source it from the
    # Firefox manifest the cask DID write.
    local zen_dir=~/.zen/native-messaging-hosts
    local moz_manifest=~/.mozilla/native-messaging-hosts/com.1password.1password.json
    local moz_wrapper=~/.mozilla/native-messaging-hosts/1PasswordWrapper.sh
    if [[ -d ~/.zen && -f "$moz_manifest" ]]; then
        mkdir -p "$zen_dir"
        cp -f "$moz_manifest" "$zen_dir/com.1password.1password.json"
        [[ -f "$moz_wrapper" ]] && cp -f "$moz_wrapper" "$zen_dir/1PasswordWrapper.sh"
        info "Installed Zen 1Password NMH manifest"
    fi

    ok "1Password configured"
}

run_config_desktop_overrides() {
    info "Deploying custom app icons and .desktop overrides"

    local icon_dir=~/.local/share/icons/reinstall-scripts
    local app_dir=~/.local/share/applications
    mkdir -p "$icon_dir" "$app_dir"

    cp -u "$SCRIPT_DIR/../shared/app-icons/"* "$icon_dir/"

    # name | source .desktop | icon filename (under shared/app-icons)
    local overrides=(
        "brave-browser.desktop|/usr/share/applications/brave-browser.desktop|brave-browser.png"
        "code.desktop|$HOME/.local/share/applications/code.desktop|code.png"
        "1password.desktop|/usr/share/applications/1password.desktop|1password.png"
        "org.gnome.Nautilus.desktop|/usr/share/applications/org.gnome.Nautilus.desktop|org.gnome.Nautilus.png"
        "com.mitchellh.ghostty.desktop|/usr/share/applications/com.mitchellh.ghostty.desktop|com.mitchellh.ghostty.png"
        "com.discordapp.Discord.desktop|/var/lib/flatpak/exports/share/applications/com.discordapp.Discord.desktop|com.discordapp.Discord.png"
        "org.signal.Signal.desktop|/var/lib/flatpak/exports/share/applications/org.signal.Signal.desktop|org.signal.Signal.png"
        "proton.vpn.app.gtk.desktop|/usr/share/applications/proton.vpn.app.gtk.desktop|proton.vpn.app.gtk.png"
        "vivaldi-stable.desktop|/usr/share/applications/vivaldi-stable.desktop|vivaldi-stable.png"
        "org.mozilla.firefox.desktop|/usr/share/applications/org.mozilla.firefox.desktop|org.mozilla.firefox.png"
        "claude-desktop.desktop|/usr/share/applications/claude-desktop.desktop|claude-desktop.png"
        "Cider.desktop|/usr/share/applications/Cider.desktop|Cider.png"
        "dev.zed.Zed.desktop|/var/lib/flatpak/exports/share/applications/dev.zed.Zed.desktop|dev.zed.Zed.png"
    )

    for row in "${overrides[@]}"; do
        IFS='|' read -r name src icon <<<"$row"
        # If the user-level file is already there (brew casks deposit some
        # straight into ~/.local/share/applications), skip the copy step.
        if [[ ! -f "$app_dir/$name" ]]; then
            if [[ ! -f "$src" ]]; then
                warn "Skipping $name — no $app_dir/$name and no $src"
                continue
            fi
            cp "$src" "$app_dir/$name"
        fi
        sed -i "s|^Icon=.*|Icon=$icon_dir/$icon|" "$app_dir/$name"
    done

    # Brave: enable touchpad overscroll history nav + native Wayland hint
    # Patches all three Exec= forms (main, New Window action, New Private Window action)
    if [[ -f "$app_dir/brave-browser.desktop" ]]; then
        sed -i \
          -e 's|^Exec=/usr/bin/brave-browser-stable %U|Exec=/usr/bin/brave-browser-stable --enable-features=TouchpadOverscrollHistoryNavigation --ozone-platform-hint=auto %U|' \
          -e 's|^Exec=/usr/bin/brave-browser-stable$|Exec=/usr/bin/brave-browser-stable --enable-features=TouchpadOverscrollHistoryNavigation --ozone-platform-hint=auto|' \
          -e 's|^Exec=/usr/bin/brave-browser-stable --incognito$|Exec=/usr/bin/brave-browser-stable --enable-features=TouchpadOverscrollHistoryNavigation --ozone-platform-hint=auto --incognito|' \
          "$app_dir/brave-browser.desktop"
    fi

    update-desktop-database ~/.local/share/applications &>/dev/null || true

    ok "Desktop overrides applied"
}

run_config_pwa() {
    info "Deploying Brave PWAs"

    local src_dir="$SCRIPT_DIR/assets/pwa"
    if [[ ! -d "$src_dir" ]]; then
        warn "PWA assets directory missing — skipping"
        return
    fi

    local app_dir=~/.local/share/applications
    local icon_dir=~/.local/share/icons/reinstall-scripts/pwa
    mkdir -p "$app_dir" "$icon_dir"

    cp -u "$src_dir/icons/"* "$icon_dir/"

    local desktop stem icon_file ext
    for desktop in "$src_dir"/*.desktop; do
        [[ -f "$desktop" ]] || continue
        stem=$(basename "$desktop" .desktop)

        # Find the icon we deployed for this PWA (png or webp)
        icon_file=""
        for ext in png webp; do
            if [[ -f "$icon_dir/$stem.$ext" ]]; then
                icon_file="$icon_dir/$stem.$ext"
                break
            fi
        done

        cp "$desktop" "$app_dir/$(basename "$desktop")"
        if [[ -n "$icon_file" ]]; then
            sed -i "s|^Icon=.*|Icon=$icon_file|" "$app_dir/$(basename "$desktop")"
        fi
        # gtk-launch doesn't expand env vars in Exec=, so resolve __HOME__
        # at deploy time. Lets each PWA get its own --user-data-dir under
        # the user's home without hardcoding /home/<user> in the repo.
        sed -i "s|__HOME__|$HOME|g" "$app_dir/$(basename "$desktop")"
    done

    # Remove legacy Brave-installed PWA .desktop entries (from the previous
    # --app-id=<crx> era). Pattern matches Brave's auto-generated naming
    # `brave-<32-char-crx-id>-Default.desktop` so we never touch the main
    # `brave-browser.desktop`.
    shopt -s nullglob
    for legacy in "$app_dir"/brave-*-Default.desktop; do
        if [[ "$(basename "$legacy")" =~ ^brave-[a-p]{32}-[A-Za-z]+\.desktop$ ]]; then
            rm -f "$legacy"
        fi
    done
    shopt -u nullglob

    update-desktop-database ~/.local/share/applications &>/dev/null || true

    ok "Brave PWAs deployed"
}

run_config_autostart() {
    info "Configuring autostart entries"

    local autostart_dir=~/.config/autostart
    local user_apps_dir=~/.local/share/applications
    mkdir -p "$autostart_dir"

    # name | fallback source (used if the user-level override isn't present)
    local entries=(
        "1password.desktop|/usr/share/applications/1password.desktop"
        "com.discordapp.Discord.desktop|/var/lib/flatpak/exports/share/applications/com.discordapp.Discord.desktop"
        "com.nextcloud.desktopclient.nextcloud.desktop|/var/lib/flatpak/exports/share/applications/com.nextcloud.desktopclient.nextcloud.desktop"
        "org.localsend.localsend_app.desktop|/var/lib/flatpak/exports/share/applications/org.localsend.localsend_app.desktop"
    )

    for row in "${entries[@]}"; do
        IFS='|' read -r name fallback <<<"$row"
        local src
        if [[ -f "$user_apps_dir/$name" ]]; then
            src="$user_apps_dir/$name"
        elif [[ -f "$fallback" ]]; then
            src="$fallback"
        else
            warn "Skipping autostart $name — no .desktop found"
            continue
        fi
        cp "$src" "$autostart_dir/$name"

        # Inject background-launch flags into the autostart copy only — the
        # user-level menu entry stays unchanged so manual launches still open
        # the window. sed patterns are anchored to substrings the source files
        # carry today; a second run is a no-op because the substring is gone.
        case "$name" in
            1password.desktop)
                # Source can be the user-level override (carries
                # --enable-features=…) or the system /usr/share fallback
                # (just /1password %U). Patch both shapes; idempotent because
                # post-injection the original substring no longer exists.
                sed -i \
                  -e 's|/1password --enable-features|/1password --silent --enable-features|' \
                  -e 's|/1password %U|/1password --silent %U|' \
                  "$autostart_dir/$name"
                ;;
            com.discordapp.Discord.desktop)
                sed -i 's|com.discordapp.Discord @@u|com.discordapp.Discord --start-minimized @@u|' \
                  "$autostart_dir/$name"
                ;;
            com.nextcloud.desktopclient.nextcloud.desktop)
                # Only the main Exec line carries --file-forwarding; the "Quit
                # Nextcloud" action Exec doesn't, so the address-match leaves
                # it alone.
                sed -i '/--file-forwarding/ s|com.nextcloud.desktopclient.nextcloud @@u|com.nextcloud.desktopclient.nextcloud --background @@u|' \
                  "$autostart_dir/$name"
                ;;
            org.localsend.localsend_app.desktop)
                sed -i 's|org.localsend.localsend_app @@u|org.localsend.localsend_app --hidden @@u|' \
                  "$autostart_dir/$name"
                ;;
        esac
    done

    ok "Autostart entries configured"
}

# LocalSend's Flutter UI honors GTK_THEME for the system titlebar/decorations.
# Flatpak override embeds the env var into every launch (autostart, app menu,
# file-share callouts) without needing per-Exec sed patches.
run_config_localsend() {
    if ! command -v flatpak &>/dev/null; then
        return
    fi
    if ! flatpak info org.localsend.localsend_app &>/dev/null; then
        return
    fi

    info "Forcing dark titlebar on LocalSend"
    flatpak override --user --env=GTK_THEME=Adwaita:dark org.localsend.localsend_app
    ok "LocalSend dark titlebar applied"
}

run_config_gnome_shell() {
    local src="$SCRIPT_DIR/assets/gnome/shell.dconf"
    if [[ ! -f "$src" ]]; then
        warn "shell.dconf not found at $src — skipping"
        return
    fi
    if ! command -v dconf &>/dev/null; then
        warn "dconf not available — skipping GNOME shell settings"
        return
    fi

    info "Applying GNOME shell settings (extensions on/off + dash-to-panel/blur-my-shell/hotedge)"
    dconf load /org/gnome/shell/ < "$src"

    # xwayland-native-scaling makes XWayland apps render at native resolution
    # under fractional scaling instead of being bitmap-scaled by mutter — fixes
    # blurry text in our Brave PWA windows (which run on XWayland for proper
    # WMClass / dock icon matching).
    dconf write /org/gnome/mutter/experimental-features \
        "['kms-modifiers', 'xwayland-native-scaling']"

    ok "GNOME shell settings applied"
}

run_config_ptyxis() {
    local src="$SCRIPT_DIR/assets/ptyxis.dconf"
    if [[ ! -f "$src" ]]; then
        warn "ptyxis.dconf not found at $src — skipping"
        return
    fi
    if ! command -v dconf &>/dev/null; then
        warn "dconf not available — skipping Ptyxis settings"
        return
    fi

    info "Applying Ptyxis settings (profiles, shortcuts, window prefs)"
    dconf load /org/gnome/Ptyxis/ < "$src"
    ok "Ptyxis settings applied"
}

# Deploy Ghostty config from assets/ghostty.config to ~/.config/ghostty/config.
# Flat-file copy (no template substitution). Backs up any pre-existing config
# that differs from the vendored one to .bak before overwriting, so a user
# who edited the live file in place gets one chance to recover.
run_config_ghostty() {
    local src="$SCRIPT_DIR/assets/ghostty.config"
    local dst="$HOME/.config/ghostty/config"
    if [[ ! -f "$src" ]]; then
        warn "ghostty.config not found at $src — skipping"
        return
    fi
    info "Deploying Ghostty config"
    mkdir -p "$(dirname "$dst")"
    if [[ -f "$dst" ]] && ! diff -q "$src" "$dst" >/dev/null 2>&1; then
        cp "$dst" "$dst.bak"
        info "Backed up existing config to $dst.bak"
    fi
    cp "$src" "$dst"
    ok "Ghostty config deployed to $dst"
}

run_config_ghostty_keybinding() {
    # Bind Ctrl+Alt+T to launch Ghostty via GNOME custom-keybinding rather
    # than Ghostty's own portal `keybind = global:` mechanism. The portal
    # grab only exists while Ghostty is running, so closing the last window
    # also kills the shortcut. A GNOME-level binding survives the process
    # exiting, and with Ghostty's gtk-single-instance = detect default,
    # re-invoking `ghostty` either opens a new window in the live instance
    # (D-Bus activation) or launches a fresh one — both states work.
    info "Configuring Ghostty Ctrl+Alt+T (GNOME custom keybinding)"

    if ! command -v ghostty >/dev/null 2>&1; then
        warn "ghostty binary not on PATH — skipping Ctrl+Alt+T keybinding."
        warn "Ghostty is installed by the bazzite-custom image; if you're"
        warn "on stock Bazzite this will run cleanly after the rebase."
        return
    fi

    # Resolve the binary's absolute path. GNOME shell spawns keybinding
    # commands with the system PATH (/usr/local/sbin:/usr/local/bin:/usr/bin),
    # which already contains /usr/bin/ghostty on the image — but using an
    # absolute path makes the binding robust against future PATH changes
    # and mirrors the same lesson learned with 1Password's keybinding.
    local gh_bin
    gh_bin=$(command -v ghostty)

    # Register our path in the global custom-keybindings list without
    # clobbering any other custom shortcuts the user already has. Only
    # add it if missing.
    local kb_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ghostty/"
    local current
    current=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
    if [[ "$current" != *"$kb_path"* ]]; then
        if [[ "$current" == "@as []" || "$current" == "[]" ]]; then
            gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$kb_path']"
        else
            gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "${current%]}, '$kb_path']"
        fi
    fi

    # Set name/command/binding under our own sub-schema — safe to write
    # unconditionally, no effect on anyone else's shortcuts. GNOME's stock
    # `terminal` keybinding on the same combo is auto-superseded by ours.
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$kb_path" \
      name "Ghostty New Window"
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$kb_path" \
      command "$gh_bin"
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$kb_path" \
      binding "<Ctrl><Alt>t"

    ok "Ctrl+Alt+T bound to $gh_bin (survives Ghostty process exit)"
}
