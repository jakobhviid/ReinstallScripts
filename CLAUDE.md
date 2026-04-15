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
- `Linux/zshrc.template` — Zsh config template for Linux (uses `BREW_PREFIX` placeholder)
- `Windows/bootstrap.ps1` — One-time admin setup (Scoop, just, WSL, ssh-agent)
- `shared/starship.toml` — Starship prompt config (shared across all platforms)
- `shared/tmux.conf` — Tmux config (shared across Mac and Linux)
- `shared/zsh-guide.md` — Zsh keybindings and workflow reference
- `Windows/justfile` — Recipes for installing apps and setting up the shell
- `Windows/profile.template.ps1` — PowerShell profile template (equivalent to zshrc.template)
- `Windows/brave-policy.json` — Brave browser policy (same policies as Mac/Linux)
- `Linux/Bazzite.md` — Notes for Bazzite Linux setup
- `Linux/speaker-eq.conf` — PipeWire filter-chain EQ for ThinkPad X1 Carbon speakers (deployed by `just speaker-eq` or `install-fedora-workstation.sh`)

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
  - **Linux:** `Linux/brave-policy.json` + `Linux/install-bazzite.sh` inline in `run_config_brave_policy()`
  - **Windows:** `Windows/brave-policy.json`
  When adding, removing, or changing a Brave policy, update all locations.
- **Git identity across all platforms is "Jakob Hviid, PhD" / jakob@hviid.phd** with `pull.rebase true`. Set by `just zsh` on Mac/Linux.
- **Shell config changes must be applied to all locations.** Each platform has its own template and install scripts:
  - `Mac/zshrc.template` + `Mac/justfile` zsh recipe
  - `Linux/zshrc.template` + `Linux/justfile` zsh recipe
  - `Linux/install-ubuntu-server.sh` (inline heredoc)
  - `Linux/install-bazzite.sh` (inline heredoc)
  - `Windows/profile.template.ps1` + `Windows/justfile` zsh recipe
- **Mac Brewfiles are intentionally different per machine.** Each machine serves a different purpose (Chronos = personal laptop, Helios = server, huginn = work laptop). Do not flag cross-machine package inconsistencies as issues.
- `Windows/supportfiles/` contains registry fixes (network drive warning) and Windows Terminal settings.
