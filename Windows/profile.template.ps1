# ─── oh-my-posh prompt ────────────────────────────────────────────────────────
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/honukai.omp.json" | Invoke-Expression

# ─── posh-git ─────────────────────────────────────────────────────────────────
Import-Module posh-git

# ─── PSReadLine (autosuggestions, syntax highlighting, history search) ────────
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# ─── PSFzf (Ctrl+R history, Ctrl+T file finder, Tab completion) ──────────────
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }

# ─── fzf previews ────────────────────────────────────────────────────────────
$env:FZF_CTRL_T_OPTS = "--preview 'bat --color=always --line-range :200 {} 2>$null'"
$env:FZF_ALT_C_OPTS = "--preview 'dir {}'"

# ─── Zoxide (smart cd) ───────────────────────────────────────────────────────
Invoke-Expression (& { zoxide init powershell | Out-String })

# ─── Git aliases ──────────────────────────────────────────────────────────────
function gs  { git status }
function gp  { git pull }
function ga  { git add . }
function gc  { param([Parameter(ValueFromRemainingArguments)]$m) git commit -m ($m -join ' ') }
function gcp { param([Parameter(ValueFromRemainingArguments)]$m) git commit -am ($m -join ' '); git push }

# ─── Podman aliases ──────────────────────────────────────────────────────────
function pc { podman compose @args }
function pcu { podman compose up -d @args }
function pcd { podman compose down @args }
function pcl { podman compose ps @args }

# ─── eza aliases (modern ls) ─────────────────────────────────────────────────
function ls { eza @args }
function ll { eza -l --git @args }
function la { eza -la --git @args }
function lt { eza --tree --level=2 @args }

# ─── Local overrides (not tracked by git) ───────────────────────────────────
$localProfile = Join-Path (Split-Path $PROFILE) "profile.local.ps1"
if (Test-Path $localProfile) { . $localProfile }
