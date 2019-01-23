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
choco install filezilla -y
choco install putty.install -y
choco install git.install -y
choco install gitkraken -y
choco install visualstudiocode -y
choco install sqlitebrowser -y
choco install typescript -y
choco install wudt -y

REM Needed for LaTeX
echo Installing tools for LaTeX
choco install miktex -y
choco install synctex -y
choco install activeperl -y
choco install python -y
refreshenv
python -m pip install --upgrade pip
pip install distribute
pip install pygments

choco install nodejs.install -y
REM choco install yarn -y
REM call npm install -g yo
REM call npm install -g bower
REM call npm install -g grunt-cli
REM REM call npm install -g yarn  - installed using choco instead
REM call npm install -g webpack


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
