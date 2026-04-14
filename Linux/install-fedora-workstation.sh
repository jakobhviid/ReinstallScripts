#!/usr/bin/env bash
set -uo pipefail

# Fedora Workstation interactive setup script
# Re-runnable — detects installed state, lets you add/remove packages.
# Requires: gum (installed automatically if missing)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Helpers ──────────────────────────────────────────────────────────────────

info()  { printf '\033[1;34m▸ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
err()   { printf '\033[1;31m✗ %s\033[0m\n' "$*"; }

# ─── Bootstrap gum ───────────────────────────────────────────────────────────

if ! command -v gum &>/dev/null; then
    info "Installing gum (interactive UI toolkit)"
    sudo dnf install -y gum
fi

# ─── Package Lists ────────────────────────────────────────────────────────────
# Paired arrays: "key" "Display Name" ...

DNF_PACKAGES=(
    "podman-docker"                          "Podman Docker CLI"
    "podman-compose"                         "Podman Compose"
    "brave-browser"                          "Brave Browser"
    "1password"                              "1Password"
    "code"                                   "VS Code"
    "proton-vpn-gnome-desktop"               "Proton VPN"
    "zsh"                                    "Zsh"
    "distrobox"                              "Distrobox"
    "libgda libgda-sqlite"                   "SQLite (libgda)"
    "piper"                                  "Piper (mouse config)"
    "nodejs nodejs-npm"                      "Node.js + npm"
    "claude-desktop"                         "Claude Desktop"
    "nautilus-python"                        "Nautilus Python"
    "nautilus-gsconnect"                     "Nautilus GSConnect"
    "file-roller-nautilus"                   "File Roller (Nautilus)"
    "papers-nautilus"                        "Papers (Nautilus)"
    "gnome-shell-extension-appindicator"     "AppIndicator Extension"
    "gnome-shell-extension-blur-my-shell"    "Blur my Shell Extension"
    "gnome-shell-extension-caffeine"         "Caffeine Extension"
    "gnome-shell-extension-dash-to-panel"    "Dash to Panel"
    "gnome-shell-extension-dash-to-dock"     "Dash to Dock"
)

FLATPAK_PACKAGES=(
    "com.discordapp.Discord"                 "Discord"
    "org.gnome.baobab"                       "Disk Usage Analyzer"
    "com.ranfdev.DistroShelf"                "DistroShelf"
    "com.mattjakeman.ExtensionManager"       "Extension Manager"
    "com.github.tchx84.Flatseal"            "Flatseal"
    "org.gimp.GIMP"                          "GIMP"
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
    "fr.handbrake.ghb"                       "HandBrake"
    "im.riot.Riot"                           "Element"
    "io.github.cleomenezesjr.aurea"          "Aurea"
    "io.github.shonebinu.Brief"              "Brief"
    "io.github.sitraorg.sitra"               "Sitra"
    "io.github.wartybix.Constrict"           "Constrict"
    "io.gitlab.theevilskeleton.Upscaler"     "Upscaler"
    "me.proton.Pass"                         "Proton Pass"
    "net.trowell.typesetter"                 "Typesetter"
    "org.altlinux.Tuner"                     "Tuner"
    "org.fedoraproject.MediaWriter"          "Fedora Media Writer"
    "org.gnome.Firmware"                     "Firmware"
    "org.gnome.Fractal"                      "Fractal"
    "org.localsend.localsend_app"            "LocalSend"
    "org.signal.Signal"                      "Signal"
    "org.zotero.Zotero"                      "Zotero"
)

# Install from extensions.gnome.org
GNOME_INSTALL=(
    "CoverflowAltTab@palatis.blogspot.com"                   "Coverflow Alt-Tab"
    "tilingshell@ferrarodomenico.com"                         "Tiling Shell"
    "compiz-alike-magic-lamp-effect@hermes83.github.com"      "Magic Lamp Effect"
    "hotedge@jonathan.jdoda.ca"                               "Hot Edge"
    "restartto@tiagoporsch.github.io"                         "Restart To"
    "copyous@boerdereinar.dev"                                "Copyous (clipboard)"
)

CLI_TOOLS=(
    "brew"       "Homebrew"
    "zsh-setup"  "Zsh Plugins + Starship"
    "nvm"        "NVM + Node LTS"
    "claude"     "Claude Code"
    "codex"      "Codex CLI"
)

# ─── Detection ────────────────────────────────────────────────────────────────

is_dnf_installed() {
    local pkg
    for pkg in $1; do
        rpm -q "$pkg" &>/dev/null || return 1
    done
}
is_flatpak_installed() { flatpak info "$1" &>/dev/null 2>&1; }
is_gext_installed()    { gnome-extensions list 2>/dev/null | grep -qF "$1"; }
is_cli_installed() {
    case "$1" in
        brew)      command -v brew &>/dev/null || [[ -d /home/linuxbrew/.linuxbrew ]] ;;
        zsh-setup) [[ -f "$HOME/.zshrc" ]] && command -v brew &>/dev/null && brew list starship &>/dev/null ;;
        nvm)       [[ -d "$HOME/.nvm" ]] ;;
        claude)    command -v claude &>/dev/null ;;
        codex)     command -v codex &>/dev/null ;;
    esac
}

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

    local -a gum_args=(--no-limit --header="$header  |  ↑↓ navigate · x/space toggle · enter confirm")
    for sel in "${selected[@]+"${selected[@]}"}"; do
        gum_args+=(--selected="$sel")
    done

    local result
    result=$(printf '%s\n' "${options[@]}" | gum choose "${gum_args[@]}") || return 1

    echo "$result"
}

# Map a key back to its display label in a paired array
key_to_label() {
    local key="$1"
    shift
    while [[ $# -ge 2 ]]; do
        if [[ "$1" == "$key" ]]; then
            echo "$2"
            return 0
        fi
        shift 2
    done
    echo "$key"  # fallback to key itself
}

# Compute diff between selected and currently installed
# Sets: to_install[@] to_remove[@]
compute_diff() {
    local check_fn="$1"
    shift
    # remaining args: selected_labels... -- key1 label1 key2 label2 ...
    local -a selected_labels=()
    while [[ $# -gt 0 && "$1" != "--" ]]; do
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

# ─── RPM Fusion & Multimedia Codecs ─────────────────────────────────────────

setup_rpmfusion() {
    if ! rpm -q rpmfusion-free-release &>/dev/null; then
        info "Installing RPM Fusion repositories"
        sudo dnf install -y \
          "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
          "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
        ok "RPM Fusion installed"
    fi
}

setup_multimedia_codecs() {
    info "Setting up multimedia codecs"

    # Swap ffmpeg-free for full ffmpeg
    if ! rpm -q ffmpeg &>/dev/null; then
        sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
    fi

    sudo dnf install -y \
      gstreamer1-plugins-bad-freeworld \
      gstreamer1-plugins-ugly \
      gstreamer1-plugins-good-extras \
      gstreamer1-libav \
      libva libva-utils \
      lame lame-libs

    sudo dnf group install -y multimedia

    ok "Multimedia codecs installed"
}

# ─── Config Step Implementations ─────────────────────────────────────────────

# Per-package repo setup — called automatically when installing a package that needs one
ensure_repo() {
    case "$1" in
        brave-browser)
            if [[ ! -f /etc/yum.repos.d/brave-browser.repo ]]; then
                info "Adding Brave repository"
                sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
            fi
            ;;
        1password)
            if [[ ! -f /etc/yum.repos.d/1password.repo ]]; then
                info "Adding 1Password repository"
                sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
                sudo tee /etc/yum.repos.d/1password.repo >/dev/null <<'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF
            fi
            ;;
        code)
            if [[ ! -f /etc/yum.repos.d/vscode.repo ]]; then
                info "Adding VS Code repository"
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
            fi
            ;;
        proton-vpn-gnome-desktop)
            if [[ ! -f /etc/yum.repos.d/protonvpn-stable.repo ]]; then
                info "Adding Proton VPN repository"
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
            fi
            ;;
        claude-desktop)
            if [[ ! -f /etc/yum.repos.d/claude-desktop.repo ]]; then
                info "Adding Claude Desktop repository"
                sudo curl -fsSLo /etc/yum.repos.d/claude-desktop.repo \
                  https://aaddrick.github.io/claude-desktop-debian/rpm/claude-desktop.repo
            fi
            ;;
    esac
}

run_config_brave_policy() {
    info "Applying Brave browser policy"

    sudo mkdir -p /etc/brave/policies/managed
    if [[ -f "$SCRIPT_DIR/brave-policy.json" ]]; then
        sudo cp "$SCRIPT_DIR/brave-policy.json" /etc/brave/policies/managed/brave-policy.json
    else
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
    fi

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

    # Fix dark titlebar and enable native Wayland
    mkdir -p ~/.local/share/applications
    if [[ ! -f ~/.local/share/applications/1password.desktop ]]; then
        cp /usr/share/applications/1password.desktop ~/.local/share/applications/1password.desktop
    fi
    sed -i 's|Exec=/opt/1Password/1password %U|Exec=env GTK_THEME=Adwaita:dark /opt/1Password/1password --enable-features=UseOzonePlatform --ozone-platform=wayland %U|' \
      ~/.local/share/applications/1password.desktop

    ok "1Password configured"
}

run_config_audio() {
    mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
    local dest=~/.config/wireplumber/wireplumber.conf.d/rename-devices.conf
    if [[ -f "$SCRIPT_DIR/rename-devices.conf" ]] && ! diff -q "$SCRIPT_DIR/rename-devices.conf" "$dest" &>/dev/null; then
        info "Updating audio device names"
        cp "$SCRIPT_DIR/rename-devices.conf" "$dest"
        systemctl --user restart wireplumber pipewire pipewire-pulse
        ok "Audio device names configured"
    fi
}

run_config_newelle() {
    info "Configuring Newelle"

    flatpak override --user io.github.qwersyk.Newelle \
      --talk-name=org.freedesktop.Flatpak --filesystem=home

    ok "Newelle configured (remember to disable Command Virtualization in Settings)"
}

# ─── Zsh Setup ────────────────────────────────────────────────────────────────

install_zsh_setup() {
    if ! command -v brew &>/dev/null; then
        err "Homebrew is required for Zsh setup. Select 'Homebrew' first."
        return 1
    fi

    brew install just
    just -f "$SCRIPT_DIR/justfile" zsh

    ok "Zsh setup complete (restart your terminal to activate)"
}

# ─── CLI Tool Install/Uninstall ───────────────────────────────────────────────

install_cli_tool() {
    case "$1" in
        brew)
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            if [[ -d /home/linuxbrew/.linuxbrew ]]; then
                eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
                # Add to .bashrc
                if ! grep -q 'linuxbrew' ~/.bashrc 2>/dev/null; then
                    printf '\neval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"\n' >> ~/.bashrc
                fi
                # Add to .zshrc if zsh is present
                if [[ -f ~/.zshrc ]] && ! grep -q 'linuxbrew' ~/.zshrc 2>/dev/null; then
                    printf '\neval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"\n' >> ~/.zshrc
                fi
            fi
            ;;
        zsh-setup)
            install_zsh_setup
            ;;
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
        claude)
            brew install claude-code
            ;;
        codex)
            if ! command -v npm &>/dev/null; then
                err "npm is required for Codex. Select 'Node.js + npm' in System Packages first."
                return 1
            fi
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
        brew)
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
            ;;
        zsh-setup)
            warn "Zsh setup removal: manually clean ~/.zshrc and ~/.config/starship.toml"
            ;;
        nvm)
            rm -rf "$HOME/.nvm"
            sed -i '/NVM_DIR/d' ~/.bashrc 2>/dev/null || true
            sed -i '/nvm.sh/d' ~/.bashrc 2>/dev/null || true
            ;;
        claude)
            brew uninstall claude-code 2>/dev/null || true
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
        if command -v pipx &>/dev/null; then
            info "Installing gnome-extensions-cli (gext) via pipx"
            pipx install gnome-extensions-cli
        else
            info "Installing gnome-extensions-cli (gext) via pip"
            pip install --user gnome-extensions-cli
        fi
        export PATH="$HOME/.local/bin:$PATH"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    info "Fedora Workstation Setup"
    echo ""

    # ── 0. RPM Fusion & Codecs ────────────────────────────────────────────────

    if gum confirm "Set up RPM Fusion and multimedia codecs?"; then
        setup_rpmfusion
        setup_multimedia_codecs
    fi

    # ── 1. System Packages ────────────────────────────────────────────────────

    local dnf_selected
    dnf_selected=$(show_checklist "System Packages (dnf)" is_dnf_installed "${DNF_PACKAGES[@]}") || true

    local -a dnf_selected_arr=()
    if [[ -n "$dnf_selected" ]]; then
        mapfile -t dnf_selected_arr <<< "$dnf_selected"
    fi

    compute_diff is_dnf_installed "${dnf_selected_arr[@]+"${dnf_selected_arr[@]}"}" -- "${DNF_PACKAGES[@]}"
    local -a dnf_to_install=("${to_install[@]+"${to_install[@]}"}")
    local -a dnf_to_remove=("${to_remove[@]+"${to_remove[@]}"}")

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

    # ── Summary ───────────────────────────────────────────────────────────────

    echo ""
    info "Summary of changes:"
    local has_changes=false

    if [[ ${#dnf_to_install[@]} -gt 0 ]]; then
        local -a dnf_install_labels=()
        for key in "${dnf_to_install[@]}"; do dnf_install_labels+=("$(key_to_label "$key" "${DNF_PACKAGES[@]}")"); done
        printf '  %-22s %s\n' "Install (dnf):" "${dnf_install_labels[*]}"
        has_changes=true
    fi
    if [[ ${#dnf_to_remove[@]} -gt 0 ]]; then
        local -a dnf_remove_labels=()
        for key in "${dnf_to_remove[@]}"; do dnf_remove_labels+=("$(key_to_label "$key" "${DNF_PACKAGES[@]}")"); done
        printf '  %-22s %s\n' "Remove (dnf):" "${dnf_remove_labels[*]}"
        has_changes=true
    fi
    if [[ ${#flatpak_to_install[@]} -gt 0 ]]; then
        local -a fp_install_labels=()
        for key in "${flatpak_to_install[@]}"; do fp_install_labels+=("$(key_to_label "$key" "${FLATPAK_PACKAGES[@]}")"); done
        printf '  %-22s %s\n' "Install (flatpak):" "${fp_install_labels[*]}"
        has_changes=true
    fi
    if [[ ${#flatpak_to_remove[@]} -gt 0 ]]; then
        local -a fp_remove_labels=()
        for key in "${flatpak_to_remove[@]}"; do fp_remove_labels+=("$(key_to_label "$key" "${FLATPAK_PACKAGES[@]}")"); done
        printf '  %-22s %s\n' "Remove (flatpak):" "${fp_remove_labels[*]}"
        has_changes=true
    fi
    if [[ ${#gext_to_install[@]} -gt 0 ]]; then
        local -a gei_labels=()
        for key in "${gext_to_install[@]}"; do gei_labels+=("$(key_to_label "$key" "${GNOME_INSTALL[@]}")"); done
        printf '  %-22s %s\n' "Install (extensions):" "${gei_labels[*]}"
        has_changes=true
    fi
    if [[ ${#gext_to_remove[@]} -gt 0 ]]; then
        local -a ger_labels=()
        for key in "${gext_to_remove[@]}"; do ger_labels+=("$(key_to_label "$key" "${GNOME_INSTALL[@]}")"); done
        printf '  %-22s %s\n' "Remove (extensions):" "${ger_labels[*]}"
        has_changes=true
    fi
    if [[ ${#cli_to_install[@]} -gt 0 ]]; then
        local -a cli_i_labels=()
        for key in "${cli_to_install[@]}"; do cli_i_labels+=("$(key_to_label "$key" "${CLI_TOOLS[@]}")"); done
        printf '  %-22s %s\n' "Install (CLI):" "${cli_i_labels[*]}"
        has_changes=true
    fi
    if [[ ${#cli_to_remove[@]} -gt 0 ]]; then
        local -a cli_r_labels=()
        for key in "${cli_to_remove[@]}"; do cli_r_labels+=("$(key_to_label "$key" "${CLI_TOOLS[@]}")"); done
        printf '  %-22s %s\n' "Remove (CLI):" "${cli_r_labels[*]}"
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

    # dnf — expand grouped keys (e.g. "nodejs nodejs-npm") into individual packages
    local -a dnf_pkgs_install=() dnf_pkgs_remove=()
    for group in "${dnf_to_install[@]+"${dnf_to_install[@]}"}"; do
        for pkg in $group; do
            ensure_repo "$pkg"
            dnf_pkgs_install+=("$pkg")
        done
    done
    for group in "${dnf_to_remove[@]+"${dnf_to_remove[@]}"}"; do
        for pkg in $group; do
            dnf_pkgs_remove+=("$pkg")
        done
    done

    if [[ ${#dnf_pkgs_install[@]} -gt 0 ]]; then
        info "Installing system packages"
        sudo dnf install -y "${dnf_pkgs_install[@]}"
        ok "System packages installed"
    fi
    if [[ ${#dnf_pkgs_remove[@]} -gt 0 ]]; then
        info "Removing system packages"
        sudo dnf remove -y "${dnf_pkgs_remove[@]}"
        ok "System packages removed"
    fi

    # App-specific config — apply if the app is installed (whether just now or previously)
    if rpm -q brave-browser &>/dev/null; then
        run_config_brave_policy
    fi
    if rpm -q 1password &>/dev/null; then
        run_config_1password
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

    # Newelle config — apply if Newelle is selected
    if is_flatpak_installed io.github.qwersyk.Newelle || printf '%s\n' "${flatpak_to_install[@]+"${flatpak_to_install[@]}"}" | grep -qF "io.github.qwersyk.Newelle"; then
        run_config_newelle
    fi

    # GNOME extensions
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

    # Set Zsh as default shell if installed and not already default
    # Use /usr/bin/zsh explicitly — brew's zsh is not in /etc/shells
    if [[ -x /usr/bin/zsh ]] && [[ "$(basename "$SHELL")" != "zsh" ]]; then
        info "Setting Zsh as default shell"
        chsh -s /usr/bin/zsh
        ok "Zsh set as default shell (takes effect on next login)"
    fi

    # Audio device renaming (always applied)
    run_config_audio

    # ── Done ──────────────────────────────────────────────────────────────────

    echo ""
    ok "All done!"
}

main "$@"
