# Applications (winget)
winget install --id=Google.Chrome -e --silent
winget install --id=AgileBits.1Password -e --silent
winget install --id=Logitech.Options -e --silent
winget install --id=Microsoft.Teams -e --silent
winget install --id=HandBrake.HandBrake -e --silent
winget install --id=TeamViewer.TeamViewer -e --silent
winget install --id=Spotify.Spotify -e --silent
winget install --id=SlackTechnologies.Slack -e --silent
winget install --id=Discord.Discord -e --silent
winget install --id=7zip.7zip -e --silent
winget install --id=Microsoft.VisualStudioCode -e --silent
winget install --id=QL-Win.QuickLook -e --silent

scoop install git
git config --global user.name "Jakob Hviid"
git config --global user.email "jakobhviid1982@gmail.com"
git config --global core.sshcommand "C:/Windows/System32/OpenSSH/ssh.exe"

scoop install aria2 sudo
scoop bucket add extras
scoop bucket add java
scoop bucket add specialized https://github.com/jakobhviid/scoop-specialized
scoop install curl grep nano vim make say tar sudo coreutils tidy oraclejre8 vlc paint.net filezilla sqlitebrowser sharpkeys nssm draw.io ssh-copy-id perl terminus plex-player latex speedtest-cli win-acme micro ueli

# Installing Visual Studio Code extensions
code --install-extension pkief.material-icon-theme

# oh-my-posh v3+ setup
Import-Module posh-git
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/paradox.omp.json" | Invoke-Expression

Add-Content $profile 'Import-Module posh-git'
Add-Content $profile 'oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/honukai.omp.json" | Invoke-Expression'

# Adding registry fixes
New-Item -Path "Registry::HKEY_CLASSES_ROOT\Directory\Background\shell\GitKraken\command" -Force | Out-Null
Set-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\Directory\Background\shell\GitKraken\command" -Name '(Default)' -Value "`"$env:LOCALAPPDATA\gitkraken\update.exe`" --processStart=gitkraken.exe --process-start-args=`"-p %V`""
regedit /s ./supportfiles/DisableNetworkDriveWarning.reg

# Instaling pygments for Latex highlighting
python -m pip install --upgrade pip
pip install pygments

# Installing cpan packages for Latex
cpan -f -i Unicode::GCString
cpan -f -i YAML::Tiny
cpan -f -i Log::Dispatch::File
cpan -f -i Log::Log4perl

# extra apps for scientific work
scoop install protege

./add-fonts.ps1