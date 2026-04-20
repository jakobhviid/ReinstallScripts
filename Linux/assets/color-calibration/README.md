# Color Calibration Profiles

Factory color calibration profiles for the **ThinkPad X1 Carbon 13th Gen (21NS)** with a **Samsung ATNA40HQ02-0** 14" 2880x1800 OLED panel (panel ID `0A2D`).

## Source

Extracted from Lenovo's official Linux color calibration tool (`linux-color-calibration-install-v1.2.zip`), downloaded from Lenovo support. The tool is a self-extracting binary that embeds encrypted per-unit calibrated ICC profiles keyed to the laptop's serial number and panel ID. The profiles were captured during extraction since the tool's automatic installation fails on immutable/atomic Fedora distributions (read-only `/usr/share`).

## Profiles

| File | Description |
|------|-------------|
| `TPLCD_0A2D_Default.icm` | Lenovo's recommended default calibration |
| `TPLCD_0A2D_sRGB.icm` | sRGB color space (best for general web/photo work) |
| `TPLCD_0A2D_REC709.icm` | Rec. 709 (broadcast/video standard) |
| `TPLCD_0A2D_Native.icm` | Native panel gamut (unconstrained) |
| `PanelInfo.xml` | Panel metadata (gamma 2.2, sRGB color space, no HDR) |

## Installation

Copy the `.icm` files to `~/.local/share/icc/`:

```bash
mkdir -p ~/.local/share/icc
cp TPLCD_0A2D_*.icm ~/.local/share/icc/
```

The profiles will appear in **GNOME Settings > Color > Built-in display**, where you can select the active profile.

## Notes

- These profiles are specific to this panel model and may not be accurate for other machines or replacement panels.
- The Lenovo tool also supports AdobeRGB, DisplayP3, and DICOM profiles on other panel models, but this panel only includes the four listed above.
- On atomic/immutable Fedora (Bazzite, Silverblue, etc.), the standard install path `/usr/share/color/icc/colord/` is read-only. The user-local path `~/.local/share/icc/` works as an alternative and is picked up by colormgr.
