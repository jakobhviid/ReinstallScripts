# Windows bootstrap — run this once as admin to get started
# After this, use `just` from the Windows/ directory for everything else

Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
scoop install git just

Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

Write-Output ""
Write-Output "Bootstrap complete. Reboot, then from the Windows/ directory run:"
Write-Output "  just install    # Install everything"
Write-Output "  just zsh        # Re-sync shell config (anytime)"
Write-Output "  just games      # Game launchers (optional)"
