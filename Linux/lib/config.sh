# shellcheck shell=bash
# Post-install configuration steps shared between Bazzite and Fedora Workstation.
# Depends on common.sh (info/ok/warn) and caller having set SCRIPT_DIR to the
# directory of the top-level install script (Linux/), so that references like
# "$SCRIPT_DIR/assets/brave-policy.json" and "$SCRIPT_DIR/../shared/app-icons/" resolve.

run_config_brave_policy() {
    info "Applying Brave browser policy"

    if [[ ! -f "$SCRIPT_DIR/assets/brave-policy.json" ]]; then
        warn "brave-policy.json not found at $SCRIPT_DIR/assets — skipping"
        return
    fi

    sudo mkdir -p /etc/brave/policies/managed
    sudo cp "$SCRIPT_DIR/assets/brave-policy.json" /etc/brave/policies/managed/brave-policy.json

    ok "Brave policy applied"
}

run_config_1password() {
    info "Configuring 1Password"

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
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$kb_path" \
      name "1Password Quick Search"
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$kb_path" \
      command "1password --quick-access"
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$kb_path" \
      binding "<Alt><Shift>2"

    # Vivaldi browser compat (no-op on machines without Vivaldi; harmless)
    sudo install -d -m 0755 /etc/1password
    printf '%s\n' vivaldi-bin | sudo tee /etc/1password/custom_allowed_browsers >/dev/null
    sudo chown root:root /etc/1password/custom_allowed_browsers
    sudo chmod 0755 /etc/1password/custom_allowed_browsers

    # Fix dark titlebar and enable native Wayland
    mkdir -p ~/.local/share/applications
    if [[ ! -f ~/.local/share/applications/1password.desktop ]]; then
        [[ -f /usr/share/applications/1password.desktop ]] && \
          cp /usr/share/applications/1password.desktop ~/.local/share/applications/1password.desktop
    fi
    if [[ -f ~/.local/share/applications/1password.desktop ]]; then
        sed -i 's|Exec=/opt/1Password/1password %U|Exec=env GTK_THEME=Adwaita:dark /opt/1Password/1password --enable-features=UseOzonePlatform --ozone-platform=wayland %U|' \
          ~/.local/share/applications/1password.desktop
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
        "brave-browser.desktop|/usr/share/applications/brave-browser.desktop|brave-browser.webp"
        "code.desktop|/usr/share/applications/code.desktop|code.webp"
        "1password.desktop|/usr/share/applications/1password.desktop|1password.webp"
        "org.gnome.Nautilus.desktop|/usr/share/applications/org.gnome.Nautilus.desktop|org.gnome.Nautilus.png"
        "org.gnome.Ptyxis.desktop|/usr/share/applications/org.gnome.Ptyxis.desktop|org.gnome.Ptyxis.webp"
        "com.discordapp.Discord.desktop|/var/lib/flatpak/exports/share/applications/com.discordapp.Discord.desktop|com.discordapp.Discord.webp"
        "org.signal.Signal.desktop|/var/lib/flatpak/exports/share/applications/org.signal.Signal.desktop|org.signal.Signal.webp"
        "proton.vpn.app.gtk.desktop|/usr/share/applications/proton.vpn.app.gtk.desktop|proton.vpn.app.gtk.png"
    )

    for row in "${overrides[@]}"; do
        IFS='|' read -r name src icon <<<"$row"
        if [[ ! -f "$src" ]]; then
            warn "Skipping $name — source $src not found"
            continue
        fi
        [[ -f "$app_dir/$name" ]] || cp "$src" "$app_dir/$name"
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
    done

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
    done

    ok "Autostart entries configured"
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

run_config_audio() {
    mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
    local dest=~/.config/wireplumber/wireplumber.conf.d/rename-devices.conf
    if [[ -f "$SCRIPT_DIR/assets/rename-devices.conf" ]] && ! diff -q "$SCRIPT_DIR/assets/rename-devices.conf" "$dest" &>/dev/null; then
        info "Updating audio device names"
        cp "$SCRIPT_DIR/assets/rename-devices.conf" "$dest"
        systemctl --user restart wireplumber pipewire pipewire-pulse
        ok "Audio device names configured"
    fi
}
