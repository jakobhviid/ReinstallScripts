# Linux setup

Re-runnable, idempotent provisioning for Bazzite (rpm-ostree). Most of the system layer (browsers, Claude Desktop, dash-to-panel/dock, CLI baseline, brave policy, wireplumber renames, three unlock services, 33 preinstalled flatpaks) is now baked into the [bazzite-custom](https://github.com/jakobhviid/bazzite-custom) image. `install-bazzite.sh`'s job is to (a) get a stock-Bazzite machine onto that image, (b) layer `proton-vpn-gnome-desktop` (which can't be baked due to a systemd-scriptlet failure in build containers), and (c) handle per-user state. The userspace layer (formulae, casks, taps, brew-bundle Flatpaks) lives in `brewfiles/Brewfile.<machine>` and is applied by `brew bundle` — same idiom as the Mac side. **1Password is in brew**, not in the image, via `cask "ublue-os/tap/1password-gui-linux"`.

## 1Password gotchas (read before debugging)

These are the load-bearing lessons from a long debugging session. The symptoms (`PipeAuthError(NoCreds)` and `invalid group attempted to connect` in `~/.config/1Password/logs/1Password_rCURRENT.log`) repeatedly led to the wrong fixes. Don't redo the chase:

- **Never add the user to the `onepassword` group.** 1P's IPC peer auth in the main app accepts an incoming connection only when the peer's `egid == onepassword`, which is supposed to be reachable ONLY via setgid exec of `1Password-BrowserSupport`. If the live user is a member of the group, that egid is trivially obtainable from any user process — the auth check becomes meaningless and 1P rejects every browser-extension connection. The cask deliberately doesn't `usermod`. Common stale tutorials (and our prior debug session) say to add the user; **that is the bug**, not the fix. `run_config_1password` aborts with a warning if it detects this state, and `just drift` flags it.
- **`/etc/1password/custom_allowed_browsers` must be `0755 root:root`** (or `0644 root:root`). 1P verifies "writable by root and only by root" — `0444` (no write for anyone) FAILS the check because root needs the write bit. The cask installs the file at `0644`; we keep it at `0755` after appending entries.
- **Vivaldi (`vivaldi-bin`) and Zen (`zen-bin`) need explicit allowlist entries** in `custom_allowed_browsers`. 1P's hardcoded trusted basenames are only `chrome chromium-browser-privacy msedge brave firefox firefox-bin firefox-esr`. The cask only writes `flatpak-session-helper`. `run_config_1password` appends both. The cask file ships without a trailing newline — handle when appending.
- **Zen needs its own NMH manifest** copied from `~/.mozilla/native-messaging-hosts/` to `~/.zen/native-messaging-hosts/` (Firefox-style with `allowed_extensions`, not `allowed_origins`). The cask doesn't know about Zen at all.
- **Don't try to layer 1Password as an RPM on top of the bazzite-custom image** — the image's `/opt` is on read-only composefs (it replaces Bazzite's `/opt → /var/opt` symlink so dnf could install /opt-using packages at image-build time), so layered RPMs that install to /opt silently lose those files. `rpm-ostree install 1password` will commit a deployment with a dead `/usr/bin/1password → /opt/1Password/1password` symlink and no payload. The brew cask installs to `/home/linuxbrew/...` (writable), which is why it works.
- **Don't bother with brew's `op` CLI cask either** — `ublue-os/homebrew-tap#208` is open: brew's `op` doesn't pair with brew's GUI. If you need `op`, layer the official `1password-cli` RPM (it's a single `/usr/bin/op` file, no /opt files, so the layering bug doesn't apply).

## Prerequisites

A fresh Bazzite GNOME install (KDE-based variants like the default `bazzite` or `bazzite-deck` won't work — the image targets the GNOME variant). Bazzite ships with `jq` (needed for the policy.json edit during Phase 1) and `rpm-ostree` so no prerequisites beyond the base OS.

`install-bazzite.sh` also bootstraps `brew` + `just` internally during Phase 2, so you can go straight to it. If you want `just` available in your shell beforehand to use other recipes (`just drift` etc.), run `./bootstrap.sh` first.

## Two phases

`install-bazzite.sh` is **phase-aware** — it auto-detects via `rpm-ostree status` whether the machine is on the bazzite-custom image, and runs the appropriate phase:

**Phase 1 — fresh stock Bazzite install** (machine NOT yet on bazzite-custom):
1. Install vendored cosign pub key (`assets/bazzite-custom.pub`) to `/etc/pki/containers/`
2. Drop a sigstore lookup entry at `/etc/containers/registries.d/ghcr-jakobhviid.yaml`
3. JSON-merge a `sigstoreSigned` trust rule into `/etc/containers/policy.json` (with backup at `policy.json.bak.bazzite-custom`)
4. Add the Proton VPN repo (still in `lib/repos.sh`)
5. `rpm-ostree rebase --install proton-vpn-gnome-desktop ostree-image-signed:registry:ghcr.io/jakobhviid/<image>:latest`
6. Reboot prompt

**Phase 2 — already on bazzite-custom** (run after the Phase 1 reboot):
1. Bootstrap brew + just if missing
2. `brew bundle install --file=brewfiles/Brewfile.<machine>`
3. Install GNOME extensions via `gext` (the 6 user-only ones — none are packaged as RPMs anywhere)
4. `just zsh` (templates `~/.zshrc.image` from `assets/zshrc.template`, bootstraps `~/.zshrc` from `assets/zshrc-bootstrap` if missing, configures tmux/tpm, sets default shell)
5. Per-user `run_config_*` — 1Password GNOME Alt+Shift+2 keybinding + dark titlebar, app icon overrides, PWA deployment, autostart entries with background-launch flags, LocalSend Flatpak GTK_THEME override, GNOME shell + Ptyxis dconf snapshots

Image variant is selected interactively during Phase 1 by `pick_image_variant`:

1. `lspci` is grep'd for NVIDIA — if found, `bazzite-nvidia-custom` is preselected; otherwise `bazzite-custom`.
2. `pick_choice` shows both options with the detected default; press Enter to accept or type the other.

This sidesteps any per-machine hardcoding. If you want to deliberately install the non-NVIDIA image on NVIDIA hardware (e.g. a server you don't want the driver loaded on), just pick `bazzite-custom` at the prompt.

## Layout

```
Linux/
├── install-bazzite.sh                    ← phase-aware orchestrator (Phase 1 trust+rebase, Phase 2 userspace)
├── bootstrap.sh                          ← brew + just bootstrap (also called by install-bazzite.sh's Phase 2)
├── brewfiles/Brewfile.<machine>          ← userspace packages per machine (brew + cask + tap + flatpak)
├── assets/
│   ├── bazzite-custom.pub                ← vendored cosign pub key (sync target whenever bazzite-custom rotates its key)
│   ├── bazzite-flatpak-ignore.txt        ← flatpak app IDs that drift/reconcile/prune treat as baseline
│   ├── brave-policy.json                 ← canonical editable Brave policy (also lives in bazzite-custom image as a copy)
│   ├── color-calibration/                ← X1 Carbon Gen 13 .icm color profiles + panel info
│   ├── gnome/shell.dconf                 ← per-user GNOME shell dconf snapshot
│   ├── ptyxis.dconf                      ← per-user Ptyxis (terminal) dconf snapshot
│   ├── pwa/                              ← Brave PWA .desktop files + icons
│   ├── rename-devices.conf               ← canonical wireplumber renames (also in image; lives here as editable source)
│   ├── speaker-eq.conf                   ← X1 Carbon-only PipeWire EQ
│   └── zshrc.template                    ← shared zsh template (sources image-installed plugins from /usr/share/, brew-only ones from BREW_PREFIX)
├── lib/                                  ← shared bash helpers, sourced by install-bazzite.sh
│   ├── common.sh                         ← loggers, confirm prompt, interactive picker
│   ├── install.sh                        ← detection helpers, CLI bootstrap
│   ├── repos.sh                          ← `ensure_repo` for proton-vpn (other repos baked in image)
│   └── config.sh                         ← per-user run_config_* (1password keybinding/desktop, app icons, PWAs, autostart, localsend, GNOME shell, Ptyxis)
├── justfile                              ← install/backup/drift + zsh + dconf snapshot/restore recipes
└── README.md
```

## Recipes

Run from the `Linux/` directory.

| Command                          | What it does                                                                                |
|----------------------------------|---------------------------------------------------------------------------------------------|
| `just`                           | List recipes + available machines                                                            |
| `just install <machine>`         | Run `install-bazzite.sh <machine>` — phase-aware (rebase + reboot, then re-run for userspace) |
| `just install`                   | Interactive — pick a machine from a numbered menu                                            |
| `just backup <machine>`          | `brew bundle dump` current state into `brewfiles/Brewfile.<machine>`                        |
| `just drift <machine>`           | Show what's out of sync. Top check: image rebase status. Then zsh templates, default shell, git identity, brave policy, ghostty config, rpm-ostree layered packages, brewfile diff. Read-only — points at the recipes that converge. |
| `just reconcile <machine>`       | Interactively reconcile a machine's Brewfile with what's installed. Per-item y/N (or y/N/i for flatpak extras, where `i` appends to `assets/bazzite-flatpak-ignore.txt`). Shows a diff and asks for final confirm before writing. |
| `just prune <machine>`           | Uninstall packages and flatpaks installed on this machine but not listed in the machine's Brewfile. Lists what would be uninstalled, asks first, then runs `brew bundle cleanup --force` and `flatpak uninstall -y`. Flatpak extras filtered through `assets/bazzite-flatpak-ignore.txt`. |
| `just install-missing <machine>`         | Install Brewfile entries that are missing on this machine (formulas/casks/taps and flatpaks). Thin wrapper over `brew bundle install`. Additive only. |
| `just zsh`                       | Re-template `~/.zshrc.image` (managed), bootstrap `~/.zshrc` once if missing, configure git/tmux/starship, install brew-only zsh plugins (image has the rest), set zsh as default |
| `just speaker-eq`                | Install the PipeWire filter-chain EQ for thin laptop speakers (X1 Carbon Gen 13 only)        |
| `just brave`                     | Deploy `assets/brave-policy.json` to `/etc/brave/policies/managed/`. Image bakes the same on rebased machines so this is normally redundant — kept for testing policy edits before syncing them into bazzite-custom. |
| `just ghostty`                   | Deploy `assets/ghostty.config` to `~/.config/ghostty/config` (backs up any pre-existing differing config to `.bak`). Also runs as `run_config_ghostty` during install-bazzite.sh Phase 2. |
| `just gnome-backup`              | Snapshot `/org/gnome/shell/` settings into `assets/gnome/shell.dconf`                        |
| `just gnome-restore`             | Apply `assets/gnome/shell.dconf` to live `/org/gnome/shell/` (asks first, default no)        |
| `just ptyxis-backup`             | Snapshot `/org/gnome/Ptyxis/` settings into `assets/ptyxis.dconf`                            |
| `just ptyxis-restore`            | Apply `assets/ptyxis.dconf` to live `/org/gnome/Ptyxis/` (asks first, default no)            |

**Editing the Brave policy:** edit `assets/brave-policy.json`, then `just brave` to deploy it on the local machine (image users will see the local copy override the image's baked-in copy). Once happy with the changes, sync the file into `../bazzite-custom/system_files/etc/brave/policies/managed/brave-policy.json` and push the bazzite-custom image so the change propagates fleet-wide.

**Editing the Ghostty config:** edit `assets/ghostty.config`, then `just ghostty` to redeploy. Keep cross-platform settings (colors, palette, padding, cursor, behavior, font-feature, link, quick-terminal) in sync with `../Mac/assets/ghostty.config` — Mac-only (`macos-*`, `cmd+*`) and Linux-only (`font-family`, portal comments) keys edit only the respective file. Ghostty itself is installed by the bazzite-custom image, not by this repo.

**Ctrl+Alt+T new-window keybinding:** bound via GNOME custom-keybinding by `run_config_ghostty_keybinding` (called from `install-bazzite.sh` Phase 2). Ghostty's own portal `keybind = global:` only survives while a Ghostty window is open — once the last window closes, the portal grab is released and the shortcut dies. A GNOME-level binding keeps working: it runs `ghostty`, which either D-Bus-activates the live single-instance process (new window in existing) or launches a fresh one. `just drift` flags this binding the same way it flags 1Password's Alt+Shift+2.

## Workflow

**First-time setup on a fresh Bazzite GNOME box:**

```sh
./install-bazzite.sh chronos-redux       # or: just install chronos-redux
# Phase 1 detected → trust setup → rebase signed + layer proton-vpn → reboot prompt
sudo systemctl reboot

# After reboot (now on bazzite-custom):
./install-bazzite.sh chronos-redux       # Phase 2 detected → userspace setup
```

For a brand-new machine without a Brewfile yet, pass the name as an argument so the picker doesn't reject it (Phase 1 doesn't need a Brewfile; Phase 2 does, so create one before running Phase 2).

**Capture current userspace state:**

```sh
just backup chronos-redux                 # overwrites brewfiles/Brewfile.chronos-redux
```

`brew bundle dump` pulls in default GNOME flatpaks that ship with Bazzite (Calculator, Calendar, Loupe, Papers, Showtime, etc.) AND the 33 image-preinstalled flatpaks — hand-edit before commit if you want to keep the brewfile lean. The image-preinstalled flatpaks are listed by convention as a "this machine wants this" record (`flatpak install` is idempotent so the duplication is harmless).

**Add a new Linux machine:**

```sh
# 1. ./install-bazzite.sh mynewbox      # Phase 1 — pick_image_variant prompts
#                                       #   (NVIDIA detected → bazzite-nvidia-custom default)
# 2. Reboot
# 3. just backup mynewbox                # creates brewfiles/Brewfile.mynewbox from current state
# 4. Hand-edit Brewfile.mynewbox to drop the dumped flatpaks if you want it lean
# 5. ./install-bazzite.sh mynewbox      # Phase 2 — userspace setup
```

No code edit needed for a new machine — the image variant is chosen at the prompt during step 1.

## Brave policy

`assets/brave-policy.json` is the canonical editable source for the Brave policy across all platforms. Cross-platform sync targets:
- `Mac/assets/brave-debloat.mobileconfig` (plist format)
- `Windows/brave-policy.json` (json copy)
- `bazzite-custom/system_files/etc/brave/policies/managed/brave-policy.json` (image's copy — what actually loads on rebased machines)

When changing the policy, edit this file then propagate to all three sync targets.

## Per-machine variation

Brewfiles diverge per machine — each machine serves a different purpose. The system-layer arrays in `install-bazzite.sh` (`RPM_PACKAGES`, `GNOME_EXTENSIONS`) currently apply uniformly. After the image rework, `RPM_PACKAGES` is just `proton-vpn-gnome-desktop`; `GNOME_EXTENSIONS` is six per-user `gext`-installed extensions. If the divergence ever matters, split per-machine.

The image variant is per-machine but selected at install time via `pick_image_variant` (NVIDIA detection + prompt) — no static mapping needed.

## Manual extras

Things the install flow doesn't do for you — run by hand on a fresh machine when you actually need them.

### Kiro CLI

Anthropic-style coding agent CLI from AWS. One-shot installer, not in the Brewfile.

```sh
curl -fsSL https://cli.kiro.dev/install | bash
```

### Newelle (immutable-host config)

Newelle is a GTK4 LLM client. On Bazzite the Flatpak sandbox can't reach the host shell out of the box — the image preinstalls the flatpak via the Fedora-native `flatpak preinstall` mechanism, but you still need to grant `flatpak-spawn` permission and disable Newelle's "Command Virtualization" toggle if you want it to run host commands.

```sh
flatpak override --user io.github.qwersyk.Newelle \
  --talk-name=org.freedesktop.Flatpak --filesystem=home
```

In Newelle: **Settings → General → Neural Network Control → Command Virtualization OFF**, then point the system prompt at Toolbox for any package work:

> "You are an AI assistant on Fedora Silverblue. The host is immutable. Use `flatpak-spawn --host` for host commands and `toolbox run` for package installs. Access files via the home directory."

### GNOME extensions bundled with Bazzite

Bazzite ships these enabled — don't add them to `GNOME_EXTENSIONS`:

- Add to Steam, Hot Edge (disable if using Dash to Panel/Dock), Restart To, Compiz alike magic lamp, Blur my Shell, AppIndicator + KStatusNotifierItem, Caffeine, GSConnect

Bundled but disabled by default — turn on via Extension Manager if wanted:

- Compiz windows effect, Desktop Cube, Burn my Windows
