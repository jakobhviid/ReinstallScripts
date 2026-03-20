# Windows bootstrap — run this once as admin to get started
# After this, use `just` from the Windows/ directory for everything else

# Require admin
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires admin. Right-click your terminal and select 'Run as Administrator'."
    exit 1
}

Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

# TLS 1.2 (required for HTTPS downloads on fresh machines)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Scoop (-RunAsAdmin since this script runs elevated)
iex "& {$(irm get.scoop.sh)} -RunAsAdmin"
scoop install git just

# ssh-agent
$sshAgent = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
if ($sshAgent) {
    Set-Service -Name ssh-agent -StartupType Automatic
    Start-Service ssh-agent
} else {
    Write-Warning "ssh-agent service not found. Install OpenSSH via Settings > Apps > Optional Features."
}

# WSL
wsl --install --no-launch

Write-Output ""
Write-Output "Bootstrap complete. Reboot, then from the Windows/ directory run:"
Write-Output "  just install    # Install everything"
Write-Output "  just zsh        # Re-sync shell config (anytime)"
Write-Output "  just games      # Game launchers (optional)"
