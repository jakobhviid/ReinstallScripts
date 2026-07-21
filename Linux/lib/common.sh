# shellcheck shell=bash
# Logging helpers, y/N confirmation prompt, interactive numbered picker.
# Sourced by install-bazzite.sh and the Linux/justfile recipes.

# Bail fast if sourced on a non-Linux host. Without this, you'd see
# obscure errors (mapfile not found on Mac's bash 3.2, etc.) when the
# wrong directory's just recipes are run.
if [[ "$(uname)" != "Linux" ]]; then
    printf '\033[1;31m✗ Linux/justfile is for Linux. Detected: %s\033[0m\n' "$(uname)" >&2
    printf '  You probably want the Mac/ directory on this host.\n' >&2
    exit 1
fi

info()  { printf '\033[1;34m▸ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
err()   { printf '\033[1;31m✗ %s\033[0m\n' "$*"; }

# Drift-style output helpers (used by 'just drift' and similar).
# Bold section header with breathing room above.
section()    { printf '\n\033[1m%s\033[0m\n' "$*"; }
# Indented status lines: green ✓ / red ✗ followed by a label.
ok_line()    { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
fail_line()  { printf '  \033[1;31m✗\033[0m %s\n' "$*"; }
# Action item for Summary: cyan → + description, then command on next line.
# Usage: action_line "description of what this does" "the actual command"
action_line() { printf '  \033[1;36m→\033[0m %s\n    \033[2m%s\033[0m\n' "$1" "$2"; }

# file_drift <src> <dst> — status of a managed flat file vs its deployed copy.
# Echoes "" if identical, "missing" if dst is absent, else "<n> lines differ".
# Callers wrap it:  d=$(file_drift "$src" "$dst")
#   [[ -z "$d" ]] && ok_line "$label" || { fail_line "$label ($d)"; drift=1; }
file_drift() {
    [[ -f "$2" ]] || { echo "missing"; return; }
    diff -q "$1" "$2" >/dev/null 2>&1 && return
    echo "$(diff "$1" "$2" 2>/dev/null | grep -c '^[<>]') lines differ"
}

# ── Brewfile / package drift helpers (drift, reconcile, prune) ───────────────

# flatpak_extras <brewfile> <ignore-file> — installed flatpak app IDs that are
# neither declared in the Brewfile nor in the ignore list, one per line.
# Replaces the hand-rolled expected-list + nested membership loop with `comm`.
flatpak_extras() {
    command -v flatpak &>/dev/null || return 0
    local installed expected ignore=""
    installed=$(flatpak list --app --columns=application 2>/dev/null) || return 0
    [[ -n "$installed" ]] || return 0
    expected=$(grep -oE '^flatpak "[^"]+"' "$1" 2>/dev/null | sed -E 's/^flatpak "([^"]+)"/\1/')
    [[ -f "$2" ]] && ignore=$(grep -vE '^\s*#|^\s*$' "$2")
    comm -23 <(printf '%s\n' "$installed" | sort -u) \
             <(printf '%s\n%s\n' "$expected" "$ignore" | grep -v '^$' | sort -u)
}

# brewfile_missing <brewfile> — Brewfile entries NOT installed on this machine,
# one per line as: TYPE<TAB>NAME<TAB>RAWLINE (TYPE ∈ brew|cask|tap|flatpak|vscode).
# Callers use whichever fields they need (drift: "TYPE NAME"; reconcile: RAWLINE).
# brew/cask names match brew's short name (tap prefix stripped); vscode is
# case-insensitive; flatpak/vscode arms skip when the tool isn't installed.
brewfile_missing() {
    local bf="$1" casks="" formulae="" taps="" flatpaks="" vscode="" line name
    casks=$(brew list --cask 2>/dev/null || true)
    formulae=$(brew list --formula 2>/dev/null || true)
    taps=$(brew tap 2>/dev/null || true)
    command -v flatpak &>/dev/null && flatpaks=$(flatpak list --app --columns=application 2>/dev/null || true)
    command -v code    &>/dev/null && vscode=$(code --list-extensions 2>/dev/null || true)
    while IFS= read -r line; do
        case "$line" in
            'brew '*)    name=$(sed -E 's/^brew "([^"]+)".*/\1/' <<<"$line");    grep -qFx "${name##*/}" <<<"$formulae" || printf 'brew\t%s\t%s\n' "$name" "$line" ;;
            'cask '*)    name=$(sed -E 's/^cask "([^"]+)".*/\1/' <<<"$line");    grep -qFx "${name##*/}" <<<"$casks"    || printf 'cask\t%s\t%s\n' "$name" "$line" ;;
            'tap '*)     name=$(sed -E 's/^tap "([^"]+)".*/\1/' <<<"$line");     grep -qFx "$name"        <<<"$taps"     || printf 'tap\t%s\t%s\n' "$name" "$line" ;;
            'flatpak '*) name=$(sed -E 's/^flatpak "([^"]+)".*/\1/' <<<"$line"); [[ -n "$flatpaks" ]] && { grep -qFx "$name" <<<"$flatpaks" || printf 'flatpak\t%s\t%s\n' "$name" "$line"; } ;;
            'vscode '*)  name=$(sed -E 's/^vscode "([^"]+)".*/\1/' <<<"$line");  [[ -n "$vscode" ]] && { grep -qFix "$name" <<<"$vscode" || printf 'vscode\t%s\t%s\n' "$name" "$line"; } ;;
        esac
    done < <(grep -vE '^\s*#|^\s*$' "$bf")
}

# brew_cleanup_extras <brewfile> — formulae/casks/taps installed but not in the
# Brewfile, per `brew bundle cleanup` (dependency-aware: a kept entry's deps are
# NOT listed — which is why this can't be replaced by naive set subtraction).
# One token per line; callers type-tag against `brew list`.
brew_cleanup_extras() {
    brew bundle cleanup --file="$1" --formula --cask --tap 2>&1 \
        | sed -n '/^Would uninstall/,/^[A-Z]/p' \
        | grep -E '^[a-z0-9][a-z0-9._/-]*$' || true
}

# is_desktop — true on a graphical Bazzite desktop, false on any headless server
# whatever the distro (Fedora CoreOS eternium/nous, or an Ubuntu/Debian server).
# gnome-shell is the tell: every desktop has it, servers don't. Gates GUI-only /
# Bazzite-specific work (flatpak, GNOME extensions, .desktop overrides, image
# rebase) so install/update/drift run cleanly on both — and a server (which
# can't look like a desktop) is never rebased onto a bazzite image. Lives here
# (not install.sh) so `just drift`, which only sources common.sh, can use it too.
is_desktop() { command -v gnome-shell &>/dev/null; }

# confirm "Prompt" — default No. Returns 0 if user types y/Y (anything starting with y).
confirm() {
    local ans
    read -rp "$1 [y/N] " ans
    [[ "$ans" =~ ^[Yy] ]]
}

# pick_choice "Prompt: " "<default>" choice1 choice2 ... — print numbered
# menu to stderr, read selection from stdin, echo the chosen value to stdout.
# User may enter a number, an exact name, or a new name (echoed verbatim).
# If <default> is non-empty, hitting Enter on a blank line returns it; the
# prompt is annotated as "Prompt [default]: ". If <default> is empty and the
# user enters nothing, nothing is echoed (caller treats as "no selection").
pick_choice() {
    local prompt="$1"; shift
    local default="$1"; shift
    local -a choices=("$@")
    local n=${#choices[@]}
    # Declare iteration locals once — zsh leaks "var=val" to output when a
    # variable is re-declared local inside the same scope.
    local idx c choice
    {
        echo "Available:"
        idx=1
        for c in "${choices[@]}"; do
            printf '  %d) %s\n' "$idx" "$c"
            idx=$((idx + 1))
        done
        if [[ -n "$default" ]]; then
            printf '%s [%s]: ' "${prompt%: }" "$default"
        else
            printf '%s' "$prompt"
        fi
    } >&2
    read -r choice
    if [[ -z "$choice" && -n "$default" ]]; then
        echo "$default"
        return 0
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= n )); then
        # Walk to the choice-th element — bash arrays are 0-indexed, zsh's
        # are 1-indexed, so explicit iteration avoids the difference.
        idx=1
        for c in "${choices[@]}"; do
            if (( idx == choice )); then
                echo "$c"
                return 0
            fi
            idx=$((idx + 1))
        done
    fi
    if [[ -n "$choice" ]]; then
        echo "$choice"
    fi
}

# current_machine_name — short hostname, lowercased, ".local" stripped.
# Used by pick_machine to detect which Brewfile matches this box.
current_machine_name() {
    local n
    n=$(hostname -s 2>/dev/null || hostname)
    n="${n%.local}"
    echo "$n" | tr '[:upper:]' '[:lower:]'
}

# pick_machine "Prompt: " choice1 choice2 ... — wraps pick_choice for the
# common "pick a machine" flow. Prints "This machine: X" so the user can see
# what hostname the system reports. If that hostname matches one of the
# choices, it becomes the default (Enter to accept).
pick_machine() {
    local prompt="$1"; shift
    local -a choices=("$@")
    local host default=""
    host=$(current_machine_name)
    if [[ -n "$host" ]]; then
        local c
        for c in "${choices[@]}"; do
            [[ "$c" == "$host" ]] && default="$c" && break
        done
        echo "This machine: $host" >&2
    fi
    pick_choice "$prompt" "$default" "${choices[@]}"
}

# list_machines — machine names (brewfiles/Brewfile.* basenames minus the
# prefix), one per line. Relative path: recipes run from the platform dir.
list_machines() {
    ls brewfiles/Brewfile.* 2>/dev/null | xargs -n1 basename | sed 's/Brewfile\.//'
}

# resolve_machine "<prompt>" "<supplied>" — the machine-selection preamble every
# machine-scoped recipe used to inline. Echoes the resolved name to stdout;
# returns non-zero if none was chosen. Callers MUST use command substitution +
# `||` (a bare `exit` inside `$(…)` would only kill the subshell), e.g.:
#     machine=$(resolve_machine "Pick a machine: " "{{machine}}") \
#         || { warn "No machine selected, exiting."; exit 0; }
# Body is portable bash+zsh (while-read into array, no mapfile) — kept identical
# in Mac/lib/common.sh.
resolve_machine() {
    local prompt="$1" m="$2" mode="${3:-}"
    if [[ -z "$m" ]]; then
        local -a choices=()
        local line
        while IFS= read -r line; do [[ -n "$line" ]] && choices+=("$line"); done < <(list_machines)
        if [[ "$mode" == create ]]; then
            # New-file flows (backup, gnome-backup): default to THIS machine's
            # hostname even if it has no Brewfile/snapshot yet, so a bare Enter
            # creates the file for the current box instead of "no selection".
            local host; host=$(current_machine_name)
            [[ -n "$host" ]] && echo "This machine: $host" >&2
            m=$(pick_choice "$prompt" "$host" "${choices[@]}")
        else
            m=$(pick_machine "$prompt" "${choices[@]}")
        fi
    fi
    [[ -n "$m" ]] || return 1
    printf '%s\n' "$m"
}

# require_brewfile "<machine>" — abort (exit 1) unless brewfiles/Brewfile.<m>
# exists. Runs at recipe top level (not in a subshell), so the exit sticks.
require_brewfile() {
    [[ -f "brewfiles/Brewfile.$1" ]] || { err "brewfiles/Brewfile.$1 not found"; exit 1; }
}
