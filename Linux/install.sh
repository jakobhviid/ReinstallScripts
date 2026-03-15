#!/usr/bin/env bash
set -uo pipefail

# Bazzite / Silverblue interactive setup script
# Re-runnable — detects installed state, lets you add/remove packages.
# Requires: gum (pre-installed on Bazzite)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Helpers ──────────────────────────────────────────────────────────────────

info()  { printf '\033[1;34m▸ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
err()   { printf '\033[1;31m✗ %s\033[0m\n' "$*"; }

needs_reboot=false

# ─── Package Lists ────────────────────────────────────────────────────────────
# Paired arrays: "key" "Display Name" ...

RPM_PACKAGES=(
    "podman-docker"                          "Podman Docker"
    "podman-compose"                         "Podman Compose"
    "brave-browser"                          "Brave Browser"
    "1password"                              "1Password"
    "code"                                   "VS Code"
    "proton-vpn-gnome-desktop"               "Proton VPN"
    "gnome-shell-extension-dash-to-panel"    "Dash to Panel"
    "gnome-shell-extension-dash-to-dock"     "Dash to Dock"
    "zsh"                                    "Zsh"
    "libgda"                                 "LibGDA"
    "libgda-sqlite"                          "LibGDA SQLite"
    "piper"                                  "Piper (mouse config)"
    "nodejs"                                 "Node.js"
    "nodejs-npm"                             "npm"
    "claude-desktop"                         "Claude Desktop"
)

FLATPAK_PACKAGES=(
    "com.discordapp.Discord"                 "Discord"
    "org.gnome.baobab"                       "Disk Usage Analyzer"
    "com.ranfdev.DistroShelf"                "DistroShelf"
    "com.mattjakeman.ExtensionManager"       "Extension Manager"
    "com.github.tchx84.Flatseal"            "Flatseal"
    "org.gimp.GIMP"                          "GIMP"
    "com.github.git_cola.git-cola"           "Git Cola"
    "be.alexandervanhee.gradia"              "Gradia"
    "org.libreoffice.LibreOffice"            "LibreOffice"
    "io.missioncenter.MissionCenter"         "Mission Center"
    "io.github.qwersyk.Newelle"              "Newelle"
    "com.nextcloud.desktopclient.nextcloud"  "Nextcloud"
    "org.gnome.World.PikaBackup"             "Pika Backup"
    "io.github.fabrialberio.pinapp"          "PinApp"
    "me.proton.Mail"                         "Proton Mail"
    "ch.protonmail.protonmail-bridge"        "Proton Bridge"
    "dev.dergs.Tonearm"                      "Tonearm"
    "io.github.flattool.Warehouse"           "Warehouse"
    "io.gitlab.news_flash.NewsFlash"         "NewsFlash"
    "it.mijorus.gearlever"                   "Gear Lever"
    "io.gitlab.adhami3310.Converter"         "Converter"
    "io.github.alainm23.planify"             "Planify"
    "com.bilingify.readest"                  "Readest"
    "com.github.johnfactotum.Foliate"        "Foliate"
    "com.calibre_ebook.calibre"              "Calibre"
    "com.collaboraoffice.Office"             "Collabora Office"
    "com.github.IsmaelMartinez.teams_for_linux" "Portal for Teams"
    "com.github.Matoking.protontricks"       "Protontricks"
    "com.vysp3r.ProtonPlus"                  "ProtonPlus"
    "fr.handbrake.ghb"                       "HandBrake"
    "im.riot.Riot"                           "Element"
    "io.github.cleomenezesjr.aurea"          "Aurea"
    "io.github.shonebinu.Brief"              "Brief"
    "io.github.sitraorg.sitra"               "Sitra"
    "io.github.wartybix.Constrict"           "Constrict"
    "io.gitlab.theevilskeleton.Upscaler"     "Upscaler"
    "me.proton.Pass"                         "Proton Pass"
    "net.retrodeck.retrodeck"                "RetroDECK"
    "net.trowell.typesetter"                 "Typesetter"
    "org.altlinux.Tuner"                     "Tuner"
    "org.fedoraproject.MediaWriter"          "Fedora Media Writer"
    "org.gnome.Firmware"                     "Firmware"
    "org.gnome.Fractal"                      "Fractal"
    "org.localsend.localsend_app"            "LocalSend"
    "org.signal.Signal"                      "Signal"
    "org.zotero.Zotero"                      "Zotero"
)

# Bundled in Bazzite but disabled by default
GNOME_BUNDLED=(
    "compiz-windows-effect@hermes83.github.com"  "Compiz Windows Effect"
    "desktop-cube@schneegans.github.com"         "Desktop Cube"
    "burn-my-windows@schneegans.github.com"      "Burn My Windows"
)

# Install from extensions.gnome.org
GNOME_INSTALL=(
    "tilingshell@ferrarodomenico.com"        "Tiling Shell"
    "copyous@boerdereinar.dev"               "Copyous (clipboard)"
    "azclock@azclock.gitlab.com"             "Desktop Clock"
    "search-light@icedman.github.com"        "Search Light"
    "advanced-alt-tab@G-dH.github.com"       "AATWS (Alt-Tab)"
    "ding@rastersoft.com"                    "Desktop Icons NG"
    "arcmenu@arcmenu.com"                    "Arc Menu"
    "Vitals@CoreCoding.com"                  "Vitals"
)

CLI_TOOLS=(
    "nvm"    "NVM + Node LTS"
    "kiro"   "Kiro CLI"
    "claude" "Claude Code"
    "codex"  "Codex CLI"
)

CONFIG_STEPS=(
    "repos"         "Package Repositories"
    "brave-policy"  "Brave Browser Policy"
    "1password"     "1Password Shortcuts & Config"
    "audio"         "Audio Device Renaming"
    "newelle"       "Newelle AI Permissions"
)

# ─── Detection ────────────────────────────────────────────────────────────────

is_rpm_installed()     { rpm -q "$1" &>/dev/null; }
is_flatpak_installed() { flatpak info "$1" &>/dev/null 2>&1; }
is_gext_installed()    { gnome-extensions list 2>/dev/null | grep -qF "$1"; }
is_cli_installed() {
    case "$1" in
        nvm)    [[ -d "$HOME/.nvm" ]] ;;
        kiro)   command -v kiro &>/dev/null ;;
        claude) command -v claude &>/dev/null ;;
        codex)  command -v codex &>/dev/null ;;
    esac
}
is_config_done() { return 1; }  # always unchecked — idempotent, safe to re-run

# ─── Interactive Checklist ────────────────────────────────────────────────────

# show_checklist "Header" check_fn "key1" "label1" "key2" "label2" ...
# Outputs selected labels (one per line)
# Returns 1 if user cancelled (Ctrl+C / Esc)
show_checklist() {
    local header="$1" check_fn="$2"
    shift 2

    local options=() selected=()

    info "Detecting installed: $header..."
    while [[ $# -ge 2 ]]; do
        local key="$1" label="$2"
        shift 2
        options+=("$label")
        if "$check_fn" "$key"; then
            selected+=("$label")
        fi
    done

    local selected_arg=""
    if [[ ${#selected[@]} -gt 0 ]]; then
        selected_arg=$(printf '%s,' "${selected[@]}")
        selected_arg="${selected_arg%,}"
    fi

    local result
    if [[ -n "$selected_arg" ]]; then
        result=$(printf '%s\n' "${options[@]}" | gum choose --no-limit \
            --header="$header (space=toggle, enter=confirm)" \
            --selected="$selected_arg") || return 1
    else
        result=$(printf '%s\n' "${options[@]}" | gum choose --no-limit \
            --header="$header (space=toggle, enter=confirm)") || return 1
    fi

    echo "$result"
}

# Map a display label back to its key in a paired array
label_to_key() {
    local label="$1"
    shift
    while [[ $# -ge 2 ]]; do
        if [[ "$2" == "$label" ]]; then
            echo "$1"
            return 0
        fi
        shift 2
    done
    return 1
}

# Compute diff between selected and currently installed
# Sets: to_install[@] to_remove[@]
compute_diff() {
    local check_fn="$1"
    shift
    # remaining args: selected_labels... -- key1 label1 key2 label2 ...
    local -a selected_labels=()
    while [[ "$1" != "--" ]]; do
        selected_labels+=("$1")
        shift
    done
    shift # skip --

    local -a all_keys=() all_labels=()
    while [[ $# -ge 2 ]]; do
        all_keys+=("$1")
        all_labels+=("$2")
        shift 2
    done

    to_install=()
    to_remove=()

    for i in "${!all_keys[@]}"; do
        local key="${all_keys[$i]}"
        local label="${all_labels[$i]}"
        local is_selected=false
        local is_installed=false

        for sel in "${selected_labels[@]+"${selected_labels[@]}"}"; do
            if [[ "$sel" == "$label" ]]; then
                is_selected=true
                break
            fi
        done

        if "$check_fn" "$key"; then
            is_installed=true
        fi

        if $is_selected && ! $is_installed; then
            to_install+=("$key")
        elif ! $is_selected && $is_installed; then
            to_remove+=("$key")
        fi
    done
}

# ─── Config Step Implementations ─────────────────────────────────────────────

run_config_repos() {
    info "Setting up package repositories"

    sudo curl -fsSLo /etc/yum.repos.d/brave-browser.repo \
      https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

    sudo curl -fsSLo /etc/yum.repos.d/vivaldi-fedora.repo \
      https://repo.vivaldi.com/archive/vivaldi-fedora.repo

    sudo tee /etc/yum.repos.d/1password.repo >/dev/null <<'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF

    sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

    local fedora_release
    fedora_release="$(rpm -E %fedora)"
    sudo curl -fsSLo "/etc/pki/rpm-gpg/RPM-GPG-KEY-protonvpn-${fedora_release}-stable" \
      "https://repo.protonvpn.com/fedora-${fedora_release}-stable/public_key.asc"

    sudo tee /etc/yum.repos.d/protonvpn-stable.repo >/dev/null <<EOF
[protonvpn-fedora-stable]
name=Proton VPN Fedora Stable repository
baseurl=https://repo.protonvpn.com/fedora-${fedora_release}-stable/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-protonvpn-${fedora_release}-stable
EOF

    sudo curl -fsSLo /etc/yum.repos.d/claude-desktop.repo \
      https://aaddrick.github.io/claude-desktop-debian/rpm/claude-desktop.repo

    ok "Repos configured"
}

run_config_brave-policy() {
    info "Applying Brave browser policy"

    sudo mkdir -p /etc/brave/policies/managed
    sudo tee /etc/brave/policies/managed/brave-policy.json >/dev/null <<'EOF'
{
  "BraveWalletDisabled": true,
  "BraveRewardsDisabled": true,
  "BraveVPNDisabled": true,
  "BraveAIChatEnabled": false,
  "TorDisabled": true,
  "BraveNewsDisabled": true,
  "BraveTalkDisabled": true,
  "BravePlaylistEnabled": false,
  "BraveSpeedreaderEnabled": false,
  "BraveWaybackMachineEnabled": false,
  "BraveP3AEnabled": false,

  "PasswordManagerEnabled": false,
  "AutofillAddressEnabled": false,
  "AutofillCreditCardEnabled": false,
  "PaymentMethodQueryEnabled": false,
  "ImportSavedPasswords": false,

  "BraveWebDiscoveryEnabled": false,
  "MetricsReportingEnabled": false,
  "BraveStatsPingEnabled": false,
  "UrlKeyedAnonymizedDataCollectionEnabled": false,
  "UserFeedbackAllowed": false,

  "SafeBrowsingEnabled": true,
  "SafeBrowsingExtendedReportingEnabled": false,

  "HttpsUpgradesEnabled": true,
  "SSLVersionMin": "tls1.2",

  "SpellCheckServiceEnabled": false,
  "AlternateErrorPagesEnabled": false,
  "PromotionalTabsEnabled": false,

  "PrivacySandboxPromptEnabled": false,
  "PrivacySandboxAdMeasurementEnabled": false,
  "PrivacySandboxAdTopicsEnabled": false,
  "PrivacySandboxSiteEnabledAdsEnabled": false,

  "ShoppingListEnabled": false,
  "IPFSEnabled": false,

  "DnsOverHttpsMode": "secure",
  "DnsOverHttpsTemplates": "https://dns0.eu/dns-query https://dns.quad9.net/dns-query",

  "DefaultSearchProviderEnabled": true,
  "DefaultSearchProviderName": "Qwant",
  "DefaultSearchProviderSearchURL": "https://www.qwant.com/?q={searchTerms}",
  "DefaultSearchProviderSuggestURL": "https://api.qwant.com/api/suggest/?q={searchTerms}",
  "DefaultSearchProviderKeyword": "qwant",
  "DefaultSearchProviderEncodings": ["UTF-8"]
}
EOF

    ok "Brave policy applied"
}

run_config_1password() {
    info "Configuring 1Password"

    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
      "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password/']"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password/ \
      name "1Password Quick Search"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password/ \
      command "1password --quick-access"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password/ \
      binding "<Alt><Shift>2"

    sudo install -d -m 0755 /etc/1password
    printf '%s\n' vivaldi-bin | sudo tee /etc/1password/custom_allowed_browsers >/dev/null
    sudo chown root:root /etc/1password/custom_allowed_browsers
    sudo chmod 0755 /etc/1password/custom_allowed_browsers

    if [[ -f ~/.local/share/applications/1password.desktop ]]; then
        sed -i 's|Exec=/opt/1Password/1password %U|Exec=env GTK_THEME=Adwaita:dark /opt/1Password/1password --enable-features=WebContentsForceDark %U|' \
          ~/.local/share/applications/1password.desktop
    fi

    ok "1Password configured"
}

run_config_audio() {
    info "Setting up audio device renaming"

    mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
    cp "$SCRIPT_DIR/rename-devices.conf" ~/.config/wireplumber/wireplumber.conf.d/
    systemctl --user restart wireplumber pipewire pipewire-pulse

    ok "Audio device names configured"
}

run_config_newelle() {
    info "Configuring Newelle"

    flatpak override --user io.github.qwersyk.Newelle \
      --talk-name=org.freedesktop.Flatpak --filesystem=home

    ok "Newelle configured (remember to disable Command Virtualization in Settings)"
}

# ─── CLI Tool Install/Uninstall ───────────────────────────────────────────────

install_cli_tool() {
    case "$1" in
        nvm)
            if [[ ! -d "$HOME/.nvm" ]]; then
                local nvm_version
                nvm_version="$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name"' | cut -d'"' -f4)"
                curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash
            fi
            export NVM_DIR="$HOME/.nvm"
            # shellcheck source=/dev/null
            [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
            nvm install --lts
            ;;
        kiro)
            curl -fsSL https://cli.kiro.dev/install | bash
            ;;
        claude)
            curl -fsSL https://claude.ai/install.sh | bash
            ;;
        codex)
            export NVM_DIR="$HOME/.nvm"
            # shellcheck source=/dev/null
            [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
            mkdir -p ~/.local/npm
            npm config set prefix ~/.local/npm
            if ! grep -q '.local/npm/bin' ~/.bashrc 2>/dev/null; then
                echo 'export PATH="$HOME/.local/npm/bin:$PATH"' >> ~/.bashrc
            fi
            export PATH="$HOME/.local/npm/bin:$PATH"
            npm install -g @openai/codex
            ;;
    esac
}

uninstall_cli_tool() {
    case "$1" in
        nvm)
            rm -rf "$HOME/.nvm"
            sed -i '/NVM_DIR/d' ~/.bashrc 2>/dev/null || true
            sed -i '/nvm.sh/d' ~/.bashrc 2>/dev/null || true
            ;;
        kiro)
            rm -f ~/.local/bin/kiro
            ;;
        claude)
            rm -f ~/.local/bin/claude
            ;;
        codex)
            export PATH="$HOME/.local/npm/bin:$PATH"
            npm uninstall -g @openai/codex 2>/dev/null || true
            ;;
    esac
}

# ─── Ensure gext is available ─────────────────────────────────────────────────

ensure_gext() {
    if ! command -v gext &>/dev/null; then
        info "Installing gnome-extensions-cli (gext)"
        pip install --user gnome-extensions-cli
        export PATH="$HOME/.local/bin:$PATH"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    if ! command -v gum &>/dev/null; then
        err "gum is required but not installed. Install it with: sudo rpm-ostree install gum"
        exit 1
    fi

    info "Bazzite Setup"
    echo ""

    # ── 1. System Packages ────────────────────────────────────────────────────

    local rpm_selected
    rpm_selected=$(show_checklist "System Packages (rpm-ostree)" is_rpm_installed "${RPM_PACKAGES[@]}") || true

    local -a rpm_selected_arr=()
    if [[ -n "$rpm_selected" ]]; then
        mapfile -t rpm_selected_arr <<< "$rpm_selected"
    fi

    compute_diff is_rpm_installed "${rpm_selected_arr[@]+"${rpm_selected_arr[@]}"}" -- "${RPM_PACKAGES[@]}"
    local -a rpm_to_install=("${to_install[@]+"${to_install[@]}"}")
    local -a rpm_to_remove=("${to_remove[@]+"${to_remove[@]}"}")

    # ── 2. Flatpaks ───────────────────────────────────────────────────────────

    local flatpak_selected
    flatpak_selected=$(show_checklist "Flatpak Apps" is_flatpak_installed "${FLATPAK_PACKAGES[@]}") || true

    local -a flatpak_selected_arr=()
    if [[ -n "$flatpak_selected" ]]; then
        mapfile -t flatpak_selected_arr <<< "$flatpak_selected"
    fi

    compute_diff is_flatpak_installed "${flatpak_selected_arr[@]+"${flatpak_selected_arr[@]}"}" -- "${FLATPAK_PACKAGES[@]}"
    local -a flatpak_to_install=("${to_install[@]+"${to_install[@]}"}")
    local -a flatpak_to_remove=("${to_remove[@]+"${to_remove[@]}"}")

    # ── 3. GNOME Extensions ───────────────────────────────────────────────────

    local gext_bundled_selected
    gext_bundled_selected=$(show_checklist "GNOME Extensions (bundled — enable/disable)" is_gext_installed "${GNOME_BUNDLED[@]}") || true

    local -a gext_bundled_selected_arr=()
    if [[ -n "$gext_bundled_selected" ]]; then
        mapfile -t gext_bundled_selected_arr <<< "$gext_bundled_selected"
    fi

    compute_diff is_gext_installed "${gext_bundled_selected_arr[@]+"${gext_bundled_selected_arr[@]}"}" -- "${GNOME_BUNDLED[@]}"
    local -a gext_bundled_enable=("${to_install[@]+"${to_install[@]}"}")
    local -a gext_bundled_disable=("${to_remove[@]+"${to_remove[@]}"}")

    local gext_install_selected
    gext_install_selected=$(show_checklist "GNOME Extensions (from extensions.gnome.org)" is_gext_installed "${GNOME_INSTALL[@]}") || true

    local -a gext_install_selected_arr=()
    if [[ -n "$gext_install_selected" ]]; then
        mapfile -t gext_install_selected_arr <<< "$gext_install_selected"
    fi

    compute_diff is_gext_installed "${gext_install_selected_arr[@]+"${gext_install_selected_arr[@]}"}" -- "${GNOME_INSTALL[@]}"
    local -a gext_to_install=("${to_install[@]+"${to_install[@]}"}")
    local -a gext_to_remove=("${to_remove[@]+"${to_remove[@]}"}")

    # ── 4. CLI Tools ──────────────────────────────────────────────────────────

    local cli_selected
    cli_selected=$(show_checklist "CLI & Developer Tools" is_cli_installed "${CLI_TOOLS[@]}") || true

    local -a cli_selected_arr=()
    if [[ -n "$cli_selected" ]]; then
        mapfile -t cli_selected_arr <<< "$cli_selected"
    fi

    compute_diff is_cli_installed "${cli_selected_arr[@]+"${cli_selected_arr[@]}"}" -- "${CLI_TOOLS[@]}"
    local -a cli_to_install=("${to_install[@]+"${to_install[@]}"}")
    local -a cli_to_remove=("${to_remove[@]+"${to_remove[@]}"}")

    # ── 5. Configuration ──────────────────────────────────────────────────────

    local config_selected
    config_selected=$(show_checklist "Configuration Steps (idempotent)" is_config_done "${CONFIG_STEPS[@]}") || true

    local -a config_selected_arr=()
    if [[ -n "$config_selected" ]]; then
        mapfile -t config_selected_arr <<< "$config_selected"
    fi

    # ── Summary ───────────────────────────────────────────────────────────────

    echo ""
    info "Summary of changes:"
    local has_changes=false

    if [[ ${#rpm_to_install[@]} -gt 0 ]]; then
        echo "  Install (rpm-ostree): ${rpm_to_install[*]}"
        has_changes=true
    fi
    if [[ ${#rpm_to_remove[@]} -gt 0 ]]; then
        echo "  Remove  (rpm-ostree): ${rpm_to_remove[*]}"
        has_changes=true
    fi
    if [[ ${#flatpak_to_install[@]} -gt 0 ]]; then
        echo "  Install (flatpak):    ${flatpak_to_install[*]}"
        has_changes=true
    fi
    if [[ ${#flatpak_to_remove[@]} -gt 0 ]]; then
        echo "  Remove  (flatpak):    ${flatpak_to_remove[*]}"
        has_changes=true
    fi
    if [[ ${#gext_bundled_enable[@]} -gt 0 ]]; then
        echo "  Enable  (extensions): ${gext_bundled_enable[*]}"
        has_changes=true
    fi
    if [[ ${#gext_bundled_disable[@]} -gt 0 ]]; then
        echo "  Disable (extensions): ${gext_bundled_disable[*]}"
        has_changes=true
    fi
    if [[ ${#gext_to_install[@]} -gt 0 ]]; then
        echo "  Install (extensions): ${gext_to_install[*]}"
        has_changes=true
    fi
    if [[ ${#gext_to_remove[@]} -gt 0 ]]; then
        echo "  Remove  (extensions): ${gext_to_remove[*]}"
        has_changes=true
    fi
    if [[ ${#cli_to_install[@]} -gt 0 ]]; then
        echo "  Install (CLI):        ${cli_to_install[*]}"
        has_changes=true
    fi
    if [[ ${#cli_to_remove[@]} -gt 0 ]]; then
        echo "  Remove  (CLI):        ${cli_to_remove[*]}"
        has_changes=true
    fi
    if [[ ${#config_selected_arr[@]} -gt 0 ]]; then
        echo "  Run config:           ${config_selected_arr[*]}"
        has_changes=true
    fi

    if ! $has_changes; then
        ok "No changes selected."
        exit 0
    fi

    echo ""
    if ! gum confirm "Apply these changes?"; then
        warn "Cancelled."
        exit 0
    fi

    # ── Execute ───────────────────────────────────────────────────────────────

    # Config: repos must run before rpm-ostree installs
    for cfg in "${config_selected_arr[@]+"${config_selected_arr[@]}"}"; do
        local cfg_key
        cfg_key=$(label_to_key "$cfg" "${CONFIG_STEPS[@]}") || continue
        "run_config_${cfg_key}"
    done

    # rpm-ostree
    if [[ ${#rpm_to_install[@]} -gt 0 ]]; then
        info "Installing system packages"
        # Ensure repos are set up even if not selected as config step
        if ! printf '%s\n' "${config_selected_arr[@]+"${config_selected_arr[@]}"}" | grep -qF "Package Repositories"; then
            run_config_repos
        fi
        sudo rpm-ostree install --idempotent "${rpm_to_install[@]}"
        needs_reboot=true
        ok "System packages layered"
    fi
    if [[ ${#rpm_to_remove[@]} -gt 0 ]]; then
        info "Removing system packages"
        sudo rpm-ostree uninstall "${rpm_to_remove[@]}"
        needs_reboot=true
        ok "System packages removed"
    fi

    # Flatpaks
    if [[ ${#flatpak_to_install[@]} -gt 0 ]]; then
        info "Installing Flatpaks"
        flatpak install -y --noninteractive flathub "${flatpak_to_install[@]}"
        ok "Flatpaks installed"
    fi
    if [[ ${#flatpak_to_remove[@]} -gt 0 ]]; then
        info "Removing Flatpaks"
        flatpak uninstall -y --noninteractive "${flatpak_to_remove[@]}"
        ok "Flatpaks removed"
    fi

    # GNOME extensions (bundled)
    for ext in "${gext_bundled_enable[@]+"${gext_bundled_enable[@]}"}"; do
        info "Enabling $ext"
        gnome-extensions enable "$ext"
    done
    for ext in "${gext_bundled_disable[@]+"${gext_bundled_disable[@]}"}"; do
        info "Disabling $ext"
        gnome-extensions disable "$ext"
    done

    # GNOME extensions (installable)
    if [[ ${#gext_to_install[@]} -gt 0 ]] || [[ ${#gext_to_remove[@]} -gt 0 ]]; then
        ensure_gext
    fi
    for ext in "${gext_to_install[@]+"${gext_to_install[@]}"}"; do
        info "Installing extension $ext"
        gext install "$ext"
    done
    for ext in "${gext_to_remove[@]+"${gext_to_remove[@]}"}"; do
        info "Removing extension $ext"
        gext uninstall "$ext"
    done

    # CLI tools
    for tool in "${cli_to_install[@]+"${cli_to_install[@]}"}"; do
        info "Installing $tool"
        install_cli_tool "$tool"
    done
    for tool in "${cli_to_remove[@]+"${cli_to_remove[@]}"}"; do
        info "Removing $tool"
        uninstall_cli_tool "$tool"
    done

    # ── Done ──────────────────────────────────────────────────────────────────

    echo ""
    ok "All done!"

    if $needs_reboot; then
        echo ""
        warn "rpm-ostree changes require a reboot."
        if gum confirm "Reboot now?"; then
            systemctl reboot
        else
            warn "Remember to reboot before changes take effect."
        fi
    fi
}

main "$@"
