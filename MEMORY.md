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
