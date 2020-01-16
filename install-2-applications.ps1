appget install chrome
appget install 1password
appget install teams
appget install handbrake
appget install teamviewer
appget install spotify
appget install du-meter
appget install slack
appget install discord
appget install 7zip

scoop install git
git config --global user.name "Jakob Hviid"
git config --global user.email "jakobhviid1982@gmail.com"

scoop install aria2 sudo
scoop bucket add extras
scoop bucket add java
scoop bucket add specialized https://github.com/jakobhviid/scoop-specialized
scoop install curl grep nano vim make say tar sudo micro coreutils git tidy oraclejre8 vlc 7zip paint.net vscode gitkraken filezilla sqlitebrowser putty anaconda3 nodejs python go sharpkeys nssm draw.io ssh-copy-id perl terminus plex-player latex

# Installing Visual Studio Code Sync Extension and the themes
code --install-extension shan.code-settings-sync
code --install-extension pkief.material-icon-theme
code --install-extension equinusocio.vsc-material-theme

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