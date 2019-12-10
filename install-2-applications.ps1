scoop bucket add extras
scoop bucket add java
scoop install aria2 sudo
scoop install curl grep nano vim make say tar sudo micro coreutils git tidy 7zip oraclejre8 vlc 7zip paint.net handbrake teamviewer discord vscode gitkraken filezilla sqlitebrowser putty dotnet-sdk anaconda3 nodejs python go

regedit /s ./supportfiles/FixGitKraken.reg
regedit /s ./supportfiles/DisableNetworkDriveWarning.reg

choco feature enable -n=allowGlobalConfirmation
choco install synctex
choco install activeperl

cd ~\Downloads\
wget https://dl.appget.net/appget/appget.setup.exe -o appget.exe 
./appget.exe /sp- /silent /norestart
