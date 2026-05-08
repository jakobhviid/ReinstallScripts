# Linux/assets/ files fetched by bazzite-custom

Two files in this directory are pulled at image build time by the
[bazzite-custom](https://github.com/jakobhviid/bazzite-custom) repo's
`build_files/build.sh` via raw GitHub URLs. Renaming or moving them
breaks the next image build (404). If you need to relocate, update the
URLs in `bazzite-custom/build_files/build.sh` in the same change.

| File | Fetched to (in image) |
|---|---|
| `brave-policy.json` | `/etc/brave/policies/managed/brave-policy.json` |
| `rename-devices.conf` | `/usr/share/wireplumber/wireplumber.conf.d/rename-devices.conf` |

The other files in this directory (zshrc.template, gnome/shell.dconf,
ptyxis.dconf, pwa/, speaker-eq.conf, color-calibration/,
bazzite-custom.pub, bazzite-flatpak-ignore.txt) are NOT fetched by
the image — they're consumed locally by `install-bazzite.sh` and the
`just *` recipes. Move them freely; just update the corresponding
references in `lib/`, `justfile`, or `install-bazzite.sh`.
