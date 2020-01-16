Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')

Set-Location ~\Downloads\
Invoke-WebRequest https://dl.appget.net/appget/appget.setup.exe -o appget.exe 
./appget.exe /sp- /silent /norestart


Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

Write-Output 'Please reboot for applications to register, and then run "install-2-applications.ps1"'
