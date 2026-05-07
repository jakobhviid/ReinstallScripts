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
