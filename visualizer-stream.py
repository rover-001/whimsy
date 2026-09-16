#!/usr/bin/env python3
"""
# whimsy audio visualizer helper.
Captures the default audio sink monitor via pw-record, computes real-time FFT
across 16 frequency bands with AGC and decay, and prints normalized values (0.0 to 1.0)
to stdout for Quickshell consumption.
"""

import sys
import time
import signal
import subprocess
import numpy as np

# Audio capture configuration
RATE = 22050
CHUNK = 512
BANDS = 16

# Frequency band edges (logarithmic from 45Hz to 9000Hz)
freqs = np.fft.rfftfreq(CHUNK, 1.0 / RATE)
edges = np.geomspace(45, 9000, BANDS + 1)
bin_indices = [np.where((freqs >= edges[i]) & (freqs < edges[i + 1]))[0] for i in range(BANDS)]

# Start pw-record process to capture system audio output (sink monitor)
proc = subprocess.Popen(
    [
        "pw-record",
        "--target", "@DEFAULT_AUDIO_SINK@",
        "-P", "{ stream.capture.sink = true }",
        "--format", "s16",
        "--rate", str(RATE),
        "--channels", "1",
        "-"
    ],
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL
)

def cleanup(signum=None, frame=None):
    try:
        proc.terminate()
        proc.wait(timeout=0.2)
    except Exception:
        pass
    sys.exit(0)

signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)

smooth = np.zeros(BANDS, dtype=np.float32)
peak_val = 12.0
hanning_win = np.hanning(CHUNK)

try:
    while True:
        raw = proc.stdout.read(CHUNK * 2)
        if not raw or len(raw) < CHUNK * 2:
            break

        data = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
        fft = np.abs(np.fft.rfft(data * hanning_win))

        # Band energy calculation
        vals = np.array(
            [float(np.mean(fft[b])) if len(b) > 0 else 0.0 for b in bin_indices],
            dtype=np.float32
        )

        # Automatic Gain Control (slow decay, fast rise)
        m = float(np.max(vals))
        if m > peak_val:
            peak_val = peak_val * 0.85 + m * 0.15
        else:
            peak_val = max(4.0, peak_val * 0.992)

        # Normalize to 0.0 - 1.0 with slight power curve for musical punch
        norm = np.clip(vals / peak_val, 0.0, 1.0)
        norm = np.power(norm, 0.85)

        # Attack / Decay filter
        smooth = np.where(norm > smooth, smooth * 0.25 + norm * 0.75, smooth * 0.78)

        line = " ".join(f"{v:.2f}" for v in smooth) + "\n"
        try:
            sys.stdout.write(line)
            sys.stdout.flush()
        except BrokenPipeError:
            break


except (BrokenPipeError, KeyboardInterrupt):
    pass
finally:
    cleanup()

