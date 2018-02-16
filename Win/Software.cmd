@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"

echo Installing Standard tools like chrome, adobe reader, java, 7zip etc.
choco install googlechrome -y
choco install lastpass -y
choco install adobereader -y
choco install jre8 -y
choco install 7zip.install -y
choco install vlc -y
choco install paint.net -y
choco install dropbox -y
choco install chocolateygui -y
choco install teamviewer -y
choco install sharex -y

choco install itunes -y
choco install spotify -y

echo Installing hardware related helper tools
choco install logitechgaming -y
choco install logitech-options -y
rem choco install setpoint -y

echo Installing Game Related Packages
choco install discord -y
choco install steam -y
choco install origin -y
choco install uplay -y
choco install geforce-experience -y
rem choco install geforce-game-ready-driver -y

echo Installing commandline tools
choco install curl -y
choco install nmap -y
choco install sudo -y

echo Installing Developer Tools
choco install golang -y
choco install jdk8 -y
REM choco install python -y
choco install filezilla -y
choco install putty.install -y
choco install git.install -y
choco install gitkraken -y
choco install visualstudiocode -y
choco install sqlitebrowser -y
choco install typescript -y
choco install wudt -y
REM dont install cygwin and min gw, install http://win-builds.org instead!
REM choco install cygwin -y
REM choco install mingw -y

choco install nodejs.install -y
choco install yarn -y
call npm install -g yo
call npm install -g bower
call npm install -g grunt-cli
REM call npm install -g yarn  - installed using choco instead
call npm install -g webpack


echo Installing Large Developer Tools Packages
REM choco install visualstudio2017community -y
choco install visualstudio2017enterprise -y
choco install visualstudio2017-workload-netweb -y
choco install visualstudio2017-workload-manageddesktop -y
choco install visualstudio2017-workload-data -y
choco install visualstudio2017-workload-netcoretools -y
choco install resharper -y
choco install sql-server-express -y
choco install sql-server-management-studio -y

echo Installing Office
REM choco install office365homepremium -y
