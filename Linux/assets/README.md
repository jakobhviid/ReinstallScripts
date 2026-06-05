# Linux/assets/ — what's here and where the image gets it

Most files in this directory are consumed locally by `install-bazzite.sh`,
`just *` recipes, and the user-mode `lib/config.sh` helpers. Two files
double as the **canonical reference for content the bazzite-custom image
also ships** — kept in lockstep with their inlined copies in the build
repo so `just drift` can flag divergence:

| File | Image-side copy (source-of-truth for what ships) | Notes |
|---|---|---|
| `brave-origin-policy.json` | `Stacks/services/bazzite-build/image/system_files/etc/brave/policies/managed/brave-policy.json` | The deployed file at `/etc/brave/policies/managed/brave-policy.json` comes from the image, not from this repo. Edit BOTH files when changing the policy. `just drift` compares the live file against this one. |
| `rename-devices.conf` | `Stacks/services/bazzite-build/image/system_files/usr/share/wireplumber/wireplumber.conf.d/rename-devices.conf` | Same model — image inlines its own copy verbatim. Edit both when changing. |

Until 2026-06-05 the bazzite-custom build fetched these two files from
this repo via raw GitHub URLs at image-build time. After the build moved
into the private Stacks repo and inlined `image/system_files/` verbatim,
the curl was retired. The files in this directory are no longer
auto-fetched by anything — they exist as the drift-check baseline,
the editable source for stock-Bazzite users (who deploy by `sudo cp`),
and the lockstep partner of the image's inlined copy.

The other files in this directory (zshrc.template, gnome/shell.dconf,
ptyxis.dconf, pwa/, color-calibration/, bazzite-custom.pub,
bazzite-flatpak-ignore.txt, ghostty.config) are pure local-use —
consumed by `install-bazzite.sh` and the `just *` recipes. Move them
freely; just update the corresponding references in `lib/`, `justfile`,
or `install-bazzite.sh`.
