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

# ─── Lazygit alias (lz) ─────────────────────────────────────────────────────
function lz { lazygit @args }

# ─── Git repo overview (fetch + status for all repos in subdirs) ────────────
function lg {
    param([string]$Dir = ".")
    $repos = Get-ChildItem -Path $Dir -Directory | Where-Object { Test-Path "$($_.FullName)\.git" }
    if (-not $repos) { Write-Output "No git repos found."; return }
    $sshRepos = $repos | Where-Object { (git -C $_.FullName remote get-url origin 2>$null) -notmatch '^https://' }
    $jobs = $sshRepos | ForEach-Object { Start-Job -ArgumentList $_.FullName -ScriptBlock { param($r); git -C $r fetch --quiet 2>$null } }
    if ($jobs) { $jobs | Wait-Job | Remove-Job -Force }
    $esc = [char]27
    Write-Host ""
    Write-Host ("  {0,-25} {1,-14} {2}" -f "Repository", "Branch", "Status") -ForegroundColor White
    Write-Host ("  {0,-25} {1,-14} {2}" -f "─────────────────────────", "──────────────", "──────") -ForegroundColor DarkGray
    foreach ($repo in $repos) {
        $r = $repo.FullName
        $name = $repo.Name
        $branch = (git -C $r branch --show-current 2>$null)
        if (-not $branch) { $branch = "detached" }
        $url = git -C $r remote get-url origin 2>$null
        if ($url -match '^https://') {
            Write-Host ("  {0,-25} {1}[34m{2,-14}{1}[0m {1}[31mHTTPS — switch to SSH{1}[0m" -f $name, $esc, $branch)
            continue
        }
        $sync = "✓"; $color = "32"
        $hasUpstream = git -C $r rev-parse --abbrev-ref '@{upstream}' 2>$null
        if ($LASTEXITCODE -eq 0 -and $hasUpstream) {
            $counts = (git -C $r rev-list --left-right --count "HEAD...@{upstream}" 2>$null) -split '\s+'
            $ahead = [int]$counts[0]; $behind = [int]$counts[1]
            if ($ahead -gt 0 -and $behind -gt 0) { $sync = "↑$ahead ↓$behind"; $color = "33" }
            elseif ($ahead -gt 0) { $sync = "↑$ahead"; $color = "33" }
            elseif ($behind -gt 0) { $sync = "↓$behind"; $color = "31" }
        } else {
            $sync = "—"; $color = "37"
        }
        $porcelain = git -C $r status --porcelain 2>$null
        $staged = 0; $modified = 0; $untracked = 0
        if ($porcelain) {
            $lines = $porcelain -split "`n"
            $staged = ($lines | Where-Object { $_ -match '^[MADRC]' }).Count
            $modified = ($lines | Where-Object { $_ -match '^.[MD]' }).Count
            $untracked = ($lines | Where-Object { $_ -match '^\?\?' }).Count
        }
        $changes = ""
        if ($staged -gt 0) { $changes += " $esc[32m+$staged$esc[0m" }
        if ($modified -gt 0) { $changes += " $esc[33m!$modified$esc[0m" }
        if ($untracked -gt 0) { $changes += " $esc[34m?$untracked$esc[0m" }
        Write-Host ("  {0,-25} {1}[34m{2,-14}{1}[0m {1}[{3}m{4}{1}[0m{5}" -f $name, $esc, $branch, $color, $sync, $changes)
    }
    Write-Host ""
}
function lgp {
    param([string]$Dir = ".")
    $repos = Get-ChildItem -Path $Dir -Directory | Where-Object { Test-Path "$($_.FullName)\.git" }
    if (-not $repos) { Write-Output "No git repos found."; return }
    Write-Host ""
    Write-Host "  Fetching..." -ForegroundColor DarkGray
    $sshRepos = $repos | Where-Object { (git -C $_.FullName remote get-url origin 2>$null) -notmatch '^https://' }
    $jobs = $sshRepos | ForEach-Object { Start-Job -ArgumentList $_.FullName -ScriptBlock { param($r); git -C $r fetch --quiet 2>$null } }
    if ($jobs) { $jobs | Wait-Job | Remove-Job -Force }
    $esc = [char]27
    foreach ($repo in $sshRepos) {
        $r = $repo.FullName
        $name = $repo.Name
        if (git -C $r status --porcelain 2>$null) { continue }
        $hasUpstream = git -C $r rev-parse --abbrev-ref '@{upstream}' 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $hasUpstream) { continue }
        $counts = (git -C $r rev-list --left-right --count "HEAD...@{upstream}" 2>$null) -split '\s+'
        $ahead = [int]$counts[0]; $behind = [int]$counts[1]
        if ($behind -gt 0 -and $ahead -eq 0) {
            Write-Host "  $esc[32m↓$esc[0m $name"
            git -C $r pull --quiet 2>$null
        }
        if ($ahead -gt 0 -and $behind -eq 0) {
            Write-Host "  $esc[32m↑$esc[0m $name"
            git -C $r push --quiet 2>$null
        }
    }
    lg $Dir
}

# ─── eza aliases (modern ls) ─────────────────────────────────────────────────
function ls { eza --icons --hyperlink --group-directories-first @args }
function ll { eza -l --git --icons --hyperlink --group-directories-first --time-style=relative @args }
function la { eza -la --git --icons --hyperlink --group-directories-first --time-style=relative @args }
function lt { eza --tree --level=2 --icons --hyperlink --group-directories-first @args }

# ─── Local overrides (not tracked by git) ───────────────────────────────────
$localProfile = Join-Path (Split-Path $PROFILE) "profile.local.ps1"
if (Test-Path $localProfile) { . $localProfile }
