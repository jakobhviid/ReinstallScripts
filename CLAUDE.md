# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A collection of OS reinstall/setup scripts organized by platform and machine. No build system or test suite — the "output" is a correctly configured machine.

## Structure

- `Mac/Brewfile.<machine>` — Per-machine Homebrew bundle (Chronos, Helios, huginn)
- `Mac/justfile` — Recipes for installing/backing up Brewfiles and Zsh setup
- `Mac/zshrc.template` — Zsh config template for macOS (uses `BREW_PREFIX` placeholder)
- `Mac/brave-debloat.mobileconfig` — macOS configuration profile to debloat Brave browser
- `Linux/justfile` — Recipe for installing/updating Zsh setup
- `Linux/assets/zshrc.template` — Zsh config template for Linux (uses `BREW_PREFIX` placeholder)
- `Linux/install-bazzite.sh` — Thin setup script for Bazzite (rpm-ostree + Flatpak)
- `Linux/install-fedora-workstation.sh` — Thin setup script for Fedora Workstation (dnf + Flatpak)
- `Linux/lib/{common,install,repos,config}.sh` — Shared library sourced by both install scripts
- `Windows/bootstrap.ps1` — One-time admin setup (Scoop, just, WSL, ssh-agent)
- `shared/starship.toml` — Starship prompt config (shared across all platforms)
- `shared/tmux.conf` — Tmux config (shared across Mac and Linux)
- `shared/zsh-guide.md` — Zsh keybindings and workflow reference
- `shared/app-icons/` — Custom icons for `.desktop` overrides (deployed to `~/.local/share/icons/reinstall-scripts/` by the Fedora/Bazzite installers)
- `Windows/justfile` — Recipes for installing apps and setting up the shell
- `Windows/profile.template.ps1` — PowerShell profile template (equivalent to zshrc.template)
- `Windows/brave-policy.json` — Brave browser policy (same policies as Mac/Linux)
- `Linux/Bazzite.md` — Notes for Bazzite Linux setup
- `Linux/assets/{brave-policy.json,rename-devices.conf,speaker-eq.conf,zshrc.template}` — Data assets deployed by the Linux installers / justfile recipes. Scripts resolve them via `$SCRIPT_DIR/assets/…` (or `{{justfile_directory()}}/assets/…`).
- `Linux/assets/gnome/shell.dconf` — Snapshot of the GNOME shell config (enabled-extensions + dash-to-panel/blur-my-shell/hotedge settings) loaded into `/org/gnome/shell/` by `run_config_gnome_shell`. **Regenerate with `just gnome-backup`** — that recipe re-dumps the live state and strips bookkeeping keys (prefs-opened, extension-version, rounded-blur-found, settings-version) and per-monitor panel layout (panel-anchors/positions/sizes/lengths/element-positions, which encode this machine's display connector ID and don't transfer). After tweaking dash-to-panel etc., re-run the recipe and commit so the next install matches.

## Mac Workflow

Requires [just](https://github.com/casey/just) (`brew install just`). Run from `Mac/`:

```sh
just install huginn        # Install packages for a machine
just backup huginn         # Dump current state to Brewfile.huginn
just backup mynewmac       # Create a new machine's Brewfile
just profile brave-debloat # Install a macOS configuration profile
just install               # Interactive — prompts with numbered menu
just                       # Show available commands/machines/profiles
```

**Install Homebrew (first-time):**
```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Machines: Chronos (personal laptop), Helios (server), huginn (work laptop).

## Linux Zsh Sync

Requires [just](https://github.com/casey/just) (`brew install just`). Run from `Linux/`:

```sh
just zsh    # Install/update Zsh plugins, config, prompt theme, and git identity
just        # Show available commands
```

First-time setup still uses `install-ubuntu-server.sh` or `install-bazzite.sh`. The justfile is for re-syncing config after the initial install.

## Zsh Config Sync

Both `just zsh` (Mac and Linux) fully overwrite `~/.zshrc` from the platform's `zshrc.template`. Per-machine customizations go in `~/.zshrc.local`, which is sourced at the end of `.zshrc` if it exists.

The templates use `BREW_PREFIX` as a placeholder, substituted at install time via `sed`. The `shared/starship.toml` config is shared across all platforms and deployed to `~/.config/starship.toml` by each platform's `just zsh` recipe.

## Windows Workflow

Requires a one-time bootstrap (as admin), then uses [just](https://github.com/casey/just) for everything else. Run from `Windows/`:

```powershell
# First time only (as admin) — installs Scoop, just, WSL, ssh-agent
.\bootstrap.ps1
# Reboot here

# Then use just for everything
just install    # All apps (winget+scoop), CLI tools, fonts, Brave policy, registry fixes
just zsh        # PowerShell profile, git config, Windows Terminal settings (re-runnable)
just games      # Game launchers — Steam, Epic, etc. (optional)
just            # Show available commands
```

## Adding a New Mac Machine

From the `Mac/` directory, run `just backup <machinename>` to create `Brewfile.<machinename>`, then commit it.

## Key Notes

- **Never run justfile recipes, install scripts, or other destructive commands without explicit user consent.** These scripts install packages, modify system state, and open configuration profiles. When testing justfile changes, always use `just --dry-run <recipe>` to inspect the generated script. Only run a recipe live if the user explicitly asks for it.
- **Brave browser policies must stay in sync across all platforms.** The same set of policies exists in these locations:
  - **Mac:** `Mac/brave-debloat.mobileconfig` (plist format)
  - **Linux:** `Linux/assets/brave-policy.json` (single source of truth — deployed by `run_config_brave_policy` in `Linux/lib/config.sh` for both Bazzite and Fedora Workstation)
  - **Windows:** `Windows/brave-policy.json`
  When adding, removing, or changing a Brave policy, update all locations.
- **Git identity across all platforms is "Jakob Hviid, PhD" / jakob@hviid.phd** with `pull.rebase true`. Set by `just zsh` on Mac/Linux.
- **Shell config changes must be applied to all locations.** Each platform has its own template:
  - `Mac/zshrc.template` + `Mac/justfile` zsh recipe
  - `Linux/assets/zshrc.template` + `Linux/justfile` zsh recipe (invoked by the Fedora/Bazzite installers via the shared `install_zsh_setup` helper)
  - `Linux/install-ubuntu-server.sh` (inline heredoc — server is out of the shared-lib flow)
  - `Windows/profile.template.ps1` + `Windows/justfile` zsh recipe
- **Mac Brewfiles are intentionally different per machine.** Each machine serves a different purpose (Chronos = personal laptop, Helios = server, huginn = work laptop). Do not flag cross-machine package inconsistencies as issues.
- **Linux installers are add-only and non-interactive.** Both `install-bazzite.sh` and `install-fedora-workstation.sh` detect what's already installed, print a summary of what's missing, ask `Proceed? [y/N]`, and then install everything idempotently. They never uninstall — to drop an app, remove its line from the relevant array in the top-level script and uninstall it manually on the machine.
- **Shared Linux install logic lives in `Linux/lib/`** (sourced by both install scripts):
  - `common.sh` — `info`/`ok`/`warn`/`err` loggers + `confirm` prompt
  - `install.sh` — detection helpers, `filter_to_install`, CLI-tool install/uninstall, `ensure_gext`
  - `repos.sh` — `ensure_repo` for Brave, 1Password, VS Code, Proton VPN, Claude Desktop
  - `config.sh` — all shared `run_config_*` (brave policy, 1password, desktop overrides, autostart, audio, GNOME shell)
  Distro-specific bits (`run_config_speaker_eq`, `setup_rpmfusion`, `setup_multimedia_codecs`) stay inline in `install-fedora-workstation.sh`.
- **Linux `.desktop` icon/Exec overrides and autostart are configured once in `Linux/lib/config.sh`**. To add a new icon override: drop the file in `shared/app-icons/`, then add a `name|source|icon` row to the `overrides` array in `run_config_desktop_overrides`. To add an autostart app: add a `name|fallback-source` row to the `entries` array in `run_config_autostart`. Both edits are single-source now — no duplication.
- `Windows/supportfiles/` contains registry fixes (network drive warning) and Windows Terminal settings.
