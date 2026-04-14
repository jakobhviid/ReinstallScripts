#!/usr/bin/env python3
"""
Speaker calibration for ThinkPad X1 Carbon Gen 13.

Plays a log sweep through the speakers, records via the built-in mic,
computes the frequency response, and generates a PipeWire filter-chain
EQ config to flatten it out.

Run multiple iterations for progressive refinement.
"""

import subprocess, sys, os, json, time, tempfile
import numpy as np
from scipy import signal, fft

RATE = 48000
DURATION = 3          # seconds per sweep
SWEEP_LOW = 50
SWEEP_HIGH = 20000
SETTLE = 0.5          # seconds silence before/after
ITERATIONS = 3
EQ_CONFIG = os.path.expanduser("~/.config/pipewire/pipewire.conf.d/speaker-eq.conf")
SPEAKER_SINK = "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Speaker__sink"
# Use the digital mic as capture source
MIC_SOURCE = "alsa_input.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Mic__source"

# Target: mild bass boost curve (not flat — flat sounds thin on small speakers)
# This defines how many dB above flat we WANT at each frequency
TARGET_CURVE = {
    50: 6, 100: 5, 200: 4, 400: 2, 800: 0,
    1500: 0, 2500: -1, 4000: 0, 8000: 0, 16000: -1
}

def generate_sweep(filename):
    """Generate a logarithmic sine sweep WAV file."""
    n_settle = int(SETTLE * RATE)
    n_sweep = int(DURATION * RATE)
    t = np.linspace(0, DURATION, n_sweep, endpoint=False)

    # Log sweep
    phase = 2 * np.pi * SWEEP_LOW * DURATION / np.log(SWEEP_HIGH / SWEEP_LOW) * \
            (np.exp(t / DURATION * np.log(SWEEP_HIGH / SWEEP_LOW)) - 1)
    sweep = 0.7 * np.sin(phase)

    # Add settle silence
    audio = np.concatenate([np.zeros(n_settle), sweep, np.zeros(n_settle)])

    # Write as 16-bit WAV
    from scipy.io import wavfile
    wavfile.write(filename, RATE, (audio * 32767).astype(np.int16))
    return n_settle, n_sweep


def play_and_record(sweep_file, rec_file):
    """Play sweep through speakers while recording from mic simultaneously."""
    total_dur = DURATION + 2 * SETTLE + 1  # extra second margin

    # Use the built-in DMIC (not the USB webcam mic)
    mic = "alsa_input.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Mic__source"
    print(f"  Using mic: Digital Microphone (DMIC)")

    # Set DMIC as default source to ensure arecord uses it
    subprocess.run(["pactl", "set-default-source", mic], capture_output=True)

    # Start recording via PulseAudio/PipeWire (not raw ALSA)
    rec_cmd = [
        "parecord", "--format=s16le", "--rate=" + str(RATE), "--channels=1",
        "--device=" + mic, "--file-format=wav", rec_file,
    ]

    rec_proc = subprocess.Popen(rec_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1)  # let recording settle

    # Play sweep through PulseAudio so it goes through the EQ filter chain
    play_proc = subprocess.run(
        ["paplay", sweep_file],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )

    time.sleep(1.5)
    rec_proc.terminate()
    rec_proc.wait()


def analyze_response(sweep_file, rec_file, n_settle, n_sweep):
    """Compute frequency response from sweep and recording."""
    from scipy.io import wavfile

    _, sweep_data = wavfile.read(sweep_file)
    _, rec_data = wavfile.read(rec_file)

    sweep_data = sweep_data.astype(np.float64) / 32768.0
    if rec_data.ndim > 1:
        rec_data = rec_data[:, 0]
    rec_data = rec_data.astype(np.float64) / 32768.0

    # Extract the sweep portion (skip settle + some margin)
    start = n_settle + int(0.1 * RATE)
    end = n_settle + n_sweep - int(0.1 * RATE)

    if len(rec_data) < end:
        # Recording might be shorter; find the sweep via correlation
        print("  Recording shorter than expected, using available data")
        end = min(end, len(rec_data) - int(0.1 * RATE))
        if end <= start:
            print("  ERROR: Recording too short!")
            return None, None

    ref = sweep_data[start:end]
    rec = rec_data[start:end]

    # Compute power spectral density
    nperseg = min(8192, len(ref) // 4)
    f_ref, psd_ref = signal.welch(ref, fs=RATE, nperseg=nperseg)
    f_rec, psd_rec = signal.welch(rec, fs=RATE, nperseg=nperseg)

    # Frequency response = recording / reference (in dB)
    # Add small epsilon to avoid log(0)
    eps = 1e-12
    response_db = 10 * np.log10((psd_rec + eps) / (psd_ref + eps))

    # Smooth the response
    from scipy.ndimage import uniform_filter1d
    response_smooth = uniform_filter1d(response_db, size=15)

    return f_ref, response_smooth


def compute_target(freqs):
    """Interpolate the target curve at given frequencies."""
    target_freqs = sorted(TARGET_CURVE.keys())
    target_vals = [TARGET_CURVE[f] for f in target_freqs]
    return np.interp(freqs, target_freqs, target_vals)


def design_eq(freqs, measured_db, iteration):
    """Design parametric EQ bands to correct the measured response toward target."""
    target_db = compute_target(freqs)
    error_db = target_db - measured_db

    # Normalize: remove DC offset from error (mic sensitivity unknown)
    # Use 500-2000 Hz as reference band
    ref_mask = (freqs >= 500) & (freqs <= 2000)
    if ref_mask.any():
        error_db = error_db - np.mean(error_db[ref_mask])

    # Sample the error at key frequencies to create EQ bands
    eq_freqs = [80, 150, 300, 500, 1000, 2000, 3500, 6000, 10000]
    bands = []

    for ef in eq_freqs:
        idx = np.argmin(np.abs(freqs - ef))
        if idx >= len(error_db):
            continue
        correction = error_db[idx]

        # Limit correction per iteration (don't overcorrect)
        correction = np.clip(correction, -6, 8)

        # Only add band if correction is meaningful
        if abs(correction) > 0.5:
            if ef <= 120:
                btype = "bq_lowshelf"
                q = 0.6
            elif ef >= 8000:
                btype = "bq_highshelf"
                q = 0.7
            else:
                btype = "bq_peaking"
                q = 1.2

            bands.append({
                "freq": ef,
                "gain": round(float(correction), 1),
                "q": q,
                "type": btype
            })

    return bands, freqs, error_db


def write_pipewire_config(bands):
    """Write the PipeWire filter-chain config with the computed EQ bands."""
    nodes = []
    for i, band in enumerate(bands):
        nodes.append(f"""                    {{
                        type  = builtin
                        name  = eq_band{i+1}
                        label = {band['type']}
                        control = {{
                            "Freq"  = {band['freq']:.1f}
                            "Q"     = {band['q']}
                            "Gain"  = {band['gain']}
                        }}
                    }}""")

    links = []
    for i in range(len(bands) - 1):
        links.append(f'                    {{ output = "eq_band{i+1}:Out" input = "eq_band{i+2}:In" }}')

    config = f"""# Speaker EQ for ThinkPad X1 Carbon Gen 13
# AUTO-GENERATED by speaker-calibrate.py — do not hand-edit
# Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}
#
# Bands:
"""
    for band in bands:
        config += f"#   {band['type']} @ {band['freq']} Hz: {band['gain']:+.1f} dB (Q={band['q']})\n"

    config += f"""
context.modules = [
    {{ name = libpipewire-module-filter-chain
        args = {{
            node.description = "Speaker EQ"
            media.name        = "Speaker EQ"
            filter.graph = {{
                nodes = [
{chr(10).join(nodes)}
                ]
                links = [
{chr(10).join(links)}
                ]
            }}
            capture.props = {{
                node.name   = "effect_input.speaker_eq"
                media.class = Audio/Sink
                audio.channels = 2
                audio.position = [ FL FR ]
            }}
            playback.props = {{
                node.name   = "effect_output.speaker_eq"
                node.target = "{SPEAKER_SINK}"
                audio.channels = 2
                audio.position = [ FL FR ]
            }}
        }}
    }}
]
"""
    with open(EQ_CONFIG, 'w') as f:
        f.write(config)


def restart_pipewire():
    """Restart PipeWire and set the EQ sink as default."""
    subprocess.run(["systemctl", "--user", "restart", "pipewire", "pipewire-pulse"],
                   capture_output=True)
    time.sleep(2)

    # Find and set default
    result = subprocess.run(["wpctl", "status"], capture_output=True, text=True)
    for line in result.stdout.splitlines():
        if "effect_input.speaker_eq" in line:
            parts = line.strip().split(".")
            node_id = ""
            for ch in parts[0]:
                if ch.isdigit():
                    node_id += ch
            if node_id:
                subprocess.run(["wpctl", "set-default", node_id], capture_output=True)
                print(f"  Set default sink to node {node_id}")
                break


def print_response(freqs, db, label):
    """Print a simple ASCII frequency response chart."""
    print(f"\n  {label}:")
    check_freqs = [63, 125, 250, 500, 1000, 2000, 4000, 8000]
    for cf in check_freqs:
        idx = np.argmin(np.abs(freqs - cf))
        val = db[idx]
        bar_len = int(val + 20)  # offset so -20dB = 0 chars
        bar_len = max(0, min(bar_len, 50))
        bar = "█" * bar_len
        print(f"  {cf:>5} Hz: {val:>+6.1f} dB  {bar}")


def main():
    print("Speaker Calibration — ThinkPad X1 Carbon Gen 13")
    print("=" * 50)
    print(f"Will run {ITERATIONS} measurement/correction iterations.\n")
    print("IMPORTANT: Keep the room quiet during measurement!")
    print("The sweep will play through the speakers and record via the mic.\n")

    with tempfile.TemporaryDirectory() as tmpdir:
        sweep_file = os.path.join(tmpdir, "sweep.wav")
        print("Generating sweep signal...")
        n_settle, n_sweep = generate_sweep(sweep_file)

        for iteration in range(1, ITERATIONS + 1):
            print(f"\n--- Iteration {iteration}/{ITERATIONS} ---")

            rec_file = os.path.join(tmpdir, f"recording_{iteration}.wav")

            print("  Playing sweep and recording...")
            play_and_record(sweep_file, rec_file)

            print("  Analyzing frequency response...")
            freqs, measured_db = analyze_response(sweep_file, rec_file, n_settle, n_sweep)

            if freqs is None:
                print("  Measurement failed, skipping iteration.")
                continue

            print_response(freqs, measured_db, "Measured response (relative)")

            print("  Computing EQ correction...")
            bands, _, error_db = design_eq(freqs, measured_db, iteration)

            if not bands:
                print("  Response looks good — no correction needed!")
                break

            print(f"  Applying {len(bands)} EQ bands:")
            for b in bands:
                print(f"    {b['type']:15s} @ {b['freq']:>5.0f} Hz: {b['gain']:>+5.1f} dB")

            write_pipewire_config(bands)

            print("  Restarting PipeWire...")
            restart_pipewire()

            if iteration < ITERATIONS:
                print("  Waiting for PipeWire to settle...")
                time.sleep(2)

    print(f"\nDone! EQ config written to:\n  {EQ_CONFIG}")
    print("\nIf it sounds wrong, delete that file and run:")
    print("  systemctl --user restart pipewire pipewire-pulse")


if __name__ == "__main__":
    main()
