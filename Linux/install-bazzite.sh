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
    "podman-compose"                         "Podman Compose"
    "brave-browser"                          "Brave Browser"
    "1password"                              "1Password"
    "code"                                   "VS Code"
    "proton-vpn-gnome-desktop"               "Proton VPN"
    "gnome-shell-extension-dash-to-panel"    "Dash to Panel"
    "gnome-shell-extension-dash-to-dock"     "Dash to Dock"
    "zsh"                                    "Zsh"
    "libgda libgda-sqlite"                   "SQLite (libgda)"
    "piper"                                  "Piper (mouse config)"
    "nodejs nodejs-npm"                      "Node.js + npm"
    "claude-desktop"                         "Claude Desktop"
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
    "brew"       "Homebrew"
    "zsh-setup"  "Zsh Plugins + Starship"
    "nvm"        "NVM + Node LTS"
    "claude"     "Claude Code"
    "codex"      "Codex CLI"
)

# ─── Detection ────────────────────────────────────────────────────────────────

is_rpm_installed() {
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

# ─── Config Step Implementations ─────────────────────────────────────────────

# Per-package repo setup — called automatically when installing a package that needs one
ensure_repo() {
    case "$1" in
        brave-browser)
            if [[ ! -f /etc/yum.repos.d/brave-browser.repo ]]; then
                info "Adding Brave repository"
                sudo curl -fsSLo /etc/yum.repos.d/brave-browser.repo \
                  https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
            fi
            ;;
        1password)
            if [[ ! -f /etc/yum.repos.d/1password.repo ]]; then
                info "Adding 1Password repository"
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
    mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
    local dest=~/.config/wireplumber/wireplumber.conf.d/rename-devices.conf
    if ! diff -q "$SCRIPT_DIR/rename-devices.conf" "$dest" &>/dev/null; then
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

    info "Installing Zsh plugins via Homebrew"
    brew install \
        starship \
        zsh-autosuggestions \
        zsh-syntax-highlighting \
        zsh-completions \
        zsh-history-substring-search \
        zsh-autopair \
        zsh-you-should-use \
        bat \
        eza \
        fzf \
        fzf-tab \
        zoxide

    # Back up existing .zshrc
    if [[ -f ~/.zshrc ]]; then
        cp ~/.zshrc ~/.zshrc.bak
        info "Backed up existing .zshrc to .zshrc.bak"
    fi

    local brew_prefix
    brew_prefix="$(brew --prefix)"

    cat > ~/.zshrc <<ZSHRC
# ─── Homebrew ─────────────────────────────────────────────────────────────────
if [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
elif [[ -d /opt/homebrew ]]; then
    eval "\$(/opt/homebrew/bin/brew shellenv zsh)"
fi

# ─── Prompt (Starship) ──────────────────────────────────────────────────────
eval "\$(starship init zsh)"

# ─── Plugins ──────────────────────────────────────────────────────────────────
source $brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $brew_prefix/share/zsh-history-substring-search/zsh-history-substring-search.zsh
source $brew_prefix/share/zsh-autopair/autopair.zsh
source $brew_prefix/share/zsh-you-should-use/you-should-use.plugin.zsh
source $brew_prefix/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh

# ─── fzf shell integration (Ctrl+R history, Ctrl+T file finder, Alt+C cd) ────
source <(fzf --zsh)

# ─── fzf previews ────────────────────────────────────────────────────────────
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --line-range :200 {} 2>/dev/null || head -200 {}'"
export FZF_ALT_C_OPTS="--preview 'ls -la {}'"

# ─── Completions ──────────────────────────────────────────────────────────────
FPATH=$brew_prefix/share/zsh-completions:$brew_prefix/share/zsh/site-functions:\$FPATH
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# ─── History ──────────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt AUTO_CD
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

# ─── Git aliases ──────────────────────────────────────────────────────────────
alias gs='git status'
alias gp='git pull'
alias gpp='git push'
alias ga='git add .'
gc() { [[ -z "\$*" ]] && echo "Commit message required" && return 1; git commit -m "\$*" }
gcp() { [[ -z "\$*" ]] && echo "Commit message required" && return 1; git commit -am "\$*" && git push }

# ─── Podman aliases ──────────────────────────────────────────────────────────
alias pc='podman compose'
alias pcu='podman compose up -d'
alias pcd='podman compose down'
alias pcl='podman compose ps'

# ─── eza aliases (modern ls) ─────────────────────────────────────────────────
alias ls='eza'
alias ll='eza -l --git'
alias la='eza -la --git'
alias lt='eza --tree --level=2'

# ─── Key bindings ─────────────────────────────────────────────────────────────
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# ─── Zoxide (smart cd) ───────────────────────────────────────────────────────
eval "\$(zoxide init zsh --cmd cd)"

# ─── NVM (if installed) ──────────────────────────────────────────────────────
if [[ -d "\$HOME/.nvm" ]]; then
    export NVM_DIR="\$HOME/.nvm"
    [ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
fi

# ─── Local bins ──────────────────────────────────────────────────────────────
[[ -d "\$HOME/.local/bin" ]] && export PATH="\$HOME/.local/bin:\$PATH"
[[ -d "\$HOME/.local/npm/bin" ]] && export PATH="\$HOME/.local/npm/bin:\$PATH"

ZSHRC

    # Deploy Starship config
    mkdir -p ~/.config
    cp "$SCRIPT_DIR/../starship.toml" ~/.config/starship.toml

    # Clean up old Powerlevel10k artifacts
    rm -f ~/.p10k.zsh
    rm -f "${XDG_CACHE_HOME:-$HOME/.cache}"/p10k-instant-prompt-*.zsh
    brew uninstall powerlevel10k 2>/dev/null || true
    brew untap romkatv/powerlevel10k 2>/dev/null || true

    # Set zsh as default shell
    if [[ "$(basename "$SHELL")" != "zsh" ]]; then
        info "Setting Zsh as default shell"
        sudo usermod -s "$(which zsh)" "$USER"
    fi

    info "Configuring Git"
    git config --global user.name "Jakob Hviid, PhD"
    git config --global user.email "jakob@hviid.phd"
    git config --global pull.rebase true

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
            curl -fsSL https://claude.ai/install.sh | bash
            # Ensure ~/.local/bin is in PATH for current and future sessions
            if ! grep -q '\.local/bin' ~/.zshrc 2>/dev/null; then
                sed -i '/# ─── Local overrides/i # ─── Local bins ──────────────────────────────────────────────────────────────\n[[ -d "$HOME/.local/bin" ]] \&\& export PATH="$HOME/.local/bin:$PATH"\n' ~/.zshrc 2>/dev/null || true
            fi
            export PATH="$HOME/.local/bin:$PATH"
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

    if [[ ${#rpm_to_install[@]} -gt 0 ]]; then
        local -a rpm_install_labels=()
        for key in "${rpm_to_install[@]}"; do rpm_install_labels+=("$(key_to_label "$key" "${RPM_PACKAGES[@]}")"); done
        printf '  %-22s %s\n' "Install (rpm-ostree):" "${rpm_install_labels[*]}"
        has_changes=true
    fi
    if [[ ${#rpm_to_remove[@]} -gt 0 ]]; then
        local -a rpm_remove_labels=()
        for key in "${rpm_to_remove[@]}"; do rpm_remove_labels+=("$(key_to_label "$key" "${RPM_PACKAGES[@]}")"); done
        printf '  %-22s %s\n' "Remove (rpm-ostree):" "${rpm_remove_labels[*]}"
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

    # rpm-ostree — expand grouped keys (e.g. "nodejs nodejs-npm") into individual packages
    local -a rpm_pkgs_install=() rpm_pkgs_remove=()
    for group in "${rpm_to_install[@]+"${rpm_to_install[@]}"}"; do
        for pkg in $group; do
            ensure_repo "$pkg"
            rpm_pkgs_install+=("$pkg")
        done
    done
    for group in "${rpm_to_remove[@]+"${rpm_to_remove[@]}"}"; do
        for pkg in $group; do
            rpm_pkgs_remove+=("$pkg")
        done
    done

    if [[ ${#rpm_pkgs_install[@]} -gt 0 ]]; then
        info "Installing system packages"
        sudo rpm-ostree install --idempotent "${rpm_pkgs_install[@]}"
        needs_reboot=true
        ok "System packages layered"
    fi
    if [[ ${#rpm_pkgs_remove[@]} -gt 0 ]]; then
        info "Removing system packages"
        sudo rpm-ostree uninstall "${rpm_pkgs_remove[@]}"
        needs_reboot=true
        ok "System packages removed"
    fi

    # App-specific config — only apply if app was just installed
    if printf '%s\n' "${rpm_to_install[@]+"${rpm_to_install[@]}"}" | grep -qF "brave-browser"; then
        run_config_brave_policy
    fi
    if printf '%s\n' "${rpm_to_install[@]+"${rpm_to_install[@]}"}" | grep -qF "1password"; then
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

    # Audio device renaming (always applied)
    run_config_audio

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
