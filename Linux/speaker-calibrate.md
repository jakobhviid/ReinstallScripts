# Speaker Calibration Tool

Measures laptop speaker frequency response and optionally generates a PipeWire filter-chain EQ config.

Auto-detects speaker sink and microphone source. Falls back to interactive selection if detection fails. Can also be overridden with `--speaker` and `--mic` flags.

## Prerequisites (Fedora)

```bash
sudo dnf install -y python3-numpy python3-scipy
```

## Usage

```bash
# Measure current response (no changes made)
python3 speaker-calibrate.py --measure-only

# Multiple passes for better accuracy
python3 speaker-calibrate.py --measure-only --iterations 5

# Override device detection
python3 speaker-calibrate.py --measure-only --speaker "alsa_output.pci-..." --mic "alsa_input.pci-..."

# Auto-calibrate (overwrites speaker-eq.conf — back up first!)
python3 speaker-calibrate.py
```

## Full documentation

See the public repo: https://github.com/jakobhviid/thinkpad-x1-carbon-pipewire-eq
