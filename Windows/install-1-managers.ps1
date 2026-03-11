Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')

# Installing oh-my-posh (v3+)
winget install --id=JanDeDobbeleer.OhMyPosh -e --silent
Install-Module -Name posh-git

Get-Service -Name ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent

# install WSL features
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

Write-Output 'Please reboot for applications to register, and then run "install-2-applications.ps1"'