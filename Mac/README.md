# Getting Started with Mac

Install [Homebrew](https://brew.sh/) and [just](https://github.com/casey/just):

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install just
```

Then from the `Mac/` directory:

```sh
# Install packages for a machine
just install huginn

# Or run interactively (prompts for machine name)
just install

# Backup current machine state
just backup huginn

# Or run interactively (pick existing or create new)
just backup

# Install a macOS configuration profile
just profile brave-debloat

# Show all commands and available machines/profiles
just
```

Each machine has its own `Brewfile.<name>` — one self-contained file with all packages, casks, Mac App Store apps, and VS Code extensions.

For more on Homebrew Bundle, see [this guide](https://tomlankhorst.nl/brew-bundle-restore-backup/).
