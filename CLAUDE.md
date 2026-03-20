# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A collection of OS reinstall/setup scripts organized by platform and machine. No build system or test suite — the "output" is a correctly configured machine.

## Structure

- `Mac/Brewfile.<machine>` — Per-machine Homebrew bundle (Chronos, Helios, huginn)
- `Mac/justfile` — Recipes for installing and backing up Brewfiles
- `Mac/brave-debloat.mobileconfig` — macOS configuration profile to debloat Brave browser
- `Linux/justfile` — Recipe for installing/updating Zsh setup
- `Linux/zshrc.template` — Zsh config template for Linux (uses `BREW_PREFIX` placeholder)
- `Windows/` — Numbered PowerShell scripts meant to be run in order
- `Linux/Bazzite.md` — Notes for Bazzite Linux setup

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
just zsh    # Install/update Zsh plugins, config, and prompt theme
just        # Show available commands
```

First-time setup still uses `install-ubuntu-server.sh` or `install-bazzite.sh`. The justfile is for re-syncing config after the initial install.

## Windows Workflow

Scripts must be run in order. Scripts 1 and 3–4 require admin; script 2 runs as user. Uses Scoop for CLI/dev tools and winget for GUI applications.

```powershell
# First: allow script execution
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

# Run as admin
.\install-1-managers.ps1   # Scoop, oh-my-posh, posh-git, WSL, ssh-agent
# Reboot here
.\install-2-applications.ps1  # All apps (winget+scoop), git config, registry fixes, fonts
.\install-3-gamerelated.ps1   # Logitech G Hub, Steam, Epic, etc.
.\install-4-specificgames.ps1 # SteamCMD + game batch install
```

## Adding a New Mac Machine

From the `Mac/` directory, run `just backup <machinename>` to create `Brewfile.<machinename>`, then commit it.

## Key Notes

- **Never run justfile recipes, install scripts, or other destructive commands without explicit user consent.** These scripts install packages, modify system state, and open configuration profiles. When testing justfile changes, always use `just --dry-run <recipe>` to inspect the generated script. Only run a recipe live if the user explicitly asks for it.
- **Brave browser policies must stay in sync across all platforms.** The same set of policies exists in three formats:
  - **Mac:** `Mac/brave-debloat.mobileconfig` (plist)
  - **Linux:** `Linux/Bazzite.md` — inline JSON block at `/etc/brave/policies/managed/brave-policy.json`
  - **Windows:** TBD (no Brave policy file exists yet)
  When adding, removing, or changing a Brave policy, update all locations.
- **Git identity across all platforms is "Jakob Hviid, PhD" / jakob@hviid.phd** with `pull.rebase true`.
- **Mac Brewfiles are intentionally different per machine.** Each machine serves a different purpose (Chronos = personal laptop, Helios = server, huginn = work laptop). Do not flag cross-machine package inconsistencies as issues.
- `supportfiles/` contains registry fixes (network drive warning), fonts (Cascadia, Delugia Nerd Font), and Windows Terminal settings used by `install-2-applications.ps1`.
