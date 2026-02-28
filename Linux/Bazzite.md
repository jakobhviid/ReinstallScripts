# Getting Started with Bazzite

## CLI Tools

**Kiro CLI** ([kiro.dev/cli](https://kiro.dev/cli/))
```sh
curl -fsSL https://cli.kiro.dev/install | bash
```

**helvum**, **zed** — install via your package manager or Flatpak.

**NVM + Node LTS**
```sh
# Install NVM
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
# Reload shell
source ~/.nvm/nvm.sh
# Install Node LTS
nvm install --lts
```

**Codex CLI**
```sh
npm install -g @openai/codex-cli
export PATH="${HOME}/.local/bin:${PATH}"
```

---

## RPM-OSTree Apps

### Repo Setup

```sh
# Brave
sudo curl -fsSLo /etc/yum.repos.d/brave-browser.repo \
  https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

# Vivaldi
sudo curl -fsSLo /etc/yum.repos.d/vivaldi-fedora.repo \
  https://repo.vivaldi.com/archive/vivaldi-fedora.repo

# 1Password
sudo tee /etc/yum.repos.d/1password.repo >/dev/null <<'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF

# VS Code
sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Proton VPN
FEDORA_RELEASE="$(rpm -E %fedora)"
sudo curl -fsSLo "/etc/pki/rpm-gpg/RPM-GPG-KEY-protonvpn-${FEDORA_RELEASE}-stable" \
  "https://repo.protonvpn.com/fedora-${FEDORA_RELEASE}-stable/public_key.asc"

sudo tee /etc/yum.repos.d/protonvpn-stable.repo >/dev/null <<EOF
[protonvpn-fedora-stable]
name=Proton VPN Fedora Stable repository
baseurl=https://repo.protonvpn.com/fedora-${FEDORA_RELEASE}-stable/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-protonvpn-${FEDORA_RELEASE}-stable
EOF
```

### Layer Packages

```sh
sudo rpm-ostree install \
  podman-docker \
  podman-compose \
  docker-compose \
  brave-browser \
  vivaldi-stable \
  1password \
  code \
  proton-vpn-gnome-desktop \
  gnome-shell-extension-dash-to-panel \
  gnome-shell-extension-dash-to-dock \
  zsh \
  libgda \
  libgda-sqlite \
  piper \
  nodejs \
  nodejs-npm
```

> On traditional Fedora (not Bazzite/Silverblue), also install:
> ```sh
> gnome-sushi sushi nautilus-python file-roller-nautilus gnome-terminal-nautilus seahorse-nautilus
> ```

### Flatpaks

```sh
flatpak install -y flathub \
  com.discordapp.Discord \
  org.gnome.baobab \
  com.ranfdev.DistroShelf \
  com.mattjakeman.ExtensionManager \
  com.github.tchx84.Flatseal \
  org.gimp.GIMP \
  com.github.git_cola.git-cola \
  be.alexandervanhee.gradia \
  org.libreoffice.LibreOffice \
  io.missioncenter.MissionCenter \
  io.github.qwersyk.Newelle \
  com.nextcloud.desktopclient.nextcloud \
  org.gnome.World.PikaBackup \
  io.github.fabrialberio.pinapp \
  me.proton.Mail \
  ch.protonmail.protonmail-bridge \
  dev.dergs.Tonearm \
  io.github.flattool.Warehouse \
  io.gitlab.news_flash.NewsFlash \
  it.mijorus.gearlever \
  io.gitlab.adhami3310.Converter \
  io.github.alainm23.planify \
  com.bilingify.readest \
  com.github.johnfactotum.Foliate
```

### Manual Installs

```sh
# Claude Code
curl -fsSL https://claude.ai/install.sh | bash

# Codex
mkdir -p ~/.local/npm
npm config set prefix ~/.local/npm
echo 'export PATH="$HOME/.local/npm/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
npm install -g @openai/codex
```

---

## App Fixes

### 1Password — Global Shortcut

```sh
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
  "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password/']" &&
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password/ \
  name "1Password Quick Search" &&
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password/ \
  command "1password --quick-access" &&
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password/ \
  binding "<Alt><Shift>2"
```

### 1Password — Vivaldi Compatibility

```sh
sudo install -d -m 0755 /etc/1password
printf '%s\n' vivaldi-bin | sudo tee /etc/1password/custom_allowed_browsers >/dev/null
sudo chown root:root /etc/1password/custom_allowed_browsers
sudo chmod 0755 /etc/1password/custom_allowed_browsers

# Fix dark theme
sed -i 's|Exec=/opt/1Password/1password %U|Exec=env GTK_THEME=Adwaita:dark /opt/1Password/1password --enable-features=WebContentsForceDark %U|' \
  ~/.local/share/applications/1password.desktop
```

### Brave — Policy Configuration

Disables unwanted Brave surfaces and locks search to Qwant. Policies override UI/Sync and apply at startup.

```sh
sudo mkdir -p /etc/brave/policies/managed
sudo tee /etc/brave/policies/managed/brave-policy.json >/dev/null <<'EOF'
{
  "TorDisabled": true,
  "BraveTalkDisabled": true,
  "BraveNewsDisabled": true,
  "BraveWalletDisabled": true,
  "BraveRewardsDisabled": true,
  "BraveWebDiscoveryEnabled": false,
  "BraveVPNDisabled": true,

  "PasswordManagerEnabled": false,
  "MetricsReportingEnabled": false,

  "DnsOverHttpsMode": "secure",
  "DnsOverHttpsTemplates": "https://dns.quad9.net/dns-query",

  "DefaultSearchProviderEnabled": true,
  "DefaultSearchProviderName": "Qwant",
  "DefaultSearchProviderSearchURL": "https://www.qwant.com/?q={searchTerms}",
  "DefaultSearchProviderSuggestURL": "https://api.qwant.com/api/suggest/?q={searchTerms}",
  "DefaultSearchProviderKeyword": "qwant",
  "DefaultSearchProviderEncodings": ["UTF-8"]
}
EOF
```

#### Policy file locations by OS

| OS | Scope | Path |
|---|---|---|
| Linux (traditional) | System | `/etc/brave/policies/managed/brave-policy.json` |
| Linux (traditional) | User | `~/.config/brave/policies/managed/brave-policy.json` |
| Atomic Fedora (Bazzite) | System | `/etc/brave/policies/managed/brave-policy.json` (`/etc` persists across rebases) |
| Atomic Fedora (Bazzite) | User | `~/.config/brave/policies/managed/brave-policy.json` |
| macOS | System | `/Library/Managed Preferences/com.brave.Browser.plist` |
| macOS | User | `~/Library/Managed Preferences/com.brave.Browser.plist` |
| Windows | System | `HKLM\Software\Policies\BraveSoftware\Brave` |
| Windows | User | `HKCU\Software\Policies\BraveSoftware\Brave` |

---

## Web Apps

Install the following as web apps using Vivaldi as the wrapper:

- [Apple Music](https://music.apple.com/dk/home)
- [Nextcloud](https://home.cloud)
- [AFFiNE](https://notes.home.cloud)
- [Craft](https://docs.craft.do)
- [Microsoft Teams](https://teams.microsoft.com)
- [ChatGPT](https://chatgpt.com)

---

## GNOME Extensions

- Dash to Panel
- Dash to Dock
- AppIndicator and KStatusNotifierItem Support
- Blur my Shell
- Compiz alike magic lamp effect
- Compiz windows effect
- Desktop Cube
- Add to Steam
- Burn my Windows
- Caffeine (prevents lock during fullscreen games)
- GSConnect
- Hot Edge
- Restart To
- Desktop Clock
- Tiling Shell
- Search Light
- Advanced Alt-Tab Window Switcher (AATWS)
- Panel Visual Clipboard
- [Rounded Window Corners Reborn](https://extensions.gnome.org/extension/7048/rounded-window-corners-reborn/)
- [Desktop Icons NG (DING)](https://extensions.gnome.org/extension/2087/desktop-icons-ng-ding/)
- Arc Menu (Windows-like start menu)
- Vitals
- Copyous (clipboard manager)

---

## AI Apps

- [Alpaca](https://flathub.org/en/apps/com.jeffser.Alpaca) — Flatpak local LLM frontend
- [Chatbox](https://github.com/chatboxai/chatbox)
- Newelle — see below

### Newelle on Bazzite (Immutable Host)

Newelle is a native GTK4 AI tool. On an immutable system, the Flatpak sandbox needs access to `flatpak-spawn` to run host commands.

**1. Grant permissions**
```sh
flatpak override io.github.qwersyk.Newelle \
  --talk-name=org.freedesktop.Flatpak \
  --filesystem=home
```

**2. Disable Command Virtualization**

In Newelle: **Settings > General > Neural Network Control** — toggle **Command Virtualization** to **OFF**. This lets the LLM send commands to the host shell via `flatpak-spawn --host`.

**3. Use Toolbox for package installs**

Since the host is read-only, direct Newelle to run commands inside a Toolbox container. Tell it: *"Always run terminal commands inside my default toolbox container."* The underlying command it will use is:
```sh
flatpak-spawn --host toolbox run <command>
```

**4. Recommended system prompt**

> "You are an AI assistant running on Fedora Silverblue. The host system is immutable. To perform tasks, use `flatpak-spawn --host`. For development or package installation, wrap commands in `toolbox run`. Access my files directly via the home directory."
