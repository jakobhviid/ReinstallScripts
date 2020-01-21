# scoop install 7zip
scoop install 7zip
appget install steam

# Copying games install script
Copy-Item .\steamcmd.txt "C:\Program Files (x86)\Steam\steamcmd.txt"

# Change Dir to Steam
Set-Location "C:\Program Files (x86)\Steam\"
Invoke-WebRequest https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip -o steamcmd.zip 

# unzipping steamcmd.exe
7z x .\steamcmd.zip

# Deleating steamcmd.zip
Remove-Item -Force .\steamcmd.zip

steamcmd +runscript steamcmd.txt 