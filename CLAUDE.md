# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Memory

Persistent project memory lives in [MEMORY.md](MEMORY.md) at the repo root, **not** in the harness's per-user auto-memory directory (`~/.claude/projects/.../memory/`). This is deliberate: the repo is meant to set up Jakob's machines, so context that helps Claude work here needs to travel with the code via git, not stay siloed on whichever machine first wrote it.

- **Read MEMORY.md** at the start of any non-trivial task in this repo — it captures preferences, decisions, and gotchas not visible in the code.
- **When you learn something durable** (a user preference, a project decision, a hard-won gotcha), add it to MEMORY.md. Do not write to `~/.claude/projects/.../memory/` for repo-scoped memories.
- The auto-memory directory is fine for facts about Jakob that span multiple repos — but anything specific to this repo or its conventions belongs in MEMORY.md.

## Overview

A collection of OS reinstall/setup scripts organized by platform and machine. No build system or test suite — the "output" is a correctly configured machine.

## Structure

Mac and Linux are aligned: both have `brewfiles/`, `assets/`, `lib/`, a top-level `justfile`, and a `README.md` describing usage.

```
Mac/
├── brewfiles/Brewfile.<machine>     ← per-machine Homebrew bundle (Chronos, Helios, huginn)
├── assets/                           ← templates + macOS configuration profiles (.mobileconfig)
│   ├── zshrc.template
│   └── *.mobileconfig (brave-debloat, encrypted-dns, privacy-baseline)
├── lib/common.sh                     ← logger + interactive picker shared by recipes
├── justfile                          ← install / backup / drift / profile / zsh / brave
└── README.md

Linux/
├── install-bazzite.sh                ← orchestrator: rpm-ostree → brew bundle → gext → run_config_*
├── brewfiles/Brewfile.<machine>      ← per-machine userspace bundle (chronos-redux, atlas)
├── assets/                            ← deployable data (zshrc template, dconf snapshots, brave policy, EQ, PWAs, icons)
├── lib/{common,install,repos,config}.sh
├── justfile                           ← install / backup / drift / zsh / speaker-eq / brave / *-backup / *-restore
└── README.md

Windows/
├── bootstrap.ps1                      ← one-time admin setup (Scoop, just, WSL, ssh-agent)
├── justfile                           ← install / zsh / games
├── profile.template.ps1               ← PowerShell profile template (BREW_PREFIX placeholder)
├── brave-policy.json
└── supportfiles/                      ← registry fixes, Windows Terminal settings

shared/
├── starship.toml                      ← Starship prompt config (all platforms)
├── tmux.conf                          ← Tmux config (Mac + Linux)
├── zsh-guide.md                       ← Keybindings + workflow reference
└── app-icons/                         ← Custom icons for Linux .desktop overrides
```

### Linux assets of note

- `Linux/assets/gnome/shell.dconf` — Snapshot of `/org/gnome/shell/` (enabled-extensions + dash-to-panel/blur-my-shell/hotedge), loaded by `run_config_gnome_shell`. **Regenerate with `just gnome-backup`** — that recipe re-dumps live state and strips bookkeeping keys (prefs-opened, extension-version, rounded-blur-found, settings-version) and per-monitor panel layout (panel-anchors/positions/sizes/lengths/element-positions, which encode this machine's display connector ID and don't transfer). After tweaking dash-to-panel etc., re-run the recipe and commit.
- `Linux/assets/ptyxis.dconf` — Snapshot of `/org/gnome/Ptyxis/` (profiles, keybindings, window prefs), loaded by `run_config_ptyxis`. **Regenerate with `just ptyxis-backup`** — full subtree dump, no filtering. Profile UUIDs are just identifiers and carry across machines.
- `Linux/assets/bazzite-flatpak-ignore.txt` — Flatpak app IDs that `just drift`, `just reconcile`, and `just prune` should treat as baseline (not flag as extras and not offer to uninstall). Used to silence default Bazzite GNOME apps that ship with the OS so drift output stays focused on real per-machine changes. One app ID per line; `#` for comments.

## Mac Workflow

Requires Homebrew + [just](https://github.com/casey/just). Run from `Mac/`:

```sh
just install huginn        # brew bundle --file=brewfiles/Brewfile.huginn + just zsh + just brave
just backup huginn         # brew bundle dump --file=brewfiles/Brewfile.huginn
just drift huginn          # show what's out of sync with the repo (read-only)
just backup mynewmac       # create a new machine's Brewfile (then hand-edit + commit)
just brave                 # apply assets/brave-debloat.mobileconfig + Cmd+W keyboard workaround
just profile brave-debloat # install any assets/<name>.mobileconfig directly
just install               # interactive picker
just                       # list recipes + machines/profiles
```

Machines: Chronos (personal laptop), Helios (server), huginn (work laptop).

## Linux Workflow

Requires a fresh Bazzite. Homebrew and `just` are bootstrapped by the script. Run from `Linux/`:

```sh
./install-bazzite.sh chronos-redux   # full flow — rpm-ostree → brew bundle → gext → configs
just install chronos-redux           # equivalent, via justfile
just backup chronos-redux            # dump live brew + flatpak state to brewfiles/Brewfile.chronos-redux
just drift chronos-redux             # show what's out of sync with the repo (read-only)
just zsh                             # re-template ~/.zshrc.image (managed) + bootstrap ~/.zshrc (once) + tmux/tpm + git identity
just speaker-eq                      # PipeWire filter-chain EQ for thin laptop speakers
just brave                           # deploy assets/brave-policy.json
just gnome-backup / just ptyxis-backup     # snapshot live dconf state to assets/
just gnome-restore / just ptyxis-restore   # push the snapshot back to live (asks first)
```

`brew bundle dump` pulls in default GNOME flatpaks that ship with Bazzite — hand-edit `brewfiles/Brewfile.<machine>` after `just backup` before committing.

## Zsh Config Sync

**Mac:** `just zsh` fully overwrites `~/.zshrc` from `Mac/assets/zshrc.template` on every run.

**Linux:** `just zsh` uses a two-file split (introduced 2026-05):
- `~/.zshrc.image` — managed file, rewritten on every `just zsh` from `Linux/assets/zshrc.template`. Drift checks this file.
- `~/.zshrc` — user-owned. Bootstrapped once from `Linux/assets/zshrc-bootstrap` if missing or if it doesn't yet contain the `source ~/.zshrc.image` line; left alone after that. Tools that auto-edit `.zshrc` (nvm, bun, pyenv) no longer get clobbered on the next `just zsh`.

Per-machine customizations go in `~/.zshrc.local` on both platforms, sourced at the end of the template if it exists.

The templates use `BREW_PREFIX` as a placeholder, substituted at install time via `sed`. The `shared/starship.toml` config is shared across all platforms and deployed to `~/.config/starship.toml` by each platform's `just zsh` recipe.

## Windows Workflow

```powershell
# First time only (as admin) — Scoop, just, WSL, ssh-agent
.\bootstrap.ps1
# Reboot here

just install    # All apps (winget+scoop), CLI tools, fonts, Brave policy, registry fixes
just zsh        # PowerShell profile, git config, Windows Terminal settings (re-runnable)
just games      # Game launchers — Steam, Epic, etc. (optional)
just            # list recipes
```

## Key Notes

- **Never run justfile recipes, install scripts, or other destructive commands without explicit user consent.** These scripts install packages, modify system state, and open configuration profiles. When testing justfile changes, use `just --dry-run <recipe>` to inspect the generated script. Only run a recipe live if the user explicitly asks for it.
- **Brave browser policies must stay in sync across all platforms.** Same policy set, three formats:
  - **Mac:** `Mac/assets/brave-debloat.mobileconfig` (plist)
  - **Linux:** `Linux/assets/brave-policy.json` (canonical editable source). The bazzite-custom image bakes a copy at `system_files/etc/brave/policies/managed/brave-policy.json` and is what actually loads on rebased machines — when changing the policy, edit this file, sync to bazzite-custom, push the image.
  - **Windows:** `Windows/brave-policy.json`
  When adding, removing, or changing a Brave policy, update all four locations (Mac, Linux source, Linux image copy, Windows).
- **Git identity across all platforms is "Jakob Hviid, PhD" / jakob@hviid.phd** with `pull.rebase true`. Set by `just zsh` on Mac/Linux.
- **Shell config changes must be applied to all locations.** Each platform has its own template:
  - `Mac/assets/zshrc.template` + `Mac/justfile` zsh recipe
  - `Linux/assets/zshrc.template` + `Linux/justfile` zsh recipe (invoked by `install-bazzite.sh` via the `install_zsh_setup` helper)
  - `Windows/profile.template.ps1` + `Windows/justfile` zsh recipe
- **Per-machine Brewfile divergence is intentional.** Each machine serves a different purpose. Don't flag cross-machine package inconsistencies as issues.
- **`install-bazzite.sh` is add-only and idempotent.** It detects what's already installed, prints a Plan, asks `Proceed? [y/N]`, then installs only what's missing. It never uninstalls — to drop an app, edit the relevant array (or `brewfiles/Brewfile.<machine>`) and uninstall the app manually.
- **`install-bazzite.sh` is phase-aware**, auto-detected via `rpm-ostree status`:
  - **Phase 1** (NOT yet on the bazzite-custom image): installs the vendored cosign pub key from `Linux/assets/bazzite-custom.pub`, drops a `/etc/containers/registries.d/` entry, JSON-merges a sigstoreSigned trust rule into `/etc/containers/policy.json`, then `rpm-ostree rebase` to the user's chosen image variant followed by `rpm-ostree install --idempotent proton-vpn-gnome-desktop`, then reboot prompt. Image variant is selected via `pick_image_variant`: detects NVIDIA hardware via `lspci`, preselects `bazzite-nvidia-custom` (NVIDIA) or `bazzite-custom` (no NVIDIA), and lets the user confirm/override via `pick_choice`.
  - **Phase 2** (already on the image): brew bootstrap → brew bundle → `gext` → `just zsh` → per-user `run_config_*`.
- **System layer is mostly in the bazzite-custom image now.** `RPM_PACKAGES` in `install-bazzite.sh` is just `proton-vpn-gnome-desktop` — the package can't be image-baked because its post-install scriptlet calls `systemctl`, which fails in a build container. Most other system pieces (browsers, Claude Desktop, dash-to-panel/dock, CLI baseline, brave policy, wireplumber renames, three unlock services, 33 preinstalled flatpaks) are in the image. **1Password is the exception**: it lives in `brewfiles/Brewfile.<machine>` as `cask "ublue-os/tap/1password-gui-linux"`, not in the image. See `bazzite-custom/README.md` for the full inventory.
- **1Password — load-bearing lessons (don't re-debug from scratch):**
  - **Never `usermod -aG onepassword $USER`.** 1P's IPC peer auth in the main app accepts `egid == onepassword` only when it could have come from a setgid exec — adding the user to the group makes that egid trivially obtainable from any user process, the auth check becomes a no-op, and 1P rejects all browser-extension connections with `PipeAuthError(NoCreds)` / `invalid group attempted to connect`. The cask deliberately does NOT add the user. Common stale tutorials say to add the user; they are wrong on Linux. `Linux/lib/config.sh`'s `run_config_1password` aborts if it detects this state, and `just drift` flags it.
  - **`/etc/1password/custom_allowed_browsers` perms must be 0755 (or 0644) root:root.** 1P's check is "writable by root and only by root" — `0444` fails because root has no write bit. The cask installs `0644`; we keep it `0755` after appending entries.
  - **Vivaldi (`vivaldi-bin`) and Zen (`zen-bin`) need explicit allowlist entries.** 1P's hardcoded trusted basenames are only `chrome chromium-browser-privacy msedge brave firefox firefox-bin firefox-esr`. The cask only writes `flatpak-session-helper`. `run_config_1password` appends both. Cask file ships without trailing newline — handle when appending.
  - **Zen needs its own NMH manifest copied from `~/.mozilla/native-messaging-hosts/`** to `~/.zen/native-messaging-hosts/` (Firefox-style with `allowed_extensions`). The cask doesn't know about Zen.
  - **`op` CLI from brew can't pair with the brew GUI** (ublue-os/homebrew-tap#208 is open). Not bundled, not used here.
- **Userspace layer** (brew-managed) — `brewfiles/Brewfile.<machine>` covers taps, formulae, casks, and Flatpaks via the `flatpak` Brewfile directive. Applied by `brew bundle` in Phase 2. Brewfiles after the image rework only contain things NOT in the image: brew-only zsh plugins (autopair, completions, history-substring-search, you-should-use), niche tools (sesh, fzf-tab, typst, dotnet), claude-code (frequent updates), VS Code via ublue tap, the 3 NF-patched typefaces, and all flatpaks (the 33 image-preinstalled ones still listed as canonical "this machine wants this" record — `flatpak install` is idempotent).
- **Shared Linux install logic lives in `Linux/lib/`** (sourced by `install-bazzite.sh`):
  - `common.sh` — `info`/`ok`/`warn`/`err` loggers, `confirm` prompt, `pick_choice` interactive picker
  - `install.sh` — detection helpers (`is_rpm_installed`, `is_flatpak_installed`, `is_gext_installed`, `is_cli_installed`), `filter_to_install`, CLI-tool install/uninstall (`brew`, `zsh-setup`), `ensure_gext`
  - `repos.sh` — `ensure_repo` for Proton VPN only (other repos baked in image)
  - `config.sh` — per-user `run_config_*` (1password GNOME keybinding + dark titlebar, desktop overrides, PWAs, autostart with background-launch flags, localsend dark titlebar, GNOME shell, Ptyxis). Functions deleted in the image rework: `run_config_brave_policy`, `run_config_audio`, `run_config_unlock_services` — image bakes those.
- **Linux `.desktop` icon/Exec overrides and autostart are configured once in `Linux/lib/config.sh`.** To add a new icon override: drop the file in `shared/app-icons/`, then add a `name|source|icon` row to the `overrides` array in `run_config_desktop_overrides`. To add an autostart app: add a `name|fallback-source` row to the `entries` array in `run_config_autostart`, plus a `case` branch if the autostart copy needs a background-launch flag injected (`--silent`, `--start-minimized`, `--background`, `--hidden`).
- **Mac `lib/common.sh`** holds the same logger functions and `pick_choice` helper used by `Linux/lib/common.sh` — keep the two in sync if you change the picker contract.
- `Windows/supportfiles/` contains registry fixes (network drive warning) and Windows Terminal settings.
