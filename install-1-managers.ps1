Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')