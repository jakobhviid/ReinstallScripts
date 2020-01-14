# Reinstall Scripts

Mac script use [Homebrew](https://brew.sh/), while Windows uses [Chocolatey](https://chocolatey.org/), [Scoop](https://scoop.sh/) and [AppGet](https://appget.net/).

## Missing items from install script

1. [Live Tex](https://www.tug.org/texlive/acquire-netinstall.html)
2. [Office 365 Home](https://account.microsoft.com/services/office/install)
3. [Visual Studio Community 2019](https://visualstudio.microsoft.com/downloads/)
4. Windows Store Apps
   1. 1Password
   2. Spotify
   3. Microsoft To-do
   4. Signal
   5. OneNote
   6. Ubuntu (for WSFL)
   7. Remote Desktop
   8. Termius
   9. Plex
   10. Netflix
   11. Terminal
   12. Messenger (beta)

## Getting Started

Begin installation using the following:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')

.\install-2-applications.ps1
.\install-3-applications.ps1

C:\Users\jakob\scoop\apps\vscode\current\vscode-install-context.reg
```

More packages can be found at [Scoop](https://github.com/ScoopInstaller/Main/tree/master/bucket), [AppGet](https://appget.net/packages), and [Chocolatey](https://chocolatey.org/packages).
