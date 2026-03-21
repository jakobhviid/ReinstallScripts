# ─── Prompt (Starship) ────────────────────────────────────────────────────────
Invoke-Expression (&starship init powershell)

# ─── PSReadLine (autosuggestions, syntax highlighting, history search) ────────
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# ─── PSFzf (Ctrl+R history, Ctrl+T file finder, Tab completion) ──────────────
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    if (Get-Command Invoke-FzfTabCompletion -ErrorAction SilentlyContinue) {
        Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
    }
}

# ─── fzf previews ────────────────────────────────────────────────────────────
$env:FZF_CTRL_T_OPTS = '--preview "bat --color=always --line-range :200 {} 2>NUL"'
$env:FZF_ALT_C_OPTS = '--preview "dir {}"'

# ─── Zoxide (smart cd) ───────────────────────────────────────────────────────
Invoke-Expression (& { zoxide init powershell --cmd cd | Out-String })

# ─── Git aliases ──────────────────────────────────────────────────────────────
Remove-Item Alias:gc -Force -ErrorAction SilentlyContinue
function gs  { git status }
function gp  { git pull }
function gpp { git push }
function ga  { git add . }
function gc  {
    param([Parameter(ValueFromRemainingArguments)]$m)
    if (-not $m) { Write-Error "Commit message required"; return }
    git commit -m ($m -join ' ')
}
function gcp {
    param([Parameter(ValueFromRemainingArguments)]$m)
    if (-not $m) { Write-Error "Commit message required"; return }
    git commit -am ($m -join ' ')
    if ($LASTEXITCODE -eq 0) { git push }
}

# ─── Podman aliases ──────────────────────────────────────────────────────────
function pc { podman compose @args }
function pcu { podman compose up -d @args }
function pcd { podman compose down @args }
function pcl { podman compose ps @args }

# ─── eza aliases (modern ls) ─────────────────────────────────────────────────
function ls { eza --icons --group-directories-first @args }
function ll { eza -l --git --icons --group-directories-first --time-style=relative @args }
function la { eza -la --git --icons --group-directories-first --time-style=relative @args }
function lt { eza --tree --level=2 --icons --group-directories-first @args }

# ─── Local overrides (not tracked by git) ───────────────────────────────────
$localProfile = Join-Path (Split-Path $PROFILE) "profile.local.ps1"
if (Test-Path $localProfile) { . $localProfile }
