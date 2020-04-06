appget install chrome
appget install 1password
appget install logitech-options
appget install logitech-unifying-software
appget install teams
appget install handbrake
appget install teamviewer
appget install spotify
appget install slack
appget install discord
appget install 7zip
appget install visual-studio-code
appget install xmeters

scoop install git
git config --global user.name "Jakob Hviid"
git config --global user.email "jakobhviid1982@gmail.com"

scoop install aria2 sudo
scoop bucket add extras
scoop bucket add java
scoop bucket add nerd-fonts
scoop bucket add specialized https://github.com/jakobhviid/scoop-specialized
scoop install curl grep nano vim make say tar sudo coreutils git tidy oraclejre8 vlc 7zip paint.net gitkraken filezilla sqlitebrowser putty nodejs python sharpkeys nssm draw.io ssh-copy-id perl terminus plex-player latex speedtest-cli win-acme
# Removed: busybox anaconda3 go micro

# Installing Visual Studio Code Sync Extension and the themes
code --install-extension shan.code-settings-sync
code --install-extension pkief.material-icon-theme
code --install-extension equinusocio.vsc-material-theme

# Bling for powershell console
Import-Module posh-git
Import-Module oh-my-posh
Set-Theme Paradox

Add-Content $profile "Import-Module posh-git"
Add-Content $profile "Import-Module oh-my-posh"
Add-Content $profile "Set-Theme Honukai"

# Adding registry fixes
regedit /s ./supportfiles/FixGitKraken.reg
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