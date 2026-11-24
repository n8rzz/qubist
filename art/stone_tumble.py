"""Makes the line-clear stone tumble sounds (#170).

A low thump with a few separate pebble knocks after it. Knocks, not
continuous noise, so it doesn't read as scraping. Each seed gives one take
with its own pebble pitches and timing. The game alternates the takes.

Needs numpy and scipy. Run from the repo root:

    python3 art/stone_tumble.py

and it writes assets/audio/stone_tumble_*.wav.
"""
import os

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
## One take per seed. 11 is the take picked in the #170 audition.
TAKES = {"a": 11, "b": 21}


def times(seconds):
    return np.arange(int(SR * seconds)) / SR


def envelope(seconds, attack, decay):
    e = np.exp(-decay * times(seconds))
    n = int(SR * attack)
    e[:n] *= np.linspace(0, 1, n)
    return e


def band(x, lo, hi):
    return sosfilt(butter(2, [lo, hi], "band", fs=SR, output="sos"), x)


def tone(freq, seconds, decay):
    return np.sin(2 * np.pi * freq * times(seconds)) * envelope(seconds, 0.001, decay)


def mix(*parts):
    out = np.zeros(max(len(p) for p in parts))
    for p in parts:
        out[: len(p)] += p
    return out


def place(buf, sound, at):
    i = int(at * SR)
    buf[i : i + len(sound)] += sound[: len(buf) - i]


def tumble(seed, seconds=0.9, knocks=5, gap=0.08, jitter=0.03, pitch=(600, 1400)):
    rng = np.random.default_rng(seed)
    buf = np.zeros(int(SR * seconds))
    place(buf, mix(tone(90, 0.4, 14), tone(140, 0.3, 20) * 0.5) * 1.2, 0)
    for i in range(knocks):
        f = rng.uniform(*pitch)
        click = band(rng.standard_normal(int(SR * 0.04)), f * 0.7, f * 1.3) * envelope(0.04, 0.0005, 90)
        knock = mix(click, tone(f, 0.12, 70) * 0.6)
        place(buf, knock * max(0, 1 - i / 7) * 0.7 * rng.uniform(0.7, 1.0), 0.03 + i * gap + rng.uniform(0, jitter))
    buf = buf / np.max(np.abs(buf)) * 0.9
    fade = int(SR * 0.01)
    buf[-fade:] *= np.linspace(1, 0, fade)
    return (buf * 32767).astype(np.int16)


if __name__ == "__main__":
    for name, seed in TAKES.items():
        path = os.path.join(OUT, f"stone_tumble_{name}.wav")
        wavfile.write(path, SR, tumble(seed))
        print("wrote", os.path.normpath(path))
