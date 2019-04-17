echo off
cd c:\

echo Installing chocolatey
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
echo Enabling Global Confirmation
choco feature enable -n=allowGlobalConfirmation

echo Installing Standard tools like chrome, adobe reader, java, 7zip etc.
choco install 1password
choco install googlechrome
choco install adobereader
choco install jre8
choco install 7zip.install
choco install vlc
choco install paint.net
choco install teamviewer
choco install spotify

echo Installing hardware related helper tools
choco install logitechgaming
choco install logitech-options
rem choco install setpoint

echo Installing Game Related Packages
choco install discord
choco install steam
choco install origin
choco install uplay
choco install epicgameslauncher
choco install geforce-experience

echo Installing commandline tools
choco install curl
choco install nmap
choco install sudo

echo Installing Developer Tools
choco install vscode
choco install git.install
choco install gitkraken
choco install filezilla
choco install golang
choco install jdk8
choco install putty.install
choco install visualstudiocode
choco install sqlitebrowser
choco install typescript
choco install wudt

REM Needed for LaTeX
echo Installing tools for LaTeX
REM choco install miktex
choco install synctex
REM choco install activeperl
choco install strawberryperl
refreshenv
cpan -f -i Unicode::GCString
cpan -f -i YAML::Tiny
cpan -f -i Log::Dispatch::File
cpan -f -i Log::Log4perl
choco install python
refreshenv
python -m pip install --upgrade pip
pip install distribute
pip install pygments
choco install anaconda3
choco install nodejs.install

REM Generating SSH keys for git etc.
cd %userprofile%/.ssh
ssh-keygen -t rsa -b 4096 -C "jakob@hviidnet.com"

REM Installing Windows System Features
powershell Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux


echo remember to install tex live - downloading to the downloads folder now:
curl http://mirrors.dotsrc.org/ctan/systems/texlive/tlnet/install-tl-windows.exe --output C:\Users\%USERNAME%\Downloads\install-tl-windows.exe

echo remember to install Office 365 too.