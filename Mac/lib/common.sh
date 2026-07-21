# shellcheck shell=bash
# Logging helpers + interactive menu picker.
# Sourced by Mac/justfile recipes.

# Bail fast if sourced on a non-macOS host. Without this, you'd see
# obscure errors (zsh-only syntax breaking on Linux, or the recipe
# silently doing macOS-specific things on the wrong OS).
if [[ "$(uname)" != "Darwin" ]]; then
    printf '\033[1;31m✗ Mac/justfile is for macOS. Detected: %s\033[0m\n' "$(uname)" >&2
    printf '  You probably want the Linux/ directory on this host.\n' >&2
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

# Trust the third-party Homebrew taps the fleet uses. Homebrew 5.2+ gates non-
# official taps behind explicit trust (~/.homebrew/trust.json); without it a
# `brew bundle` / `brew upgrade` / `brew install` touching one of those taps
# fails or is silently skipped. Reads the single shared list
# shared/brew-trusted-taps (one list for both platforms). TRUST ONLY — never
# `brew tap` here. Byte-identical to Linux/lib/install.sh's copy; keep in sync.
#   $1 — path to the shared/brew-trusted-taps list
trust_brew_taps() {
    command -v brew &>/dev/null || return 0
    local list="$1"
    [[ -f "$list" ]] || { warn "brew-trusted-taps list not found at $list — skipping trust"; return 0; }
    local -a taps=()
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"                       # strip comments
        line="${line//[[:space:]]/}"             # strip all whitespace
        [[ -n "$line" ]] && taps+=("$line")
    done < "$list"
    (( ${#taps[@]} )) || return 0
    info "Trusting Homebrew taps: ${taps[*]}"
    brew trust --tap "${taps[@]}" 2>/dev/null || true
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
# in Linux/lib/common.sh.
resolve_machine() {
    local prompt="$1" m="$2" mode="${3:-}"
    if [[ -z "$m" ]]; then
        local -a choices=()
        local line
        while IFS= read -r line; do [[ -n "$line" ]] && choices+=("$line"); done < <(list_machines)
        if [[ "$mode" == create ]]; then
            # New-file flows (backup): default to THIS machine's hostname even if
            # it has no Brewfile yet, so a bare Enter creates the file for the
            # current box instead of "no selection".
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

# deploy_file <src> <dst> — copy src→dst, backing up any differing existing dst
# to .bak first. Shared by the ghostty/opencode deploy recipes (mirrors the
# copy-with-backup loop in Linux/lib/config.sh).
deploy_file() {
    local src="$1" dst="$2"
    [[ -f "$src" ]] || { err "$src not found"; return 1; }
    mkdir -p "$(dirname "$dst")"
    if [[ -f "$dst" ]] && ! diff -q "$src" "$dst" >/dev/null 2>&1; then
        cp "$dst" "$dst.bak"
        info "Backed up existing $dst to $dst.bak"
    fi
    cp "$src" "$dst"
    ok "Deployed $dst"
}

# deploy_ssh_config <src> — deploy the managed SSH host config (src =
# shared/ssh-shared.conf) to ~/.ssh/config.d/shared.conf and bootstrap an
# Include into ~/.ssh/config once (leaving the user's Host */agent block
# alone). Mirrors run_config_ssh in Linux/lib/config.sh.
deploy_ssh_config() {
    local src="$1"
    [[ -f "$src" ]] || { warn "ssh-shared.conf not found at $src — skipping SSH config"; return 0; }
    info "Deploying managed SSH config"
    local ssh_dir="$HOME/.ssh" dropin_dir="$HOME/.ssh/config.d"
    local managed="$HOME/.ssh/config.d/shared.conf" cfg="$HOME/.ssh/config"
    mkdir -p "$dropin_dir"
    chmod 700 "$ssh_dir" "$dropin_dir" 2>/dev/null || true
    cp "$src" "$managed"
    chmod 600 "$managed"
    if [[ ! -f "$cfg" ]]; then
        printf '%s\n' "Include config.d/shared.conf" > "$cfg"
        chmod 600 "$cfg"
        info "Created ~/.ssh/config with Include for the managed drop-in"
    elif ! grep -qF 'config.d/shared.conf' "$cfg"; then
        cp "$cfg" "$cfg.bak"
        { printf '%s\n\n' "Include config.d/shared.conf"; cat "$cfg"; } > "$cfg.tmp"
        mv "$cfg.tmp" "$cfg"
        chmod 600 "$cfg"
        info "Prepended Include to ~/.ssh/config (backup at ~/.ssh/config.bak)"
        warn "Any existing manual Host eternium/nous/pve blocks are now redundant (managed wins) — safe to delete."
    fi
    ok "Managed SSH config deployed to $managed"
}

# ── Brewfile / package drift helpers (drift, reconcile, prune) ───────────────

# file_drift <src> <dst> — status of a managed flat file vs its deployed copy.
# Echoes "" if identical, "missing" if dst absent, else "<n> lines differ".
# Byte-identical to Linux/lib/common.sh's copy.
file_drift() {
    [[ -f "$2" ]] || { echo "missing"; return; }
    diff -q "$1" "$2" >/dev/null 2>&1 && return
    echo "$(diff "$1" "$2" 2>/dev/null | grep -c '^[<>]') lines differ"
}

# brew_cleanup_extras <brewfile> — formulae/casks/taps installed but not in the
# Brewfile, per `brew bundle cleanup` (dependency-aware: a kept entry's deps are
# NOT listed). One token per line; callers type-tag against `brew list`.
# Byte-identical to Linux/lib/common.sh's copy.
brew_cleanup_extras() {
    brew bundle cleanup --file="$1" --formula --cask --tap 2>&1 \
        | sed -n '/^Would uninstall/,/^[A-Z]/p' \
        | grep -E '^[a-z0-9][a-z0-9._/-]*$' || true
}

# brewfile_missing <brewfile> — Brewfile entries NOT installed on this machine,
# one per line as: TYPE<TAB>NAME<TAB>RAWLINE (TYPE ∈ brew|cask|tap|mas|vscode).
# Callers use whichever fields they need (drift: "TYPE NAME"; reconcile: RAWLINE,
# filtered to brew/cask/tap). mas NAME is "AppName (id)"; vscode is
# case-insensitive; mas/vscode arms skip when that tool isn't installed. This is
# the macOS sibling of the Linux copy (mas/vscode arms instead of flatpak).
brewfile_missing() {
    local bf="$1" casks="" formulae="" taps="" mas_ids="" vscode="" line name id
    casks=$(brew list --cask 2>/dev/null)
    formulae=$(brew list --formula 2>/dev/null)
    taps=$(brew tap 2>/dev/null)
    command -v mas  &>/dev/null && mas_ids=$(mas list 2>/dev/null | awk '{print $1}')
    command -v code &>/dev/null && vscode=$(code --list-extensions 2>/dev/null)
    while IFS= read -r line; do
        case "$line" in
            'brew '*)   name=$(sed -E 's/^brew "([^"]+)".*/\1/' <<<"$line");    grep -qFx "${name##*/}" <<<"$formulae" || printf 'brew\t%s\t%s\n' "$name" "$line" ;;
            'cask '*)   name=$(sed -E 's/^cask "([^"]+)".*/\1/' <<<"$line");    grep -qFx "${name##*/}" <<<"$casks"    || printf 'cask\t%s\t%s\n' "$name" "$line" ;;
            'tap '*)    name=$(sed -E 's/^tap "([^"]+)".*/\1/' <<<"$line");     grep -qFx "$name"        <<<"$taps"     || printf 'tap\t%s\t%s\n' "$name" "$line" ;;
            'mas '*)    name=$(sed -E 's/^mas "([^"]+)".*/\1/' <<<"$line"); id=$(sed -E 's/.*id: ([0-9]+).*/\1/' <<<"$line"); [[ -n "$mas_ids" ]] && { grep -qFx "$id" <<<"$mas_ids" || printf 'mas\t%s (%s)\t%s\n' "$name" "$id" "$line"; } ;;
            'vscode '*) name=$(sed -E 's/^vscode "([^"]+)".*/\1/' <<<"$line");  [[ -n "$vscode" ]] && { grep -qFix "$name" <<<"$vscode" || printf 'vscode\t%s\t%s\n' "$name" "$line"; } ;;
        esac
    done < <(grep -vE '^\s*#|^\s*$' "$bf")
}
