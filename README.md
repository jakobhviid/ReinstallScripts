# Reinstall Scripts

Mac script use [Homebrew](https://brew.sh/), while Windows uses [Scoop](https://scoop.sh/) and [AppGet](https://appget.net/).

## Missing items from install script

1. [Live Tex](https://www.tug.org/texlive/acquire-netinstall.html)
2. [Office 365 Home](https://account.microsoft.com/services/office/install)
3. [Visual Studio Community 2019](https://visualstudio.microsoft.com/downloads/)
4. Windows Store Apps
   1. 1Password
   2. Microsoft To-do
   3. OneNote
   4. Ubuntu (for WSFL)
   5. Remote Desktop
   6. Termius
   7. Plex
   8. Netflix
   9. Terminal
   10. Messenger (beta)

## Getting Started

Begin installation using the following:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

#run as admin
.\install-1-managers.ps1

#run as user
.\install-2-applications.ps1

C:\Users\jakob\scoop\apps\vscode\current\vscode-install-context.reg
```

More packages can be found at [Scoop](https://github.com/ScoopInstaller/Main/tree/master/bucket), and [AppGet](https://appget.net/packages).
