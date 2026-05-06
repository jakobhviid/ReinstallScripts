# Linux setup

Re-runnable, idempotent provisioning for Bazzite (rpm-ostree). The system layer (rpm-ostree packages, custom RPM repos, GNOME extensions) is driven by `install-bazzite.sh` and `lib/`. The userspace layer (formulae, casks, taps, Flatpaks) is driven by [`brew bundle`](https://github.com/Homebrew/homebrew-bundle) — same idiom as the Mac side, with one `brewfiles/Brewfile.<machine>` per machine.

## Prerequisites

A fresh Bazzite install. Homebrew and `just` are installed by the script if missing.

```sh
# fix bracketed paste if you copy-paste this README into a terminal
bind 'set enable-bracketed-paste off'
source ~/.bashrc
```

## Layout

```
Linux/
├── install-bazzite.sh                   ← orchestrator: rpm-ostree → brew bundle → gext → config
├── brewfiles/Brewfile.<machine>          ← userspace packages per machine (brew + cask + tap + flatpak)
├── assets/                               ← deployable data (templates, dconf snapshots, policies, EQ, PWAs, icons)
│   ├── brave-policy.json
│   ├── gnome/shell.dconf
│   ├── ptyxis.dconf
│   ├── pwa/
│   ├── rename-devices.conf
│   ├── speaker-eq.conf
│   └── zshrc.template
├── lib/                                  ← shared bash helpers, sourced by install-bazzite.sh
│   ├── common.sh                         ← loggers, confirm prompt, interactive picker
│   ├── install.sh                        ← detection helpers, CLI bootstrap
│   ├── repos.sh                          ← per-package custom RPM repo setup
│   └── config.sh                         ← all run_config_* (brave/1password/desktop/etc.)
├── justfile                              ← install/backup/cleanup + zsh + dconf snapshot recipes
└── README.md
```

## Recipes

Run from the `Linux/` directory.

| Command                          | What it does                                                                                |
|----------------------------------|---------------------------------------------------------------------------------------------|
| `just`                           | List recipes + available machines                                                            |
| `just install <machine>`         | Run `install-bazzite.sh <machine>` — full flow                                              |
| `just install`                   | Interactive — pick a machine from a numbered menu                                            |
| `just backup <machine>`          | `brew bundle dump` current state into `brewfiles/Brewfile.<machine>`                        |
| `just cleanup <machine>`         | Show userspace packages installed but not in the machine's Brewfile                          |
| `just zsh`                       | Re-template `~/.zshrc`, configure git/tmux/starship, install zsh plugins, set zsh as default |
| `just speaker-eq`                | Install the PipeWire filter-chain EQ for thin laptop speakers                                |
| `just brave`                     | Deploy `assets/brave-policy.json` to `/etc/brave/policies/managed/`                          |
| `just gnome-backup`              | Snapshot `/org/gnome/shell/` settings into `assets/gnome/shell.dconf`                        |
| `just ptyxis-backup`             | Snapshot `/org/gnome/Ptyxis/` settings into `assets/ptyxis.dconf`                            |

## Install flow

`install-bazzite.sh <machine>` (also reachable as `just install <machine>`) runs:

1. **Preflight** — verify Bazzite, fail closed.
2. **rpm-ostree** — layer system packages (Brave, 1Password, Proton VPN, Claude Desktop, etc.) from the `RPM_PACKAGES` array, after registering each repo via `lib/repos.sh`.
3. **Homebrew bootstrap** — install brew if missing.
4. **`brew bundle --file=brewfiles/Brewfile.<machine>`** — taps, formulae, casks, and Flatpaks.
5. **GNOME extensions** — installed via `gnome-extensions-cli`.
6. **Zsh setup** — `just zsh` (templates `~/.zshrc`, configures tmux/tpm, sets default shell).
7. **Config helpers** — Brave policy, 1Password keybinding/Vivaldi compat/dark theme, custom desktop overrides, PWA deployment, autostart entries (with background-launch flags), audio device renames, LocalSend dark titlebar, unlock services for Brave/Nextcloud, GNOME shell + Ptyxis dconf snapshots.

The script is **add-only and idempotent** — it detects what's already present, prints a plan, asks `Proceed?`, then installs only what's missing. To drop an app, edit the relevant array (or the Brewfile) and uninstall the app manually on the machine.

## Workflow

**First-time setup on a new Bazzite box**

```sh
./install-bazzite.sh chronos-redux       # or: just install chronos-redux
```

A reboot is required after the rpm-ostree pass; re-run after reboot so the config helpers can touch the freshly-layered apps.

**Capture current state**

```sh
just backup chronos-redux                 # overwrites brewfiles/Brewfile.chronos-redux
```

`brew bundle dump` pulls in default GNOME flatpaks that ship with Bazzite (Calculator, Calendar, Loupe, Papers, Showtime, etc.) — hand-edit the file before commit.

**Add a new Linux machine**

```sh
just backup mynewbox                      # creates brewfiles/Brewfile.mynewbox
# clean up the dumped flatpaks, commit
```

## Brave policy

`assets/brave-policy.json` is the source of truth for the Brave policy across all platforms. Keep it in sync with `Mac/assets/brave-debloat.mobileconfig` and `Windows/brave-policy.json` — same policy set, three formats.

## Per-machine variation

Like the Mac side, Brewfiles diverge per machine. The system-layer arrays in `install-bazzite.sh` (`RPM_PACKAGES`, `GNOME_EXTENSIONS`) currently apply uniformly — split them out per machine if the divergence matters.

## Manual extras

Things the install flow doesn't do for you — run by hand on a fresh machine when you actually need them.

### Kiro CLI

Anthropic-style coding agent CLI from AWS. One-shot installer, not in the Brewfile.

```sh
curl -fsSL https://cli.kiro.dev/install | bash
```

### Newelle (immutable-host config)

Newelle is a GTK4 LLM client. On Bazzite the Flatpak sandbox can't reach the host shell out of the box — the install adds the Flatpak but you still need to grant `flatpak-spawn` permission and disable Newelle's "Command Virtualization" toggle if you want it to run host commands.

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
