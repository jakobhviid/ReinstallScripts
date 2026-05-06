# Mac setup

Re-runnable, declarative macOS provisioning driven by [`brew bundle`](https://github.com/Homebrew/homebrew-bundle) and [`just`](https://github.com/casey/just). Each machine has its own `brewfiles/Brewfile.<name>` listing every formula, cask, Mac App Store app, VS Code extension, and tap that should be installed on it.

## Prerequisites

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install just
```

## Layout

```
Mac/
├── brewfiles/Brewfile.<machine>   ← source of truth per machine
├── assets/                         ← templates + macOS configuration profiles
│   ├── zshrc.template
│   └── *.mobileconfig
├── lib/common.sh                   ← logger + interactive picker shared by recipes
├── justfile                        ← all recipes
└── README.md
```

## Recipes

Run from the `Mac/` directory.

| Command                          | What it does                                                                  |
|----------------------------------|-------------------------------------------------------------------------------|
| `just`                           | List recipes + available machines/profiles                                    |
| `just install <machine>`         | `brew bundle --file=brewfiles/Brewfile.<machine>`, then `just zsh` + `just brave` |
| `just install`                   | Interactive — pick a machine from a numbered menu                             |
| `just backup <machine>`          | `brew bundle dump` current state into `brewfiles/Brewfile.<machine>`          |
| `just backup`                    | Interactive — pick existing or type a new machine name                        |
| `just cleanup <machine>`         | Show packages installed but not in the machine's Brewfile                     |
| `just brave`                     | Apply Brave debloat profile + Cmd+W keyboard workaround                       |
| `just profile <name>`            | Install `assets/<name>.mobileconfig` (opens System Settings)                  |
| `just zsh`                       | Re-template `~/.zshrc`, configure git/tmux/starship, install zsh plugins      |

## Workflow

**First-time setup on a new Mac**

```sh
just install huginn      # or whichever machine matches
```

That installs everything in `brewfiles/Brewfile.huginn`, then sets up the shell, then opens the Brave debloat profile.

**Capture current state**

```sh
just backup huginn       # overwrites brewfiles/Brewfile.huginn
```

After running, `git diff` and trim anything you don't actually want to track.

**Add a new machine**

```sh
just backup mynewmac     # creates brewfiles/Brewfile.mynewmac
git add brewfiles/Brewfile.mynewmac && git commit
```

## Per-machine variation is intentional

Brewfiles intentionally diverge — Chronos is a personal laptop, Helios is a server, huginn is a work laptop. Don't flag cross-machine package differences as drift.

## Brave configuration

`just brave` and `just profile brave-debloat` are equivalent — `just brave` is just a thin wrapper. Either way, two things happen:

1. **Rebinds Brave's "Close Window" to ⌘⇧W** via `defaults write com.brave.Browser NSUserKeyEquivalents -dict-add "Close Window" '@$w'`. Workaround for an intermittent Chromium bug where Brave's File menu loses the "Close Tab" item and "Close Window" hijacks ⌘W. Runs *first* — `defaults` is non-interactive and System Settings is user-blocking. Restart Brave for the rebinding to take effect.
2. **Opens `assets/brave-debloat.mobileconfig`** in System Settings → Profiles. This is the macOS counterpart of `Linux/assets/brave-policy.json` and `Windows/brave-policy.json` — keep all three in sync when changing Brave policies (same policy set, three formats).

The companion `defaults write` lives as a `case` branch in the `profile` recipe (keyed on the profile name), so any path that installs `brave-debloat` — interactive picker, direct invocation, or `just brave` — gets the keyboard fix.

To remove the keyboard rebinding: `defaults delete com.brave.Browser NSUserKeyEquivalents`.

## Reference

For more on Homebrew Bundle, see [this guide](https://tomlankhorst.nl/brew-bundle-restore-backup/).
