# MEMORY.md

Persistent project memory for ReinstallScripts — checked into git so every
Claude Code session in this repo starts with the same background.

## How Claude should use this file

- **Read it at the start of any non-trivial task here.** These notes aren't
  derivable from the code or git history.
- **When you learn something durable** (user preference, project decision,
  hard-won gotcha), edit this file. Do **not** use the harness auto-memory dir
  (`~/.claude/projects/.../memory/`) for repo-scoped memory — it doesn't travel
  between machines.
- **Don't store** what's derivable from reading the repo (code conventions,
  file paths, how a recipe is wired), ephemeral task state, or anything already
  in CLAUDE.md. Prefer the *why* and the *don't-do-X* over the mechanics.
- Update or delete an entry when it's wrong or outdated.

---

## User

**Jakob is the end-user, not the developer.** He relies on Claude to set up and
configure the tooling. Explanations should focus on what he can *do* (commands,
keybindings), not implementation/config internals. Concise and actionable.

---

## Feedback

### Keep explanations short and user-focused
Lead with what he'll experience, not how it works. Recommend tools in 1–2
sentences; save the config/setup detail for when he says "go ahead."

### Don't revert changes without being asked
Reporting a problem is not a request to remove the thing. Troubleshoot or ask
what he wants — don't undo work preemptively. (Origin: Claude yanked an eza
hyperlink flag the moment Jakob mentioned a visual glitch.)

### Only commit/push when explicitly asked
Never `git commit` or `git push` unless Jakob explicitly says so ("commit",
"push", etc.) — even when the change feels done. Leave the tree dirty and
report what changed; his commit cadence is his own. (Origin: "only make commits
when i ask you to.")

### Don't run destructive recipe steps while testing
When verifying a recipe that uninstalls, removes profiles, or mutates system
state, never let the destructive step actually fire. Pipe `n` to the prompt
(`echo n | just <recipe>`), or use a no-op dry-run (e.g. `brew bundle cleanup`
without `--force`). If there's no built-in confirmation, don't run it — reason
from the code. Always say plainly that nothing was changed. (Origin: "remember
not to actually remove stuff on my machine.")

### Don't propose repo changes from live-machine bugs without proving they reproduce fresh
Jakob's live machines carry migration residue (old paths, deprecated tools,
stale config). Most live breakage is leftovers, not script defects. Fix the
live machine and stop — unless you can show, by reading the install path, that
a *clean* install would hit the same thing. Otherwise flag the idea as
speculative and ask. (Incident: a stale `gpg.ssh.program=/opt/1Password/...`
from the old deb install; Claude fixed it live but then wanted to bake an
`environment.d/brew.conf` into `lib/config.sh` without checking a fresh install
even needs it. "Don't change it if it works, and we don't know if it does.")

### Policies are personal good-defaults, not enterprise lockdown
The Brave/macOS-profile policies apply *sensible defaults across Jakob's own
machines* — not company lockdown. ("Not about controlling a company, just good
defaults at home.") So: don't add a policy just because it's "stricter"; frame
as "turns X off by default, still toggleable"; never block Jakob from something
he'd reasonably want (DevTools, extension installs); it's fine to drop dead
policies (e.g. `SSLVersionMin`) as clutter.

### Verify Brave policy keys against the official ADMX
Before adding/trusting any `Brave*` policy key, confirm the exact spelling
exists in Brave's official templates
(`https://brave-browser-downloads.s3.brave.com/latest/policy_templates.zip`,
grep `windows/admx/brave.admx`) — not LLM memory or blog posts. Brave silently
ignores unknown keys and `brave://policy` shows a typo'd key as "OK", so that's
**not** proof it works — have Jakob spot-check `brave://settings`. (Incident:
`BraveDebounceEnabled` vs the real `BraveDebouncingEnabled` shipped broken on
all three platforms for a long time.)

### Universal shell settings → template; per-machine → `~/.zshrc`
A setting true on *every* machine is a default and belongs in
`{Mac,Linux}/assets/zshrc.template` (rendered to managed `~/.zshrc.image` by
`just zsh`). Only machine-specific things (work tokens, per-host paths, tool
installers like LM Studio's PATH) go in the user-owned `~/.zshrc`. So when drift
flags an extra line in `~/.zshrc.image`, ask "universal or per-machine?" and
move it into the template if universal — don't default to stripping it. ("We
use brew everywhere, even linux.") (`~/.zshrc.local` was the old per-machine
slot, decommissioned 2026-05.)

---

## Project

### `.desktop` override gotchas (Linux, `run_config_desktop_overrides`)
We rewrite launchers in `~/.local/share/applications/` (icons + some Exec/
WMClass). Three non-obvious traps:

- **ublue casks must be reset before a brew upgrade.** VS Code
  (`ublue-os/tap/visual-studio-code-linux`) and 1Password
  (`ublue-os/tap/1password-gui-linux`) deposit launchers we then edit; brew
  tracks those as cask artifacts, so a later upgrade/reinstall aborts
  ("modified artifact"). `reset_desktop_customized_casks` (`lib/install.sh`)
  `brew reinstall --force`s each cask in `DESKTOP_CUSTOMIZED_CASKS` **that's
  `brew outdated`** — before the upgrade in both `phase2_userspace` and `just
  update` — then the overrides re-apply. Add any new in-place-edited *brew*
  cask to that array (image/flatpak launchers don't need it).
- **Claude Desktop is `claude-desktop-unofficial`**, not `claude-desktop`
  (binary `/usr/bin/claude-desktop-unofficial`, WMClass `com.anthropic.Claude`).
  Don't "correct" the override back to `claude-desktop.desktop` — that path is
  gone from the image, so the override would silently skip. The function also
  deletes a stale `claude-desktop.desktop` we deployed under the old name.
- **Cider needs `StartupWMClass=cider`.** It's a Wayland app (`app_id=cider`);
  the image's `Cider.desktop` drops the line its own
  `/usr/lib/Cider/resources/Cider.desktop` declares, so GNOME can't bind the
  window to the launcher (separate, icon-less entry). The override's optional
  4th field (`name|src|icon|StartupWMClass`) sets it. `xprop` (XWayland-only)
  and GNOME `Eval` (unsafe-mode off) can't read the app_id — trust the app's
  bundled `.desktop`. Same 4th field fixes any future "separate window, no
  icon" app.

### Linux fleet has two roles, auto-detected via gnome-shell
Desktops (atlas, chronos-redux, kira) are Bazzite; **servers (eternium, nous)
are stock Fedora CoreOS** — no gnome-shell/flatpak/brew/gext/just. Role =
`is_desktop()` (`command -v gnome-shell`, `lib/install.sh`), **not** a per-
machine flag, and distro-agnostic (an Ubuntu/Debian server takes the same
headless path — the userspace tier has no Fedora assumptions). Misdetection is
safe by construction: a server can't look like a desktop, so it's never
cosign-trusted + rebased onto a bazzite image. On a server, `install-bazzite.sh`
skips Phase 1 and all GUI config, running only brew + zsh + Brewfile + opencode;
`just update`/`drift` skip the desktop pieces; `speaker-eq`/`gnome-*`/`ptyxis-*`/
`extensions-sync` early-exit. **Decision (2026-07): servers are userspace-only —
the installer never touches their OS image.** If a signed custom *server* image
ever exists, that's a new path; don't retrofit the desktop rebase. Each server
needs its own `Brewfile.<machine>`.

### Managed SSH config is shared; agent config is not
`shared/ssh-shared.conf` → `~/.ssh/config.d/shared.conf` (via `just ssh-config`
both platforms; Linux `run_config_ssh` in install too). `~/.ssh/config` gets an
`Include` prepended once, then is left alone.
- **Agent config (1Password `IdentityAgent`, `ForwardAgent`) is deliberately
  NOT managed** — stays in the user's own `Host *` block (differs per machine).
  Never add agent lines to the managed file.
- **Routing:** on-LAN (holds a `192.168.1.x` addr) → direct; off-LAN → internal
  hosts via the `eternium` jump (`hviid.cloud`, key-only). `Match … exec`
  blocks before the defaults; LAN test is portable (`ip` / `ifconfig` fallback).
  **Caveat:** the test is just "any 192.168.1.x", a common range — on another
  such LAN it false-positives. If it bites, probe eternium specifically
  (`nc -z -w1 192.168.1.4 22`). Verify with `ssh -G <host>`.
- Hosts + IPs are committed to a **public** repo deliberately: no secrets,
  private IPs non-routable, exposed host is key-only.

### Third-party brew taps must be trusted before every brew install/upgrade
Homebrew 5.2+ gates non-official taps behind `brew trust`
(`~/.homebrew/trust.json`); untrusted → install/upgrade/reinstall fails or is
silently skipped, on **both** platforms. Single explicit list
`shared/brew-trusted-taps` (`colindean/fonts-nonfree`, `joshmedeski/sesh`,
`ublue-os/tap`) — explicit, *not* derived from Brewfiles, because
`joshmedeski/sesh` (sesh's source) is referenced bare, not via a `tap "…"` line.
**Trust only — never `brew tap`.** `trust_brew_taps <list>` (duplicated
byte-for-byte in `Linux/lib/install.sh` + `Mac/lib/common.sh`, portable
bash+zsh) is called everywhere brew installs: install / update / install-missing
/ **zsh** (zsh installs `sesh` outside `brew bundle`, so it needs it too).

### `just drift` is the read-only sync checker — never make it interactive
`just drift <machine>` (both platforms) reports what differs between machine and
repo and ends with a summary of which recipes converge each item; it **never
changes state** (no "apply? [y/N]"). Built because the friction was *not knowing
whether/which recipe to run*, not running them. When adding a drift category on
one platform, mirror it on the other where applicable (some are platform-
specific: image rebase / 1Password / rpm-ostree = Linux; mobileconfig = Mac).
Deliberately **not** tracked (add only if worth the upkeep): Ptyxis dconf,
`.desktop` overrides + autostart, gext set, registered repos, PipeWire EQ,
PWAs/icons. Companion restore recipes (`gnome-restore`, `ptyxis-restore`)
overwrite live state behind a default-**no** `confirm()` prompt.

### `fzf --zsh` — keep the `source <(fzf --zsh) 2>/dev/null`
The `2>/dev/null` in both zshrc templates is load-bearing, **not** redundant.
`fzf --zsh` snapshots shell options via `setopt -o`, and `zle` (auto-managed in
interactive zsh) can't be set that way, so fzf prints `can't change option: zle`
to stderr twice on every startup — pushing the first prompt down ~2 rows. The
redirect silences it; keybindings still work. If a linter flags it, leave it. If
one day you need to see other output, use a targeted filter
(`2> >(grep -v "can't change option: zle" >&2)`) rather than dropping it.

### `LANG=en_GB.UTF-8` in both zshrc templates is deliberate — 24h clock
Don't "correct" to en_US/da_DK. opencode (a JS runtime) renders clock times from
the process locale via `LANG`/`LC_ALL` for the default `Intl` locale — **not**
`LC_TIME`, and not macOS's GUI 24h toggle (Cocoa-only). `en_GB` = 24h + English;
accepted side effect is DD/MM dates (`en_DK` would give ISO dates but dotted
times). opencode has no time-format config key — the env var is the only lever.

### Tmux theme should track Jakob's Gruvbox tweaks
Jakob tuned the Gruvbox palette in `shared/starship.toml` for readability
against white text. Keep tmux status-bar colors close to the Starship palette so
they feel cohesive (and check contrast).

### Mac `brave-debloat.mobileconfig` targets both macOS and iOS
Jakob runs Brave on iPhone + Mac and wants one hardened profile for both (both
consume Apple config profiles). Prefer policy keys valid on both platforms; call
out any desktop- or iOS-only key. (Verify names against Brave's
`policy_templates.zip`, per the ADMX rule above.)
