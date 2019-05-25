# Reinstall Scripts

Mac script use [Homebrew](https://brew.sh/), while Windows uses [Chocolatey](https://chocolatey.org/).

## Missing items from install script

1. [Live Tex](https://www.tug.org/texlive/acquire-netinstall.html)
2. [Office 365 Home](https://account.microsoft.com/services/office/install)
3. [Visual Studio Community 2019](https://visualstudio.microsoft.com/downloads/)
4. [draw.io desktop application](https://about.draw.io/integrations/#integrations_offline)
5. Windows Store Apps
   1. 1Password
   2. Spotify
   3. Microsoft To-do
   4. Wunderlist
   5. Signal
   6. OneNote
   7. Ubuntu (for WSFL)
   8. Remote Desktop
   9. Termius
   10. Plex
   11. Netflix
   
## Remember scoop!!!
get scoop from [here](https://scoop.sh/), and install by using powershell:

```powershell
Set-ExecutionPolicy RemoteSigned -scope CurrentUser
iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
```

Install my most common packages with these commands:
```powershell
scoop install aria2 
scoop install curl grep nano touch vim make
```

## Instructions for VS Code Setup

1. Install sync command.
2. Run sync.download command from palete.
3. Paste access token: "9d87c1263d8133c86a7acb6be4e8f0ebb4f5fa52".
4. Paste Gist id: "dac237d22d72a0305708292b111c62c5".
