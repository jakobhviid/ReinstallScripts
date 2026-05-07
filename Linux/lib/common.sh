# shellcheck shell=bash
# Logging helpers, y/N confirmation prompt, interactive numbered picker.
# Sourced by install-bazzite.sh and the Linux/justfile recipes.

info()  { printf '\033[1;34m▸ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
err()   { printf '\033[1;31m✗ %s\033[0m\n' "$*"; }

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
