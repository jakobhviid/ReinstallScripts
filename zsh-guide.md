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

Zoxide learns which directories you visit and lets you jump to them with partial names.

```sh
z dev              # jumps to ~/Developer (or best match from history)
z scripts          # jumps to the most frequently visited dir matching "scripts"
z dev scripts      # matches directories containing both "dev" and "scripts"
zi                 # interactive mode — fuzzy pick from all known directories
```

Zoxide ranks by **frequency** (how often) and **recency** (how recently). The more you visit a directory, the higher it ranks.

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
| `Alt+C`  | Fuzzy browse subdirectories and cd into the selected one |

**Inside any fzf picker:**

- Type to filter results
- `Enter` to select
- `Esc` or `Ctrl+C` to cancel
- Arrow keys or `Ctrl+J`/`Ctrl+K` to navigate

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

Reminds you when you type a command that has an alias defined. If you've set up:

```sh
alias gss='git status'
```

And then type `git status`, you'll see:

```
Found existing alias for "git status". You can use: "gss"
```

Helps you build muscle memory for your own aliases.

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
| `HIST_IGNORE_DUPS` | Duplicate consecutive commands are stored only once |
| `HIST_IGNORE_SPACE` | Commands starting with a space are not saved to history (useful for sensitive commands) |
| `HISTSIZE=10000` | 10,000 commands kept in memory |
| `SAVEHIST=10000` | 10,000 commands saved to `~/.zsh_history` |

**Privacy tip:** Prefix a command with a space to keep it out of history:

```sh
 export SECRET_KEY=abc123    # note the leading space — not saved
```

---

## Quick Reference

| What you want | How to do it |
|---------------|-------------|
| Jump to a directory | `z <partial-name>` |
| Browse and pick a directory | `zi` or `Alt+C` |
| Enter a directory without cd | Just type its name |
| Search command history | `Ctrl+R` |
| Find a file | `Ctrl+T` |
| See git branch in prompt | It's always there |
| Check if a command is valid | Look at the color (green = valid) |
| Accept an autosuggestion | `Right arrow` |
| Accept one word of suggestion | `Ctrl+Right arrow` |
| Reconfigure prompt theme | `p10k configure` |
| Hide a command from history | Prefix with a space |
