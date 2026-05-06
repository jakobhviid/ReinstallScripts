# shellcheck shell=bash
# Logging helpers + interactive menu picker.
# Sourced by Mac/justfile recipes.

info()  { printf '\033[1;34m▸ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
err()   { printf '\033[1;31m✗ %s\033[0m\n' "$*"; }

# pick_choice "Prompt: " choice1 choice2 ... — print numbered menu to stderr,
# read selection from stdin, echo the chosen value to stdout. User may enter
# a number, an exact name, or a new name (echoed verbatim). Empty input echoes
# nothing — caller treats that as "no selection".
pick_choice() {
    local prompt="$1"; shift
    local -a choices=("$@")
    {
        echo "Available:"
        local i
        for i in "${!choices[@]}"; do
            printf '  %d) %s\n' "$((i + 1))" "${choices[$i]}"
        done
        printf '%s' "$prompt"
    } >&2
    local choice
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#choices[@]} )); then
        echo "${choices[$((choice - 1))]}"
    elif [[ -n "$choice" ]]; then
        echo "$choice"
    fi
}
