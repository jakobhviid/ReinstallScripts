# Getting Started with Bazzite

## 1. System Packages (rpm-ostree)

### Repo Setup

```sh
# Brave repo
sudo curl -fsSLo /etc/yum.repos.d/brave-browser.repo \
  https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

# Vivaldi repo
sudo curl -fsSLo /etc/yum.repos.d/vivaldi-fedora.repo \
  https://repo.vivaldi.com/archive/vivaldi-fedora.repo

# 1Password repo (created explicitly)
sudo tee /etc/yum.repos.d/1password.repo >/dev/null <<'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF

# VS Code repo (Microsoft) — repo file only; no rpm --import on an rpm-ostree host
sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Proton VPN repo (Atomic-friendly: key is stored as a file and referenced via file://)
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
# Layer packages by name (single transaction)
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

> On Silverblue, also install these GNOME extensions (they come standard on Bazzite):
> ```sh
> sudo rpm-ostree install \
>   gnome-shell-extension-appindicator \
>   gnome-shell-extension-blur-my-shell \
>   gnome-shell-extension-caffeine \
>   gnome-shell-extension-gsconnect
> ```

> On traditional Fedora (not Bazzite/Silverblue), also install:
> ```sh
> gnome-sushi sushi nautilus-python file-roller-nautilus gnome-terminal-nautilus seahorse-nautilus
> ```

> **Reboot required before continuing.**

---

## 2. Flatpaks

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

---

## 3. App Configuration

### Brave — Policy Configuration

Disables unwanted Brave surfaces and locks search to Qwant. Policies override UI/Sync and apply at startup.

```sh
# Brave Config
sudo mkdir -p /etc/brave/policies/managed && sudo tee /etc/brave/policies/managed/brave-policy.json >/dev/null <<'EOF'
{
  "TorDisabled": true,
  "BraveTalkDisabled": true,
  "BraveNewsDisabled": true,
  "BraveWalletDisabled": true,
  "BraveRewardsDisabled": true,
  "BraveWebDiscoveryEnabled": false,
  "BraveVPNDisabled": true,

  "PasswordManagerEnabled": false,
  "AutofillAddressEnabled": false,
  "AutofillCreditCardEnabled": false,

  "MetricsReportingEnabled": false,
  "BraveStatsPingEnabled": false,
  "UrlKeyedAnonymizedDataCollectionEnabled": false,
  "UserFeedbackAllowed": false,

  "SafeBrowsingExtendedReportingEnabled": false,

  "ShoppingListEnabled": false,

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

### 1Password — Global Shortcut

```sh
# Enable 1password shortcut
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password/']" &&
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password/ name "1Password Quick Search" &&
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password/ command "1password --quick-access" &&
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password/ binding "<Alt><Shift>2"
```

### 1Password — Vivaldi Compatibility

```sh
# 1Password ↔ Vivaldi compatibility (required on Linux)
sudo install -d -m 0755 /etc/1password
printf '%s\n' vivaldi-bin | sudo tee /etc/1password/custom_allowed_browsers >/dev/null
sudo chown root:root /etc/1password/custom_allowed_browsers
sudo chmod 0755 /etc/1password/custom_allowed_browsers
# fixing the theme
sed -i 's|Exec=/opt/1Password/1password %U|Exec=env GTK_THEME=Adwaita:dark /opt/1Password/1password --enable-features=WebContentsForceDark %U|' ~/.local/share/applications/1password.desktop
```

---

## 4. CLI & Developer Tools

### NVM + Node LTS

```sh
# install NVM (Node Version Manager) — always fetches the latest release
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name"' | cut -d'"' -f4)/install.sh" | bash
# reload shell
source ~/.nvm/nvm.sh
# install Node LTS
nvm install --lts
```

### Kiro CLI ([kiro.dev/cli](https://kiro.dev/cli/))

```sh
curl -fsSL https://cli.kiro.dev/install | bash
```

### Claude Code

```sh
curl -fsSL https://claude.ai/install.sh | bash
```

### Codex CLI

```sh
# Codex
mkdir -p ~/.local/npm
npm config set prefix ~/.local/npm
echo 'export PATH="$HOME/.local/npm/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
npm install -g @openai/codex
```

---

## 5. GNOME Extensions

### Bundled and enabled by default in Bazzite — no action needed

- Add to Steam
- Hot Edge (disable if using Dash to Dock or Dash to Panel)
- Restart To
- Compiz alike magic lamp effect
- Blur my Shell
- AppIndicator and KStatusNotifierItem Support
- Caffeine
- GSConnect

### Bundled in Bazzite but disabled by default — enable via Extension Manager

- Compiz windows effect
- Desktop Cube
- Burn my Windows

### Not in Bazzite — install via [Extension Manager](https://flathub.org/apps/com.mattjakeman.ExtensionManager)

- Tiling Shell (important)
- Copyous (clipboard manager) (important)
- Desktop Clock
- Search Light
- Advanced Alt-Tab Window Switcher (AATWS)
- Panel Visual Clipboard
- [Desktop Icons NG (DING)](https://extensions.gnome.org/extension/2087/desktop-icons-ng-ding/)
- Arc Menu (Windows-like start menu)
- Vitals

---

## 6. Web Apps

Install the following as web apps using Vivaldi as the wrapper:

- [Apple Music](https://music.apple.com/dk/home)
- [Nextcloud](https://home.cloud)
- [AFFiNE](https://notes.home.cloud)
- [Craft](https://docs.craft.do)
- [Microsoft Teams](https://teams.microsoft.com)
- [ChatGPT](https://chatgpt.com)

---

## 7. AI Apps

- Newelle — see below (already installed above)

### Newelle on Bazzite (Immutable Host)

Newelle is a native GTK4 AI tool. On an immutable system, the Flatpak sandbox needs access to `flatpak-spawn` to run host commands.

**1. Grant permissions**
```sh
flatpak override io.github.qwersyk.Newelle --talk-name=org.freedesktop.Flatpak --filesystem=home
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
