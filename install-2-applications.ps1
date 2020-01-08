scoop install git
git config --global user.name "Jakob Hviid"
git config --global user.email "jakobhviid1982@gmail.com"

scoop install aria2 sudo
scoop bucket add extras
scoop bucket add java
scoop install curl grep nano vim make say tar sudo micro coreutils git tidy oraclejre8 vlc 7zip paint.net vscode gitkraken filezilla sqlitebrowser putty anaconda3 nodejs python go caprine sharpkeys nssm draw.io ssh-copy-id perl terminus plex-player

# Installing Visual Studio Code Sync Extension and the themes
code --install-extension shan.code-settings-sync
code --install-extension pkief.material-icon-theme
code --install-extension equinusocio.vsc-material-theme


regedit /s ./supportfiles/FixGitKraken.reg
regedit /s ./supportfiles/DisableNetworkDriveWarning.reg

choco feature enable -n=allowGlobalConfirmation
choco install synctex

Set-Location ~\Downloads\
Invoke-WebRequest https://dl.appget.net/appget/appget.setup.exe -o appget.exe 
./appget.exe /sp- /silent /norestart

appget install teams
appget install handbrake
appget install teamviewer
appget install spotify