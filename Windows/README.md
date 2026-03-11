# Getting Started with Windows

Begin installation using the following:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

# Run as admin
.\install-1-managers.ps1
# Reboot here

# Run as user
.\install-2-applications.ps1

# Run as admin
.\install-3-gamerelated.ps1
.\install-4-specificgames.ps1
```

More packages can be found at [Scoop](https://github.com/ScoopInstaller/Main/tree/master/bucket) and [winget](https://winget.run/).

## Missing items from install script

1. [Office 365 Home](https://account.microsoft.com/services/office/install)
2. [Visual Studio Community](https://visualstudio.microsoft.com/downloads/)
3. Windows Store Apps
   1. Microsoft To-do
   2. OneNote
   3. Ubuntu (for WSL)
   4. Remote Desktop
   5. Plex
   6. Netflix
   7. Messenger
