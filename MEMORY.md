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

### Universal tool settings go in the template, not .zshrc.local

When a shell setting applies to a tool that's used on every machine, it
belongs in the template (`Mac/assets/zshrc.template`,
`Linux/assets/zshrc.template`), not in `~/.zshrc.local`.

**Why:** Jakob said: "Scripts don't care about local sometimes. but we use
brew everywhere, even linux." `.zshrc.local` is for *per-machine*
customizations — things only true on one machine. A setting that's true on
every machine is a default, and defaults belong in the source-of-truth so
every machine gets them.

**How to apply:**
- When drift surfaces a "harmless" extra line in `~/.zshrc`, ask: is this
  universal (every machine should have it) or per-machine (only here)?
  - **Universal** → bring it into the template; the next `just zsh`
    re-renders it everywhere. Examples: brew env vars (`HOMEBREW_NO_*`),
    aliases, default editors, locale settings.
  - **Per-machine** → move it to `~/.zshrc.local` (work tokens,
    machine-specific paths, hostname-conditional logic).
- Don't default to "move it to .zshrc.local" when drift is detected. The
  whole point of the templated approach is that good defaults are shared.

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
- v1 categories (Mac and Linux): zsh templates (`~/.zshrc`,
  `~/.config/starship.toml`, `~/.tmux.conf`), default shell, git identity,
  brave (mobileconfig keys on Mac, policy file on Linux), brewfile (missing
  + extras). Linux adds rpm-ostree layered packages.
- **Cross-platform parity matters:** when adding a new drift category on
  one platform, add it on the other if applicable. Same shape, same summary
  table format.
- **Don't add interactive "apply? [y/N]" prompts to drift.** Drift just
  reports; the user reads and runs the suggested recipe. Keeps the tool
  predictable and small.
- The mobileconfig drift check on Mac compares
  `assets/brave-debloat.mobileconfig` against
  `/Library/Managed Preferences/<user>/com.brave.Browser.plist` via
  `plutil → jq`.
- Categories deliberately *not* tracked: dconf (use `just gnome-restore` /
  `just ptyxis-restore` for explicit re-apply), `.desktop` overrides +
  autostart, GNOME extensions, registered repos, PipeWire EQ, PWAs/icons.
  Add only if the maintenance is worth it.
- Companion recipes: `just gnome-restore` and `just ptyxis-restore` apply
  the dconf snapshots back to live state with a y/N prompt that defaults
  to **no** because they overwrite live GNOME prefs.
