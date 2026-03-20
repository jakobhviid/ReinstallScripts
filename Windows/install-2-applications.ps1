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
winget install --id=VideoLAN.VLC -e --silent
winget install --id=dotPDN.PaintDotNet -e --silent
winget install --id=JGraph.Draw -e --silent
winget install --id=Plex.Plex -e --silent
winget install --id=Ookla.Speedtest.CLI -e --silent

# CLI tools (scoop)
scoop install git
git config --global user.name "Jakob Hviid, PhD"
git config --global user.email "jakob@hviid.phd"
git config --global pull.rebase true
git config --global core.sshcommand "C:/Windows/System32/OpenSSH/ssh.exe"

scoop install aria2 sudo
scoop bucket add extras
scoop bucket add specialized https://github.com/jakobhviid/scoop-specialized
scoop install grep nano vim make coreutils ssh-copy-id micro

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

./add-fonts.ps1