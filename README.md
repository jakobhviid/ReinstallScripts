# Reinstall Scripts

Mac script use [Homebrew](https://brew.sh/), while Windows uses [Scoop](https://scoop.sh/) and [AppGet](https://appget.net/).

## Missing items from install script for Windows 10

1. [Office 365 Home](https://account.microsoft.com/services/office/install)
2. [Visual Studio Community 2019](https://visualstudio.microsoft.com/downloads/)
3. Windows Store Apps
   1. Microsoft To-do
   2. Ubuntu (for WSL)
   3. Remote Desktop
   4. Termius
   5. Plex
   6. Netflix
   7. Messenger

## Getting Started with Windows 10

Begin installation using the following:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

#run as admin
.\install-1-managers.ps1

#run as user
.\install-2-applications.ps1

C:\Users\jakob\scoop\apps\vscode\current\vscode-install-context.reg
```

More packages can be found at [Scoop](https://github.com/ScoopInstaller/Main/tree/master/bucket), and [AppGet](https://appget.net/packages).
