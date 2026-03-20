#!/usr/bin/env bash
set -uo pipefail

# Ubuntu Server — Zsh setup script
# Installs Zsh, Homebrew, and the full plugin/config stack.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { printf '\033[1;34m▸ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
err()   { printf '\033[1;31m✗ %s\033[0m\n' "$*"; }

# ─── Install Zsh ──────────────────────────────────────────────────────────────

if ! command -v zsh &>/dev/null; then
    info "Installing Zsh"
    sudo apt update && sudo apt install -y zsh
fi

# ─── Install Homebrew ─────────────────────────────────────────────────────────

if ! command -v brew &>/dev/null; then
    info "Installing Homebrew"
    sudo apt install -y build-essential curl git
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -d /home/linuxbrew/.linuxbrew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        if ! grep -q 'linuxbrew' ~/.bashrc 2>/dev/null; then
            printf '\neval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"\n' >> ~/.bashrc
        fi
    fi
fi

# ─── Install Zsh plugins via Homebrew ─────────────────────────────────────────

info "Installing Zsh plugins via Homebrew"
brew install \
    romkatv/powerlevel10k/powerlevel10k \
    zsh-autosuggestions \
    zsh-syntax-highlighting \
    zsh-completions \
    zsh-history-substring-search \
    zsh-autopair \
    zsh-you-should-use \
    bat \
    eza \
    fzf \
    fzf-tab \
    zoxide

# ─── Generate .zshrc ─────────────────────────────────────────────────────────

if [[ -f ~/.zshrc ]]; then
    cp ~/.zshrc ~/.zshrc.bak
    info "Backed up existing .zshrc to .zshrc.bak"
fi

brew_prefix="$(brew --prefix)"

cat > ~/.zshrc <<ZSHRC
# ─── Homebrew ─────────────────────────────────────────────────────────────────
if [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
elif [[ -d /opt/homebrew ]]; then
    eval "\$(/opt/homebrew/bin/brew shellenv zsh)"
fi

# ─── Powerlevel10k instant prompt ─────────────────────────────────────────────
if [[ -r "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh" ]]; then
    source "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh"
fi

# ─── Prompt ───────────────────────────────────────────────────────────────────
source $brew_prefix/share/powerlevel10k/powerlevel10k.zsh-theme

# ─── Plugins ──────────────────────────────────────────────────────────────────
source $brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $brew_prefix/share/zsh-history-substring-search/zsh-history-substring-search.zsh
source $brew_prefix/share/zsh-autopair/autopair.zsh
source $brew_prefix/share/zsh-you-should-use/you-should-use.plugin.zsh
source $brew_prefix/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh

# ─── fzf shell integration (Ctrl+R history, Ctrl+T file finder, Alt+C cd) ────
source <(fzf --zsh)

# ─── fzf previews ────────────────────────────────────────────────────────────
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --line-range :200 {} 2>/dev/null || head -200 {}'"
export FZF_ALT_C_OPTS="--preview 'ls -la {}'"

# ─── Completions ──────────────────────────────────────────────────────────────
FPATH=$brew_prefix/share/zsh-completions:$brew_prefix/share/zsh/site-functions:\$FPATH
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# ─── History ──────────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt AUTO_CD
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

# ─── Git aliases ──────────────────────────────────────────────────────────────
alias gs='git status'
alias gp='git pull'
alias ga='git add .'
gc() { git commit -m "\$*" }
gcp() { git commit -am "\$*" && git push }

# ─── Podman aliases ──────────────────────────────────────────────────────────
alias pc='podman compose'
alias pcu='podman compose up -d'
alias pcd='podman compose down'
alias pcl='podman compose ps'

# ─── eza aliases (modern ls) ─────────────────────────────────────────────────
alias ls='eza'
alias ll='eza -l --git'
alias la='eza -la --git'
alias lt='eza --tree --level=2'

# ─── Key bindings ─────────────────────────────────────────────────────────────
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# ─── Zoxide (smart cd) ───────────────────────────────────────────────────────
eval "\$(zoxide init zsh)"

# ─── Local bins ──────────────────────────────────────────────────────────────
[[ -d "\$HOME/.local/bin" ]] && export PATH="\$HOME/.local/bin:\$PATH"
[[ -d "\$HOME/.local/npm/bin" ]] && export PATH="\$HOME/.local/npm/bin:\$PATH"

# ─── NVM (if installed) ──────────────────────────────────────────────────────
if [[ -d "\$HOME/.nvm" ]]; then
    export NVM_DIR="\$HOME/.nvm"
    [ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
fi

# ─── Powerlevel10k config ────────────────────────────────────────────────────
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
ZSHRC

# ─── Deploy p10k config ──────────────────────────────────────────────────────

cp "$SCRIPT_DIR/p10k.zsh" ~/.p10k.zsh

# ─── Set Zsh as default shell ────────────────────────────────────────────────

if [[ "$(basename "$SHELL")" != "zsh" ]]; then
    info "Setting Zsh as default shell"
    chsh -s "$(which zsh)"
fi

info "Configuring Git"
git config --global user.name "Jakob Hviid, PhD"
git config --global user.email "jakob@hviid.phd"
git config --global pull.rebase true

ok "Zsh setup complete — restart your terminal (or log out and back in) to activate"
