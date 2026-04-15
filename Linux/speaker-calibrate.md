# Speaker Calibration Tool

Measures the frequency response of laptop speakers using the built-in DMIC and either auto-generates a PipeWire EQ config or reports the current response for manual tuning.

Designed for the ThinkPad X1 Carbon Gen 13, but should work on any laptop with PipeWire, a SoundWire/SOF speaker, and a built-in digital microphone.

## How it works

1. Generates a logarithmic sine sweep (50 Hz - 20 kHz)
2. Plays the sweep through the speakers via PulseAudio/PipeWire
3. Simultaneously records via the built-in DMIC
4. Computes the frequency response using Welch's method (power spectral density)
5. In calibration mode: designs parametric EQ bands to correct toward a target curve and writes a PipeWire filter-chain config
6. In measure-only mode: displays the response and averages multiple passes

## Prerequisites

### System packages (Fedora)

```bash
sudo dnf install -y python3-numpy python3-scipy sox pipewire-utils
```

### Other distros

You need:
- **python3** with **numpy** and **scipy**
- **paplay** and **parecord** (from `pipewire-pulseaudio` or `pulseaudio-utils`)
- **pactl** (from `pipewire-pulseaudio` or `pulseaudio-utils`)
- **wpctl** (from `wireplumber`)
- **PipeWire** as the audio server (with PulseAudio compatibility layer)

## Usage

### Measure current response (no changes)

```bash
python3 speaker-calibrate.py --measure-only
```

Runs 3 measurement passes by default and prints an averaged frequency response chart. Does not modify any config files.

### Measure with custom pass count

```bash
python3 speaker-calibrate.py --measure-only --iterations 5
```

### Auto-calibrate (overwrites EQ config)

```bash
python3 speaker-calibrate.py
```

Runs 3 iterative measurement/correction cycles, writing a new PipeWire filter-chain config to `~/.config/pipewire/pipewire.conf.d/speaker-eq.conf` and restarting PipeWire after each iteration.

**Warning:** This overwrites the existing `speaker-eq.conf`. Back it up first if you have a known-good config.

### Revert to manual EQ

If auto-calibration produces bad results:

```bash
# Restore the hand-tuned config from this repo
cp speaker-eq.conf ~/.config/pipewire/pipewire.conf.d/speaker-eq.conf
systemctl --user restart pipewire pipewire-pulse
```

Or remove the EQ entirely:

```bash
rm ~/.config/pipewire/pipewire.conf.d/speaker-eq.conf
systemctl --user restart pipewire pipewire-pulse
```

## Limitations

- The built-in DMIC has very limited high-frequency sensitivity. Readings above ~1.5 kHz are unreliable and should not be used for tuning decisions.
- The measurement is affected by room acoustics, background noise, and mic placement (fixed in the chassis). Keep the room quiet during measurement.
- Auto-calibration mode uses a target curve with mild bass emphasis (not flat), since flat EQ sounds thin on small laptop speakers.
- The hardcoded ALSA device names (`alsa_output.pci-0000_00_1f.3-platform-sof_sdw...` and `alsa_input.pci-0000_00_1f.3-platform-sof_sdw...`) are specific to the ThinkPad X1 Carbon Gen 13. Other machines will need these edited.

## Interpreting the output

```
   63 Hz:  -19.0 dB  |█
  125 Hz:  -28.7 dB  |
  250 Hz:  -17.1 dB  |██
  500 Hz:  -12.6 dB  |███████
 1000 Hz:   -7.7 dB  |████████████
 2000 Hz:  -46.4 dB  |              (unreliable — DMIC limitation)
```

All values are relative (dB difference between recorded and reference signal). The absolute numbers don't matter — what matters is the shape:

- A flat line = speakers reproducing all frequencies equally
- The typical laptop pattern: weak bass, peak around 500-1000 Hz, then the DMIC drops off above 1.5 kHz
- The 500-2000 Hz range is used as the normalization reference
