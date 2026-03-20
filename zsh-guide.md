# Zsh Setup Guide

A guide to the plugins and tools installed by the setup scripts. Everything is managed via Homebrew and works identically on Linux (Bazzite) and macOS.

---

## Prompt: Powerlevel10k

Your terminal prompt shows useful context at a glance:

- **Left side:** current directory + git branch/status
- **Right side:** last command duration + timestamp
- **Second line:** `>` prompt character (green = last command succeeded, red = failed)

**Reconfigure anytime:**

```sh
p10k configure
```

---

## Navigation

### AUTO_CD

Type a directory name to enter it — no `cd` needed.

```sh
Developer          # same as: cd Developer
..                 # same as: cd ..
../..              # same as: cd ../..
```

### Zoxide (smart cd)

Zoxide replaces `cd` with a smarter version. Regular `cd` behavior works as normal (`cd ..`, `cd ./folder`, `cd -`), but you can also jump to any previously visited directory by typing partial names.

```sh
cd dev             # jumps to ~/Developer (or best match from history)
cd scripts         # jumps to the most frequently visited dir matching "scripts"
cd dev scripts     # matches directories containing both "dev" and "scripts"
cd ../..           # regular cd still works as expected
```

Zoxide ranks by **frequency** (how often) and **recency** (how recently). The more you visit a directory, the higher it ranks.

### cdi (interactive mode)

`cdi` opens an fzf-powered fuzzy picker of all directories zoxide knows about. You can type to filter, arrow through results, and press Enter to jump there. It's the best way to navigate when you can't remember the exact name — just type any fragment and pick from the matches.

**Seed directories you care about:**

```sh
zoxide add ~/Developer
zoxide add ~/Documents
zoxide add ~/Downloads
```

**List known directories:**

```sh
zoxide query --list
```

---

## Fuzzy Finding: fzf

fzf provides fuzzy search everywhere. Three keybindings are active:

| Shortcut | What it does |
|----------|-------------|
| `Ctrl+R` | Fuzzy search through command history |
| `Ctrl+T` | Fuzzy find a file and insert its path at the cursor |
| `Alt+C`  | Fuzzy browse subdirectories and cd into the selected one (see note below) |

> **macOS note:** `Alt+C` won't work by default because macOS uses Option to type special characters (e.g. `ç`). In iTerm2, go to Preferences → Profiles → Keys → General and set "Left Option key" to **Esc+**. In Terminal.app, check "Use Option as Meta key" in Profiles → Keyboard.

**Inside any fzf picker:**

- Type to filter results
- `Enter` to select
- `Esc` or `Ctrl+C` to cancel
- Arrow keys or `Ctrl+J`/`Ctrl+K` to navigate

### fzf previews

`Ctrl+T` and `Alt+C` show inline previews as you arrow through results:

- **Ctrl+T** shows file contents (syntax-highlighted via `bat`)
- **Alt+C** shows directory listings

### fzf-tab

Replaces the default tab completion menu with fzf. When you press `Tab` and there are multiple matches, you get a fuzzy-searchable list instead of a static menu.

```sh
git checkout f<Tab>     # fuzzy pick from branches starting with f
cd ~/Dev<Tab>           # fuzzy pick from matching directories
kill <Tab>              # fuzzy pick from running processes
```

Works with every command that has tab completions — git, docker, podman, npm, systemctl, etc.

---

## Autosuggestions

As you type, zsh shows a faded suggestion based on your command history. The suggestion appears inline to the right of your cursor.

| Action | What it does |
|--------|-------------|
| `Right arrow` or `End` | Accept the full suggestion |
| `Ctrl+Right arrow` | Accept the next word only |
| Keep typing | Ignore the suggestion |

The more you use your shell, the better the suggestions get.

---

## Syntax Highlighting

Commands are colored as you type:

| Color | Meaning |
|-------|---------|
| **Green** | Valid command (exists in PATH) |
| **Red** | Invalid command (typo or not installed) |
| **Underlined** | Valid file path |
| **Yellow** | Built-in command |

You see errors before you press Enter.

---

## History Substring Search

Press `Up`/`Down` arrow keys to search history by what you've already typed.

```sh
git c    # type this, then press Up
         # cycles through: git commit, git checkout, git cherry-pick, etc.
```

Regular `Up`/`Down` (with empty prompt) cycles through all history as usual.

---

## Autopair

Automatically closes brackets, quotes, and parentheses as you type:

| You type | You get |
|----------|---------|
| `(` | `()` with cursor between |
| `"` | `""` with cursor between |
| `{` | `{}` with cursor between |
| `[` | `[]` with cursor between |

Pressing the closing character when already at one skips over it instead of doubling. Backspace on an opening character deletes the pair.

---

## You Should Use

Reminds you when you type a command that has an alias defined. For example, if you type `git status`, you'll see:

```
Found existing alias for "git status". You can use: "gs"
```

Helps you build muscle memory for your own aliases.

---

## eza (modern ls)

`ls`, `ll`, `la`, and `lt` are aliased to `eza`, a modern replacement for `ls` with color and git awareness.

| Command | What it does |
|---------|-------------|
| `ls` | Colored file listing |
| `ll` | Long format with git status column |
| `la` | Long format including hidden files |
| `lt` | Tree view (2 levels deep) |

The git column in `ll`/`la` shows per-file status (`M` modified, `N` new, etc.) when inside a git repo.

---

## Case-Insensitive Completion

Tab completion ignores case. Typing `developer<Tab>` matches `Developer`, `dev<Tab>` matches `Developer`, etc. Works everywhere — file paths, commands, arguments.

---

## Completions

The `zsh-completions` package adds tab completion support for hundreds of tools including:

- **Containers:** podman, docker, docker-compose
- **Git:** git, gh (GitHub CLI)
- **Package managers:** brew, npm, flatpak, rpm-ostree
- **System:** systemctl, journalctl
- **Dev tools:** kubectl, helm, terraform, cargo, go

Just press `Tab` after any command or flag to see available options.

---

## History Settings

Your shell history is configured with:

| Setting | What it does |
|---------|-------------|
| `SHARE_HISTORY` | History is shared across all open terminal sessions |
| `HIST_IGNORE_ALL_DUPS` | Duplicate commands are removed from history (keeps the latest) |
| `HIST_IGNORE_SPACE` | Commands starting with a space are not saved to history (useful for sensitive commands) |
| `HIST_REDUCE_BLANKS` | Trims extra whitespace from saved commands |
| `HIST_VERIFY` | Shows expanded history command before running (safety net for `!!`) |
| `HISTSIZE=50000` | 50,000 commands kept in memory |
| `SAVEHIST=50000` | 50,000 commands saved to `~/.zsh_history` |

**Privacy tip:** Prefix a command with a space to keep it out of history:

```sh
 export SECRET_KEY=abc123    # note the leading space — not saved
```

---

## Git Aliases

| Alias | Command |
|-------|---------|
| `gs` | `git status` |
| `gp` | `git pull` |
| `ga` | `git add .` |
| `gc message` | `git commit -m "message"` |
| `gcp message` | `git commit -am "message" && git push` |

`gcp` stages tracked modified files, commits, and pushes in one step. New (untracked) files need `ga` first.

---

## Podman Aliases

| Alias | Command |
|-------|---------|
| `pc` | `podman compose` |
| `pcu` | `podman compose up -d` |
| `pcd` | `podman compose down` |
| `pcl` | `podman compose ps` |

---

## Local Overrides

Per-machine customizations go in `~/.zshrc.local`. This file is sourced at the end of `.zshrc` if it exists, and is not overwritten by `just zsh`. Use it for machine-specific env vars, aliases, or tool config.

---

## Quick Reference

| What you want | How to do it |
|---------------|-------------|
| Jump to a directory | `cd <partial-name>` |
| Browse and pick a directory | `cdi` or `Alt+C` |
| Enter a directory without cd | Just type its name |
| Search command history | `Ctrl+R` |
| Find a file | `Ctrl+T` |
| See git branch in prompt | It's always there |
| List files with git status | `ll` |
| List files as a tree | `lt` |
| Check if a command is valid | Look at the color (green = valid) |
| Accept an autosuggestion | `Right arrow` |
| Accept one word of suggestion | `Ctrl+Right arrow` |
| Git status | `gs` |
| Git add, commit, push | `ga && gcp message` |
| Reconfigure prompt theme | `p10k configure` |
| Per-machine zsh overrides | `~/.zshrc.local` |
| Hide a command from history | Prefix with a space |
