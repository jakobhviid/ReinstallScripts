scoop install git
scoop install aria2 sudo
scoop bucket add extras
scoop bucket add java
scoop install curl grep nano vim make say tar sudo micro coreutils git tidy oraclejre8 vlc 7zip paint.net handbrake teamviewer discord vscode gitkraken filezilla sqlitebrowser putty dotnet-sdk anaconda3 nodejs python go caprine sharpkeys

regedit /s ./supportfiles/FixGitKraken.reg
regedit /s ./supportfiles/DisableNetworkDriveWarning.reg

choco feature enable -n=allowGlobalConfirmation
choco install synctex
choco install activeperl

cd ~\Downloads\
wget https://dl.appget.net/appget/appget.setup.exe -o appget.exe 
./appget.exe /sp- /silent /norestart

appget install teams
appget install handbrake
