# MEMORY.md

Persistent project memory for the ReinstallScripts repo. This file is the
**single source of truth** for context that should follow the code across
machines — checked into git so any Claude Code session in this repo gets the
same background.

## How Claude should use this file

- **At the start of any non-trivial task in this repo, read this file.** The
  notes here are not derivable from the code or git history.
- **When learning something durable about the user, the project, or how to
  work in it, edit this file directly.** Do **not** write to the harness's
  auto-memory directory (`~/.claude/projects/.../memory/`) for repo-scoped
  memories — entries there don't transport between machines.
- **Memory types** mirror the auto-memory schema:
  - **user** — facts about Jakob's role, expertise, preferences
  - **feedback** — guidance on *how* to work (rules, do's and don'ts)
  - **project** — durable facts about ongoing work, decisions, motivations
  - **reference** — pointers to external systems
- **Don't store** code conventions, file paths, or anything derivable from
  reading the repo. Don't store ephemeral task state. Don't duplicate what's
  already in CLAUDE.md.
- When a memory turns out to be wrong or outdated, update or remove it.

---

## User

### Jakob is the end-user, not the developer

Jakob is the user of these machines, not a developer. He relies on Claude to
set up and configure tooling. Explanations should focus on what he can *do*
(the commands, the keybindings) not on implementation details, config syntax,
or plugin internals. Keep recommendations concise and actionable.

---

## Feedback

### Keep explanations short and user-focused

Don't dump full config files, plugin tables, or implementation details. Lead
with what he'll experience, not how it works under the hood.

**Why:** Jakob is the end-user, not the person writing the configs — Claude
handles setup. Too much detail is overwhelming.

**How to apply:** When recommending tools, explain what they do in 1–2
sentences. Save the config/setup work for when he says "go ahead and set it
up."

### Don't revert changes without being asked

Don't assume the user wants something removed just because they report an
issue with it. Ask what they'd like to do instead of jumping to a revert.

**Why:** Jakob reported a visual issue with eza hyperlinks and Claude
immediately removed the flag without being asked to.

**How to apply:** When the user reports a problem, help troubleshoot or ask
what they want — don't undo work preemptively.

### Verify Brave policy keys against the official ADMX

Before adding or trusting a Brave enterprise policy key, verify the exact
spelling against Brave's official policy templates.

**Why:** A typo in `BraveDebounceEnabled` (the actual key is
`BraveDebouncingEnabled`) was silently shipped across all three platforms
(Mac, Linux, Windows) for a long time. Brave silently ignores unknown keys,
and `brave://policy` shows the typo'd key as "OK" because Chromium just
accepts JSON it doesn't recognize. The "Auto-redirect tracking URLs" toggle
stayed off despite our config supposedly enabling it.

**How to apply:**
- Source of truth:
  `https://brave-browser-downloads.s3.brave.com/latest/policy_templates.zip`
  (extract and grep `windows/admx/brave.admx`).
- When adding any new `Brave*` policy key, confirm it appears in that ADMX
  file — don't trust LLM training data, blog posts, or even Brave community
  threads for exact spelling.
- After deploying, ask the user to spot-check the actual setting in
  `brave://settings` — `brave://policy` showing "OK" is **not** sufficient
  evidence the key is correct.

### Policies are personal good-defaults, not enterprise lockdown

The policy files in this repo (Brave policies, macOS configuration profiles,
etc.) are about applying **sensible defaults across Jakob's own machines** —
they are not enterprise/company lockdown configs.

**Why:** Jakob explicitly framed it: "This is not about controlling a
company, but just having good defaults at home on all machines."

**How to apply:**
- Don't suggest adding policies just because they're "more locked down" or
  "stricter." The bar is *useful default for me*, not *maximally
  restrictive*.
- It's fine to remove dead/deprecated policies (like `SSLVersionMin`) even
  when their value is technically valid — if the policy isn't doing
  anything, it's just clutter.
- When suggesting new policies, frame them as "this turns X off by default;
  you can still toggle it" rather than "this prevents users from doing X."
- Don't add policies that would block Jakob himself from doing something he
  might reasonably want to do (e.g. disabling DevTools, blocking extension
  installs, force-installing extensions).

### Universal tool settings go in the template, per-machine in ~/.zshrc

When a shell setting applies to a tool that's used on every machine, it
belongs in the template (`Mac/assets/zshrc.template`,
`Linux/assets/zshrc.template`) — rendered into `~/.zshrc.image` by
`just zsh`. Per-machine settings go in the user-owned `~/.zshrc` (which
sources `~/.zshrc.image`), not in a separate override file.

**Why:** Jakob said: "Scripts don't care about local sometimes. but we use
brew everywhere, even linux." A setting that's true on every machine is a
default, and defaults belong in the source-of-truth so every machine gets
them. Per-machine settings are anything only true on one machine.

(Historical note: an `~/.zshrc.local` file was previously used as the
per-machine slot, but was decommissioned 2026-05 when Mac aligned with
Linux's two-file model and `~/.zshrc` itself became the user-owned slot.)

**How to apply:**
- When drift surfaces a "harmless" extra line in `~/.zshrc.image`, ask: is
  this universal (every machine should have it) or per-machine (only here)?
  - **Universal** → bring it into the template; the next `just zsh`
    re-renders it everywhere. Examples: brew env vars (`HOMEBREW_NO_*`),
    aliases, default editors, locale settings.
  - **Per-machine** → it belongs in `~/.zshrc` directly (work tokens,
    machine-specific paths, hostname-conditional logic, tool installers
    like LM Studio's PATH export).
- Don't default to "move it out of the template" when drift is detected.
  The whole point of the templated approach is that good defaults are shared.

### Don't actually run destructive recipes on Jakob's machine while testing

When verifying a recipe that uninstalls packages, removes profiles, modifies system state, or otherwise has a destructive blast radius, never let it actually execute the destructive step. Pipe `n` to the confirmation prompt, or use a dry-run path that doesn't touch state.

**Why:** Jakob said: "remember not to actually remove stuff on my machine." Test runs can quietly turn into real work-loss if a confirmation prompt is bypassed or a flag flipped. He wants verification, not state changes, when the task is "build this recipe and confirm it works."

**How to apply:**
- For any recipe that calls `brew uninstall`, `brew bundle cleanup --force`, `dconf load`, `chsh`, `defaults write`, profile install/remove, `rm`, `git reset`, etc., the test invocation must end without the destructive line firing.
- Pipe `n` to confirmations (`echo n | just <recipe>`). Verify the recipe printed the dry-run preview and exited at the prompt.
- If the recipe has no built-in confirmation, do not run it. Read the code, reason about the output, run an isolated dry-run (e.g. `brew bundle cleanup` without `--force` to preview).
- Surface in the response that nothing was actually changed, so Jakob can verify.

### Don't propose repo changes from live-machine bugs without verifying they reproduce on a fresh install

When something is broken on Jakob's live machine, fix it on the live machine and stop. Don't propose baking the fix into `install-bazzite.sh` / `Linux/lib/` / justfiles "so a future reinstall gets it" unless you've actually verified the same problem would occur on a clean install.

**Why:** Jakob's live machines accumulate residue from migrations (old install paths, deprecated tools, stale config from previous package managers). Most live-machine breakage is migration leftovers, not script defects. Specific incident: a stale `gpg.ssh.program=/opt/1Password/op-ssh-sign` was left over from when 1Password was installed via deb/rpm; after migrating to the brew cask the path was wrong. Claude correctly fixed the live config but then proposed adding `~/.config/environment.d/brew.conf` to `Linux/lib/config.sh` — without ever checking whether GUI apps on a fresh install actually fail to find brew binaries. Jakob: "don't change it if it works, and we don't know if it does."

**How to apply:**
- Default: fix the live machine, report what changed, stop.
- If you think the install scripts should also be updated, first show the evidence — read the install path, point to the gap, explain why a fresh install would hit the same issue.
- If you can't show that evidence, flag the suggestion as speculative and ask whether it's worth verifying before doing the work.

### Only commit when explicitly asked

Never create git commits unless Jakob explicitly asks for one ("commit",
"make commits", "commit this", etc.).

**Why:** Jakob said: "only make commits when i ask you to." This applies
even when changes feel "done" or at a natural stopping point. He wants
control over when work gets boxed up — partly to review it himself, partly
because his commit cadence is his own choice.

**How to apply:**
- After finishing a chunk of work, leave the working tree dirty and report
  what changed. Don't commit "to tidy up."
- Don't commit even if it seems obvious that the change is shippable.
- Don't push without explicit instruction either (general default but worth
  the same care).
- The only acceptable trigger is an explicit "commit" / "make commits" /
  "git commit" from Jakob.

---

## Project

### ublue desktop-customized casks are reset before any brew upgrade

`run_config_desktop_overrides` (in `Linux/lib/config.sh`) rewrites the `.desktop`
launchers deposited into `~/.local/share/applications/` by two ublue casks —
`ublue-os/tap/visual-studio-code-linux` (`code.desktop`) and
`ublue-os/tap/1password-gui-linux` (`1password.desktop`) — changing `Icon=`
(and `Exec=` for 1Password). These aren't cosmetic-only edits; they're
deliberate.

**Why the force step exists:** brew tracks that launcher as a cask artifact.
Once we've modified it, a later `brew bundle` upgrade/reinstall of the cask
aborts with a "modified artifact — use `--force`" error. Fixed by
`reset_desktop_customized_casks` in `Linux/lib/install.sh`, called *before*
brew's upgrade step in two places — `phase2_userspace` (before `brew bundle`)
and the `just update` recipe (before `brew upgrade`). It `brew reinstall
--cask --force`s each cask in `DESKTOP_CUSTOMIZED_CASKS` **that `brew outdated
--cask` reports as outdated**, resetting the launcher to pristine so the
pending upgrade lands cleanly. `run_config_desktop_overrides` (and
`run_config_1password` for the Exec=) re-apply the edits afterward.

**Only outdated casks are reset**, not every installed one — an up-to-date
cask (or a `:latest`/`auto_updates` cask brew won't touch without `--greedy`)
is exactly one brew won't try to upgrade, so it can't trip the guard and
needs no reset. This keeps `just update` from re-downloading VS Code /
1Password on every run when nothing's changed.

**How to apply:**
- Reset runs *before* the brew upgrade step (not after) so brew never sees a
  modified artifact — keep that ordering in both call sites.
- The `brew outdated --cask` guard also means fresh machines skip it (nothing
  installed → nothing outdated), so `brew bundle` installs those casks clean
  and there's nothing to reset.
- If a new override in `run_config_desktop_overrides` targets a launcher that a
  brew cask (not the image / not a flatpak) deposits, add that cask's
  tap-qualified token to `DESKTOP_CUSTOMIZED_CASKS`. Image-baked
  (`/usr/share/applications/…`) and flatpak (`/var/lib/flatpak/…`) sources
  don't need it — brew doesn't manage those.

### Claude Desktop's launcher is `claude-desktop-unofficial.desktop`, not `claude-desktop.desktop`

The bazzite-custom image ships Claude Desktop as **`claude-desktop-unofficial`**:
launcher `/usr/share/applications/claude-desktop-unofficial.desktop`, binary
`/usr/bin/claude-desktop-unofficial`, `StartupWMClass=com.anthropic.Claude`.
An older image used the name `claude-desktop` (binary `/usr/bin/claude-desktop`);
that name is **gone** on the current image.

**How to apply:**
- The `run_config_desktop_overrides` row for Claude targets
  `claude-desktop-unofficial.desktop`. Don't "correct" it back to
  `claude-desktop.desktop` — that source path doesn't exist on the image, so
  the override would silently skip (dead `src`) and no icon would ever apply.
- The function also removes a stale user-level `claude-desktop.desktop` **iff**
  its `Icon=` sits under our icon dir (i.e. one we deployed under the old name)
  — leftover on machines migrated from the old image, where its
  `Exec=/usr/bin/claude-desktop` now points at an absent binary. That's why the
  icon looked "never applied": the working menu entry was the untouched
  `-unofficial` one while our override re-skinned the broken duplicate.
- If a future image renames it again, update the row's name + src together and
  re-check the cleanup guard.

### Linux fleet has two roles, auto-detected via gnome-shell (no manual flag)

Not every Linux machine is a Bazzite desktop. **eternium and nous are stock
Fedora CoreOS servers** (`VARIANT_ID=coreos`, booted on
`quay.io/fedora/fedora-coreos:stable` — *not* a jakobhviid custom image), with
rpm-ostree/bootc/zsh/podman/docker but **no gnome-shell, flatpak, brew, gext,
or just**. atlas / chronos-redux / kira are the desktops. **Servers may be any
distro** — the userspace tier (brew + zsh + opencode) is distro-agnostic, so
Ubuntu/Debian servers are handled by the exact same headless path as FCOS; the
detection keys on gnome-shell, not on the distro.

**Role is detected from the OS, not a per-machine flag:** `is_desktop()`
(`Linux/lib/install.sh`) = `command -v gnome-shell`. Desktops have it (even
stock Bazzite pre-rebase); FCOS servers never do. The same check is inlined in
the `just update` / `just drift` recipes. **The misdetection failure mode is
deliberately safe:** a server can't look like a desktop, so we can never
wrongly cosign-trust + rebase a server onto a bazzite image.

**How it's wired:**
- `install-bazzite.sh` `main()` → on a server, **skip Phase 1 entirely** (no
  rebase/cosign — FCOS self-manages its image via zincati/rpm-ostree) and run a
  reduced Phase 2: brew + zsh + Brewfile + opencode. `phase2_userspace` gates
  RPM layer, GNOME extensions, and every GUI `run_config_*` behind the role;
  `run_config_opencode` stays universal (servers run opencode too).
- `just update` and `just drift` skip flatpak / gext / desktop checks on a server.
- `just speaker-eq`, `gnome-backup/restore`, `ptyxis-backup/restore`,
  `extensions-sync` early-exit with a "desktop-only" message on a server.

**Servers are userspace-only by decision** (2026-07): the installer never
touches a server's OS image, regardless of distro. If a signed custom *server*
image is ever built, that's a new Phase-1-like path — don't retrofit the desktop
rebase onto servers. Entry point on a fresh server is `./install-bazzite.sh
<machine>` (just isn't present yet; the script bootstraps it via the
distro-agnostic bootstrap.sh), then `just update` works like on desktops. Each
server needs its own `brewfiles/Brewfile.<machine>` (eternium + nous exist).

### Cider needs `StartupWMClass=cider` in its .desktop (image drops it)

Cider (v2 "Genten", image-baked at `/usr/lib/Cider/Cider`, symlinked
`/usr/bin/Cider`) is a **Wayland** Electron app whose window `app_id` is
**`cider`** (lowercase). Its own reference launcher
`/usr/lib/Cider/resources/Cider.desktop` declares `StartupWMClass=cider`, but
the image-deployed `/usr/share/applications/Cider.desktop` **drops that line**.
Without it GNOME can't bind the running Wayland window to the launcher → the app
opens as a separate, generic-icon taskbar entry (our custom icon doesn't stick).

**Fix:** `run_config_desktop_overrides` now supports an optional 4th field on an
override row (`name|src|icon|StartupWMClass`); Cider's row sets `cider`, so the
deployed override always carries `StartupWMClass=cider`. `xprop` can't see this
(Wayland-native window, not XWayland) and GNOME Shell `Eval` is blocked
(unsafe-mode off) — the authoritative WM_CLASS comes from Cider's bundled
`resources/Cider.desktop`. After the fix, **quit and relaunch Cider** for GNOME
to re-associate the window. If another app shows the same "separate window, no
icon" symptom, it's the same cause — add its `app_id` as the 4th field.

### Managed SSH host config is shared (Mac + Linux), agent config is not

`shared/ssh-shared.conf` is the managed SSH **host inventory + home/away routing**,
deployed verbatim to `~/.ssh/config.d/shared.conf` (0600) by `run_config_ssh`
(Linux `lib/config.sh`, also `just ssh-config`) and the Mac `just ssh-config`
recipe. `~/.ssh/config` is bootstrapped **once** — `Include config.d/shared.conf`
prepended at the top (with a `.bak`) — then left alone.

- **Agent config is deliberately NOT managed.** The user's own `~/.ssh/config`
  `Host *` block (1Password `IdentityAgent`, `ForwardAgent`) stays put; the
  managed file never mentions agents (it differs per machine — desktops use the
  1Password agent, servers use a forwarded one). Don't add agent lines to
  `ssh-shared.conf`.
- **Routing:** on the home LAN (machine holds a `192.168.1.x` addr) → connect
  DIRECT to internal IPs; off-LAN → internal hosts go through the `eternium`
  jump (`hviid.cloud`, key-only). Done with `Match … exec "<lan test>"` blocks
  placed BEFORE the default `Host` blocks (ssh keeps the first value per option;
  on-LAN blocks set `HostName 192.168.1.4` for eternium and `ProxyJump none` for
  the rest). Verify with `ssh -G <host>` (prints resolved config, no connect).
- **LAN test is portable:** `{ ip -4 -o addr show || ifconfig; } | grep -qF
  'inet 192.168.1.'` — `ip` on Linux (desktops + servers), `ifconfig` fallback
  on macOS. Runs on servers too (no agent/GUI assumptions), so it's universal in
  install-bazzite.sh Phase 2 (outside the desktop gate, like opencode).
- Hosts: eternium (jump, `hviid.cloud`/192.168.1.4), helios (.2), nous (.6),
  pve (.5), all `User jakob`. Committed to a **public** repo — deliberate: no
  secrets, private IPs are non-routable, and the exposed host is key-only.
- `just update` on **both** platforms re-deploys this file (and re-templates
  `~/.zshrc.image` via `just zsh`). Mac gained a `just update` for this (brew
  upgrade + zsh + ghostty + opencode + ssh-config; no flatpak/rpm/GUI).

### `fzf --zsh` stderr suppression in both zshrc templates

Line in both `Mac/assets/zshrc.template` and `Linux/assets/zshrc.template`:

```zsh
source <(fzf --zsh) 2>/dev/null
```

The `2>/dev/null` looks redundant but is load-bearing — **do not remove it.**

**Why:** `fzf --zsh` (verified on fzf 0.72.0) emits zsh code that snapshots
all shell options via `setopt -o $opt`. The `zle` option can't be set this
way (it's auto-managed by zsh in interactive mode), so zsh prints
`(eval):1: can't change option: zle` to stderr — twice, because fzf does the
snapshot in both its `key-bindings.zsh` and `completion.zsh` blocks. Without
redirection, those two stderr lines fire on every shell startup, pushing the
first prompt down by ~2 rows. Combined with Starship's `add_newline = true`,
the cumulative top gap was noticeable in both Ghostty and iTerm2 on Mac.

**Verified:**
- `2>/dev/null` silences both errors.
- fzf key bindings remain functional: `^R` (history), `^T` (file finder),
  `^[c` / Alt+C (cd), Tab completion. Confirmed via
  `zsh --no-rcs -ic 'source <(fzf --zsh) 2>/dev/null; bindkey | grep fzf'`.

**How to apply:**
- When future Claude (or a linter) sees the apparently-redundant
  `2>/dev/null`, leave it.
- If fzf upstream stops emitting the `setopt -o zle` (the issue is fzf's, not
  ours), the redirect becomes a no-op but still does no harm. No need to
  remove it preemptively.
- If a different tool's output starts showing up that we *do* want to see,
  this redirect would hide it — in that case, switch to a more targeted
  approach (e.g. `2> >(grep -v "can't change option: zle" >&2)`) rather than
  reverting.

### `LANG=en_GB.UTF-8` in both zshrc templates is deliberate — 24h clock

Both `Mac/assets/zshrc.template` and `Linux/assets/zshrc.template` export
`LANG=en_GB.UTF-8`. **Do not "correct" this to `en_US`/`en_DK`/`da_DK`** thinking
it looks wrong for a Danish user.

**Why:** opencode (and other locale-aware CLI apps) render clock times from the
process locale, not macOS's GUI "24-hour time" toggle — that toggle is Cocoa-only
and CLI tools never see it. `en_US` = 12h ("1:29 pm"); `en_GB` = 24h ("13:29")
while keeping English messages. JS runtimes (opencode is one) only honour
`LANG`/`LC_ALL` for the default `Intl` locale, **not** `LC_TIME` — so `LC_TIME`
alone does nothing; it has to be `LANG`. Jakob explicitly chose global/"everywhere"
over an opencode-only alias.

**How to apply:**
- Leave `en_GB.UTF-8`. The accepted side effect is DD/MM/YYYY date order in CLI
  tools. If Jakob ever dislikes that, `en_DK.UTF-8` gives 24h + ISO dates but
  dot-separated times (`13.29`).
- opencode has **no** config key for time format (checked `config.json` +
  `tui.json` schemas + TUI source). The env var is the only lever. Don't go
  looking for an opencode setting.

### Tmux theme should track Jakob's Gruvbox tweaks for Starship

Jakob modified the Gruvbox color palette in `shared/starship.toml` so white
text is easier to read. When setting up tmux theming, keep the tmux status
bar colors close to the Starship palette so they feel cohesive.

**Why:** Readability concern — the default Gruvbox tones didn't contrast
enough with white text.

**How to apply:** When picking or configuring a tmux Gruvbox theme, verify
the text contrast matches what Jakob is used to from Starship.

### Mac brave-debloat.mobileconfig targets both iOS and macOS

The Apple-side Brave policy (`Mac/assets/brave-debloat.mobileconfig`) is
intended to apply to **both Brave for macOS and Brave for iOS**
simultaneously, since both consume Apple configuration profiles (MDM-style
payloads).

**Why:** Jakob runs Brave on both iPhone and Mac and wants the same
hardened privacy posture on both, deployed from one profile.

**How to apply:**
- When changing or adding policy keys in `brave-debloat.mobileconfig`,
  prefer keys that exist on both platforms. If a key is desktop-only or
  iOS-only, call it out before merging.
- When the Linux/Windows JSON policies change, the Mac `.mobileconfig` must
  change too (existing CLAUDE.md rule), and the iOS implication is
  automatic — same file.
- Verify policy names against Brave's official `policy_templates.zip` before
  adding.

### `just drift` is the read-only sync checker; never make it interactive

`just drift <machine>` is the canonical "what's out of sync between this
machine and the repo" recipe on Mac and Linux. It is **read-only** by
design — each detected drift category prints what differs and ends with a
summary table of which existing recipes converge it. Running the recipes is
the user's choice; drift never changes state.

**Why:** Built when Jakob noted the friction wasn't running recipes, it was
*not knowing whether to run them or which one*. Especially after weeks of
not touching a machine, then noticing it differs from another. `just
cleanup` was deleted in the same change — it was a subset of drift's
brewfile section.

**How to apply:**
- **Linux drift sections** (in order): image rebase (booted on
  `bazzite-{,nvidia-}custom:latest`), zsh (`~/.zshrc` sources
  `~/.zshrc.image`, `~/.zshrc.image` matches rendered template,
  `~/.config/starship.toml`, `~/.tmux.conf`), default shell, git identity,
  brave (policy file at `/etc/brave/policies/managed/brave-policy.json`),
  rpm-ostree layered packages, brewfile (missing + extras with flatpak
  ignore-list applied), gnome shell (filtered live state vs
  `assets/gnome/shell.<machine>.dconf`), 1password integration (group
  membership, `custom_allowed_browsers` perms+entries, Zen NMH manifest,
  Alt+Shift+2 keybinding command path).
- **Mac drift sections**: zsh (`~/.zshrc` matches rendered template,
  starship, tmux), default shell, git identity, brave (mobileconfig keys
  vs Managed Preferences plist), brewfile.
- **Two-file zsh model on Linux only** (`.zshrc` user-owned bootstrap +
  `.zshrc.image` managed) — Mac still uses single-file `~/.zshrc`. Drift
  reflects this.
- **Cross-platform parity matters:** when adding a new drift category on
  one platform, add it on the other if applicable. Same shape, same summary
  table format. Some sections are platform-specific (image rebase, 1P
  integration, rpm-ostree are Linux-only; mobileconfig parsing is
  Mac-only).
- **Don't add interactive "apply? [y/N]" prompts to drift.** Drift just
  reports; the user reads and runs the suggested recipe. Keeps the tool
  predictable and small.
- The mobileconfig drift check on Mac compares
  `assets/brave-debloat.mobileconfig` against
  `/Library/Managed Preferences/<user>/com.brave.Browser.plist` via
  `plutil → jq`.
- Categories deliberately *not* tracked: Ptyxis dconf (shared single
  file, no per-machine variance), `.desktop` overrides + autostart,
  GNOME extensions (gext-installed set; the *configured* state is
  in the gnome-shell drift check), registered repos, PipeWire EQ,
  PWAs/icons, speaker EQ. Add only if the maintenance is worth it.
- Companion recipes: `just gnome-restore <machine>` loads shared
  `shell.dconf` then per-machine `shell.<machine>.dconf` into live
  state, with a y/N prompt that defaults to **no** (via `confirm()` in
  `lib/common.sh`). `just ptyxis-restore` applies the single Ptyxis
  snapshot the same way. Both overwrite live state — the prompt is
  there for a reason.
