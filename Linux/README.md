# Linux setup

Re-runnable, idempotent provisioning for Bazzite (rpm-ostree). Most of the system layer (browsers, 1Password, Claude Desktop, dash-to-panel/dock, CLI baseline, brave policy, 1pw allowed-browsers, wireplumber renames, three unlock services, 33 preinstalled flatpaks) is now baked into the [bazzite-custom](https://github.com/jakobhviid/bazzite-custom) image. `install-bazzite.sh`'s job is to (a) get a stock-Bazzite machine onto that image, (b) layer `proton-vpn-gnome-desktop` (which can't be baked due to a systemd-scriptlet failure in build containers), and (c) handle per-user state. The userspace layer (formulae, casks, taps, brew-bundle Flatpaks) lives in `brewfiles/Brewfile.<machine>` and is applied by `brew bundle` — same idiom as the Mac side.

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
4. `just zsh` (templates `~/.zshrc`, configures tmux/tpm, sets default shell)
5. Per-user `run_config_*` — 1Password GNOME Alt+Shift+2 keybinding + dark titlebar, app icon overrides, PWA deployment, autostart entries with background-launch flags, LocalSend Flatpak GTK_THEME override, GNOME shell + Ptyxis dconf snapshots

The per-machine → image variant mapping is the `machine_to_image` case statement at the top of `install-bazzite.sh`. Add new machines there:

| Machine name | Image variant |
|---|---|
| `chronos-redux`, `atlas` | `bazzite-nvidia-custom` |
| (default) | `bazzite-custom` |

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
| `just drift <machine>`           | Show what's out of sync. Top check: image rebase status. Then zsh templates, default shell, git identity, brave policy, rpm-ostree layered packages, brewfile diff. Read-only — points at the recipes that converge. |
| `just reconcile <machine>`       | Interactively reconcile a machine's Brewfile with what's installed. Per-item y/N (or y/N/i for flatpak extras, where `i` appends to `assets/bazzite-flatpak-ignore.txt`). Shows a diff and asks for final confirm before writing. |
| `just prune <machine>`           | Uninstall packages and flatpaks installed on this machine but not listed in the machine's Brewfile. Lists what would be uninstalled, asks first, then runs `brew bundle cleanup --force` and `flatpak uninstall -y`. Flatpak extras filtered through `assets/bazzite-flatpak-ignore.txt`. |
| `just install-missing <machine>`         | Install Brewfile entries that are missing on this machine (formulas/casks/taps and flatpaks). Thin wrapper over `brew bundle install`. Additive only. |
| `just zsh`                       | Re-template `~/.zshrc`, configure git/tmux/starship, install brew-only zsh plugins (image has the rest), set zsh as default |
| `just speaker-eq`                | Install the PipeWire filter-chain EQ for thin laptop speakers (X1 Carbon Gen 13 only)        |
| `just gnome-backup`              | Snapshot `/org/gnome/shell/` settings into `assets/gnome/shell.dconf`                        |
| `just gnome-restore`             | Apply `assets/gnome/shell.dconf` to live `/org/gnome/shell/` (asks first, default no)        |
| `just ptyxis-backup`             | Snapshot `/org/gnome/Ptyxis/` settings into `assets/ptyxis.dconf`                            |
| `just ptyxis-restore`            | Apply `assets/ptyxis.dconf` to live `/org/gnome/Ptyxis/` (asks first, default no)            |

(`just brave` was removed — the image bakes `/etc/brave/policies/managed/brave-policy.json`. The canonical editable source still lives at `assets/brave-policy.json`; sync to bazzite-custom when changing the policy.)

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
# 1. Add the machine name → image variant mapping in install-bazzite.sh
#    (machine_to_image function — bazzite-custom for non-NVIDIA, bazzite-nvidia-custom for NVIDIA)
# 2. ./install-bazzite.sh mynewbox      # Phase 1 — rebase, reboot
# 3. Reboot
# 4. just backup mynewbox                # creates brewfiles/Brewfile.mynewbox from current state
# 5. Hand-edit Brewfile.mynewbox to drop the dumped flatpaks if you want it lean
# 6. ./install-bazzite.sh mynewbox      # Phase 2 — userspace setup
```

## Brave policy

`assets/brave-policy.json` is the canonical editable source for the Brave policy across all platforms. Cross-platform sync targets:
- `Mac/assets/brave-debloat.mobileconfig` (plist format)
- `Windows/brave-policy.json` (json copy)
- `bazzite-custom/system_files/etc/brave/policies/managed/brave-policy.json` (image's copy — what actually loads on rebased machines)

When changing the policy, edit this file then propagate to all three sync targets.

## Per-machine variation

Brewfiles diverge per machine — each machine serves a different purpose. The system-layer arrays in `install-bazzite.sh` (`RPM_PACKAGES`, `GNOME_EXTENSIONS`) currently apply uniformly. After the image rework, `RPM_PACKAGES` is just `proton-vpn-gnome-desktop`; `GNOME_EXTENSIONS` is six per-user `gext`-installed extensions. If the divergence ever matters, split per-machine.

The image variant differs per machine via the `machine_to_image` mapping — that's where NVIDIA vs Intel splits.

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
