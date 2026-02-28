# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A collection of OS reinstall/setup scripts organized by platform and machine. No build system or test suite — the "output" is a correctly configured machine.

## Structure

- `Mac/<machine>/Brewfile` — Per-machine Homebrew bundle (brew formulae, casks, Mac App Store apps, VS Code extensions)
- `Mac/<machine>/brave-debloat.mobileconfig` — macOS configuration profile to debloat Brave browser
- `Windows/` — Numbered PowerShell scripts meant to be run in order
- `Linux/Bazzite.md` — Notes for Bazzite Linux setup

## Mac Workflow

**Install from Brewfile:**
```sh
brew bundle
```

**Capture current machine state to Brewfile:**
```sh
brew bundle dump
```

**Install Homebrew (first-time):**
```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Each machine has its own subdirectory (`Chronos`, `Helios`, `huginn`) with a tailored Brewfile. Run `brew bundle` from within that machine's directory.

## Windows Workflow

Scripts must be run in order. Scripts 1 and 3–4 require admin; script 2 runs as user.

```powershell
# First: allow script execution
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

# Run as admin
.\install-1-managers.ps1   # Scoop, AppGet, posh-git, oh-my-posh, WSL, ssh-agent
# Reboot here
.\install-2-applications.ps1  # All apps, git config, registry fixes, fonts
.\install-3-gamerelated.ps1   # Logitech G Hub, Steam, Epic, etc.
.\install-4-specificgames.ps1 # SteamCMD + game batch install

# After VS Code installs:
C:\Users\jakob\scoop\apps\vscode\current\vscode-install-context.reg
```

## Adding a New Mac Machine

Create `Mac/<machinename>/Brewfile` by running `brew bundle dump` on the new machine, then commit it. Optionally copy `brave-debloat.mobileconfig` if Brave is used.

## Key Notes

- Windows scripts reference `jakobhviid1982@gmail.com` as the git user — update if setting up for a different identity.
- `supportfiles/` contains registry fixes (GitKraken, network drive warning) and fonts (Cascadia, Delugia Nerd Font) used by `install-2-applications.ps1`.
- AppGet (`appget.net`) referenced in Windows scripts is discontinued; those entries may need replacing with Scoop or Winget equivalents.
