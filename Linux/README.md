# Linux setup

Re-runnable, idempotent provisioning for Bazzite (rpm-ostree). Most of the system layer (browsers, Claude Desktop, dash-to-panel/dock, CLI baseline, brave policy, wireplumber renames, three unlock services, 33 preinstalled flatpaks) is now baked into the [bazzite-custom](https://github.com/jakobhviid/bazzite-custom) image. `install-bazzite.sh`'s job is to (a) get a stock-Bazzite machine onto that image, (b) layer `proton-vpn-gnome-desktop` (which can't be baked due to a systemd-scriptlet failure in build containers), and (c) handle per-user state. The userspace layer (formulae, casks, taps, brew-bundle Flatpaks) lives in `brewfiles/Brewfile.<machine>` and is applied by `brew bundle` — same idiom as the Mac side. **1Password is in brew**, not in the image, via `cask "ublue-os/tap/1password-gui-linux"`.

## 1Password gotchas (read before debugging)

These are the load-bearing lessons from a long debugging session. The symptoms (`PipeAuthError(NoCreds)` and `invalid group attempted to connect` in `~/.config/1Password/logs/1Password_rCURRENT.log`) repeatedly led to the wrong fixes. Don't redo the chase:

- **Never add the user to the `onepassword` group.** 1P's IPC peer auth in the main app accepts an incoming connection only when the peer's `egid == onepassword`, which is supposed to be reachable ONLY via setgid exec of `1Password-BrowserSupport`. If the live user is a member of the group, that egid is trivially obtainable from any user process — the auth check becomes meaningless and 1P rejects every browser-extension connection. The cask deliberately doesn't `usermod`. Common stale tutorials (and our prior debug session) say to add the user; **that is the bug**, not the fix. `run_config_1password` aborts with a warning if it detects this state, and `just drift` flags it.
- **`/etc/1password/custom_allowed_browsers` must be `0755 root:root`** (or `0644 root:root`). 1P verifies "writable by root and only by root" — `0444` (no write for anyone) FAILS the check because root needs the write bit. The cask installs the file at `0644`; we keep it at `0755` after appending entries.
- **Vivaldi (`vivaldi-bin`), Zen (`zen-bin`), and Brave Origin (`brave-origin` + `brave-origin-stable`) need explicit allowlist entries** in `custom_allowed_browsers`. 1P's hardcoded trusted basenames are only `chrome chromium-browser-privacy msedge brave firefox firefox-bin firefox-esr` — "brave" covers `brave-browser{,-stable}` but NOT `brave-origin`'s binaries. The cask only writes `flatpak-session-helper`. `run_config_1password` appends all four. The cask file ships without a trailing newline — handle when appending.
- **Zen needs its own NMH manifest** copied from `~/.mozilla/native-messaging-hosts/` to `~/.zen/native-messaging-hosts/` (Firefox-style with `allowed_extensions`, not `allowed_origins`). The cask doesn't know about Zen at all.
- **Brave Origin needs its own NMH manifest** copied from `~/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts/` to `~/.config/BraveSoftware/Brave-Origin/NativeMessagingHosts/` (Chromium-style with `allowed_origins` — same extension IDs as Brave-Browser, so the JSON is portable apart from the `path` field). 1P's `op-nm-installer` only writes into Brave-Browser's peer dir; Brave Origin's stays empty and the extension's native-messaging launch fails before 1P's IPC ever sees it. The `path` in the copied manifest must be rewritten to point at the Brave-Origin copy of `1PasswordWrapper.sh`; the wrapper itself is portable (execs the brew-installed BrowserSupport binary). **Allowlist entries alone are not enough** — without the manifest, the browser side can't attempt the connection.
- **Don't try to layer 1Password as an RPM on top of the bazzite-custom image** — the image's `/opt` is on read-only composefs (it replaces Bazzite's `/opt → /var/opt` symlink so dnf could install /opt-using packages at image-build time), so layered RPMs that install to /opt silently lose those files. `rpm-ostree install 1password` will commit a deployment with a dead `/usr/bin/1password → /opt/1Password/1password` symlink and no payload. The brew cask installs to `/home/linuxbrew/...` (writable), which is why it works.
- **Don't bother with brew's `op` CLI cask either** — `ublue-os/homebrew-tap#208` is open: brew's `op` doesn't pair with brew's GUI. If you need `op`, layer the official `1password-cli` RPM (it's a single `/usr/bin/op` file, no /opt files, so the layering bug doesn't apply).

## Prerequisites

A fresh Bazzite GNOME install (KDE-based variants like the default `bazzite` or `bazzite-deck` won't work — the image targets the GNOME variant). Bazzite ships with `jq` (needed for the policy.json edit during Phase 1) and `rpm-ostree` so no prerequisites beyond the base OS.

`install-bazzite.sh` also bootstraps `brew` + `just` internally during Phase 2, so you can go straight to it. If you want `just` available in your shell beforehand to use other recipes (`just drift` etc.), run `./bootstrap.sh` first.

## Machine roles (desktop vs server)

The Linux fleet isn't all Bazzite desktops. **eternium and nous are headless servers** (Fedora CoreOS today — no gnome-shell/flatpak/brew/gext; they run `quay.io/fedora/fedora-coreos:stable`, not a jakobhviid image). `install-bazzite.sh` is **role-aware**: `is_desktop()` (`lib/common.sh`, = `command -v gnome-shell`) auto-detects the role — no per-machine flag, and it's distro-agnostic (an Ubuntu/Debian server takes the same headless path; the userspace tier has no Fedora/rpm-ostree assumptions).

- **Desktop** → the two phases below (image rebase + full userspace).
- **Server** (any distro) → Phase 1 is skipped entirely (the server self-manages its OS — FCOS via zincati/rpm-ostree, or an apt distro; the installer never rebases or cosign-trusts it), and only the distro-agnostic userspace tier runs: brew + `just zsh` + Brewfile + opencode config. All GUI `run_config_*`, GNOME extensions, and the proton-vpn RPM are skipped. Each server needs its own `brewfiles/Brewfile.<machine>` (eternium + nous exist).

The failure mode is safe by construction: a server can't look like a desktop (no gnome-shell), so a server is never mistakenly rebased onto a bazzite image. `just update` / `just drift` skip the flatpak/gext/desktop pieces on a server too, and the purely-desktop recipes (`speaker-eq`, `gnome-*`, `ptyxis-*`, `extensions-sync`) early-exit with a "desktop-only" message. Entry point on a fresh server is `./install-bazzite.sh <machine>` (just isn't there yet — the script bootstraps it).

## Two phases (desktop)

`install-bazzite.sh` is **phase-aware** — for a desktop it auto-detects via `rpm-ostree status` whether the machine is on the bazzite-custom image, and runs the appropriate phase:

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
│   ├── brave-origin-policy.json          ← Brave Origin policy fetched by bazzite-custom at image-build time
│   ├── color-calibration/                ← X1 Carbon Gen 13 .icm color profiles + panel info
│   ├── gnome/shell.dconf                 ← per-user GNOME shell dconf snapshot
│   ├── ptyxis.dconf                      ← per-user Ptyxis (terminal) dconf snapshot
│   ├── pwa/                              ← Brave PWA .desktop files + icons
│   ├── rename-devices.conf               ← canonical wireplumber renames (also in image; lives here as editable source)
│   ├── speaker-eq/                       ← PipeWire EQ profiles (vendored from the pipewire-speaker-calibration repo via `just eq-import`); installed by `just speaker-eq`
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
| `just update`                    | Update what's already installed (`brew upgrade`, `flatpak update`, `gext update` for GNOME Shell extensions, zsh toolchain) and re-apply the machine-agnostic per-user fixes (desktop icon/Exec overrides, 1Password integration, PWAs, autostart flags, ghostty/opencode config, managed SSH config, and `~/.zshrc.image` via `just zsh`) by re-running install-bazzite.sh's `run_config_*` helpers. No machine arg, and **server-safe**: on a headless/CoreOS image (detected via absent `gnome-shell`) the flatpak, GNOME-extension and `.desktop`-override steps are skipped, so brew/zsh/opencode still update on a box like eternium. Installs nothing new (use `just install` / `just install-missing`), doesn't reload GNOME/Ptyxis dconf snapshots (those overwrite live tweaks — use `just gnome-restore` / `just ptyxis-restore`), and touches no OS image, layered rpms, or firmware (use `ujust update`, which is topgrade — it re-does brew/flatpak too). `gext update` fills a real gap: topgrade's config excludes the gnome-extensions step, so nothing else updates them. |
| `just backup <machine>`          | `brew bundle dump` current state into `brewfiles/Brewfile.<machine>`                        |
| `just drift <machine>`           | Show what's out of sync. Top check: image rebase status. Then zsh templates, default shell, git identity, brave policy, ghostty config, rpm-ostree layered packages, brewfile diff. Read-only — points at the recipes that converge. |
| `just reconcile <machine>`       | Interactively reconcile a machine's Brewfile with what's installed. Per-item y/N (or y/N/i for flatpak extras, where `i` appends to `assets/bazzite-flatpak-ignore.txt`). Shows a diff and asks for final confirm before writing. |
| `just prune <machine>`           | Uninstall packages and flatpaks installed on this machine but not listed in the machine's Brewfile. Lists what would be uninstalled, asks first, then runs `brew bundle cleanup --force` and `flatpak uninstall -y`. Flatpak extras filtered through `assets/bazzite-flatpak-ignore.txt`. |
| `just install-missing <machine>`         | Install Brewfile entries that are missing on this machine (formulas/casks/taps and flatpaks). Thin wrapper over `brew bundle install`. Additive only. |
| `just zsh`                       | Re-template `~/.zshrc.image` (managed), bootstrap `~/.zshrc` once if missing, configure git/tmux/starship, install brew-only zsh plugins (image has the rest), set zsh as default |
| `just eq-import`                 | Pull finalized speaker-EQ profiles from the [pipewire-speaker-calibration](https://github.com/jakobhviid/pipewire-speaker-calibration) repo (the calibration "lab") into `assets/speaker-eq/`. Clones the lab via SSH beside this repo if it's not checked out (else fast-forwards), then copies every `calibrated/*.conf`. The dependency lives here (the consumer); the lab is self-contained. Review + commit, then `just speaker-eq`. |
| `just speaker-eq [profile]`      | Install a PipeWire filter-chain speaker EQ from `assets/speaker-eq/*.conf`. No arg → picks a profile, defaulting to the connected speaker (`all` installs every profile). Each profile resolves its target sink from a `# target-match:` monitor/speaker name, so the `dell-u4025qw` profile follows the monitor across the desktop's HDMI and the laptop's Thunderbolt DisplayPort. Profiles coexist (distinct virtual sinks), so a docked laptop can EQ both its internal speakers and the monitor. |
| `just ghostty`                   | Deploy `assets/ghostty.config` to `~/.config/ghostty/config` (backs up any pre-existing differing config to `.bak`). Also runs as `run_config_ghostty` during install-bazzite.sh Phase 2. |
| `just ssh-config`                | Deploy `shared/ssh-shared.conf` (host inventory + home/away routing) to `~/.ssh/config.d/shared.conf`; bootstrap an `Include` into `~/.ssh/config` once (your `Host *`/agent block is left untouched). On-LAN direct, off-LAN via the `eternium` jump. Also runs as `run_config_ssh` during install-bazzite.sh Phase 2 (universal — servers too). |
| `just gnome-backup`              | Snapshot `/org/gnome/shell/` settings into `assets/gnome/shell.dconf`                        |
| `just gnome-restore`             | Apply `assets/gnome/shell.dconf` to live `/org/gnome/shell/` (asks first, default no)        |
| `just ptyxis-backup`             | Snapshot `/org/gnome/Ptyxis/` settings into `assets/ptyxis.dconf`                            |
| `just ptyxis-restore`            | Apply `assets/ptyxis.dconf` to live `/org/gnome/Ptyxis/` (asks first, default no)            |

**Editing the Brave Origin policy:** edit `assets/brave-origin-policy.json` here AND the byte-identical copy at `Stacks/services/bazzite-build/image/system_files/etc/brave/policies/managed/brave-policy.json` (the image's inline source). Push both. The 10:00 UTC daily `bazzite-build.timer` on Eternium produces a fresh image; `ujust update` (Bazzite's "System Update") on each machine picks it up. `just drift` here flags any deployed key that's missing from or extra in this repo's copy, so divergence between the two source files surfaces quickly.

**Editing the Ghostty config:** edit `assets/ghostty.config`, then `just ghostty` to redeploy. Keep cross-platform settings (colors, palette, padding, cursor, behavior, font-feature, link, quick-terminal) in sync with `../Mac/assets/ghostty.config` — Mac-only (`macos-*`, `cmd+*`) and Linux-only (`font-family`) keys edit only the respective file. Ghostty itself is installed by the bazzite-custom image, not by this repo.

**Ctrl+Alt+T new-window keybinding:** bound via GNOME custom-keybinding by `run_config_ghostty_keybinding` (called from `install-bazzite.sh` Phase 2). Ghostty's own portal `keybind = global:` only survives while a Ghostty window is open — once the last window closes, the portal grab is released and the shortcut dies. A GNOME-level binding keeps working: it runs `ghostty`, which either D-Bus-activates the live single-instance process (new window in existing) or launches a fresh one. `just drift` flags this binding the same way it flags 1Password's Alt+Shift+2.

**Quick-terminal is unsupported on GNOME.** Ghostty's quake-style dropdown depends on the `wlr-layer-shell` Wayland protocol, which Mutter doesn't expose (it's a wlroots-ecosystem protocol — Sway, Hyprland, KDE). Ghostty disables the feature at runtime with `winproto_wayland: your compositor does not support the wlr-layer-shell protocol; disabling quick terminal`. The `quick-terminal-*` settings in the config are kept (harmless no-ops) so the feature lights up the moment Mutter ships layer-shell or a stable extension exists, and so the Mac/Linux configs stay aligned. No global toggle keybind is registered — doing so just spawns the xdg-desktop-portal permission popup for a binding that can never fire.

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

## Brave Origin policy

`assets/brave-origin-policy.json` is the canonical reference for the policy deployed to every Linux machine at `/etc/brave/policies/managed/brave-policy.json`. The image bakes its own byte-identical copy at `Stacks/services/bazzite-build/image/system_files/etc/brave/policies/managed/brave-policy.json` — that's what actually gets installed; this file's job is to be the drift-check baseline (`just drift` compares the live file against this one) and to give stock-Bazzite users (without the image) an editable JSON to deploy by hand. **Both files must stay byte-identical** — to change the policy, edit both, push both, and the next 10:00 UTC `bazzite-build.timer` fire on Eternium rebuilds the image; `ujust update` (Bazzite's "System Update") propagates.

The Origin policy is deliberately leaner than the Mac policy because most of regular Brave's "extras" (Wallet, Rewards, Leo, Tor, News, Talk, VPN, Playlist, Speedreader, Wayback Machine, P3A, Web Discovery, Stats Ping, IPFS) are compiled out of the Brave Origin binary — the matching policy keys would be dead bytes. The Mac policy (`../Mac/assets/brave-debloat.mobileconfig`) is independent — it still targets regular Brave and keeps the full set. Cross-platform settings shared by both (DoH, Qwant search provider, 1Password forcelist, autofill toggles, etc.) need updating in both files when changed.

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
