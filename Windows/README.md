# Getting Started with Windows

## First-time setup

Run `bootstrap.ps1` as admin to install Scoop, just, oh-my-posh, WSL, and ssh-agent:

```powershell
.\bootstrap.ps1
# Reboot here
```

## After reboot

From the `Windows/` directory:

```powershell
just install    # All apps (winget+scoop), CLI tools, fonts, Brave policy
just zsh        # PowerShell profile, git config, Windows Terminal settings
just games      # Game launchers (optional)
```

To re-sync shell config after changes (re-runnable):

```powershell
just zsh
```

More packages can be found at [Scoop](https://github.com/ScoopInstaller/Main/tree/master/bucket) and [winget](https://winget.run/).
