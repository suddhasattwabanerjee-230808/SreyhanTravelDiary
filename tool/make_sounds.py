"""Synthesises the app's sound effects and the garba music loop into
assets/sounds/*.ogg, so every sound is our own and needs no licence.

    python3 tool/make_sounds.py

Needs numpy and sox (for the OGG Vorbis encoding, about a tenth of WAV's size).
"""

import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack=0.005, decay=8.0):
    """A fast attack and an exponential fall, over n samples."""
    x = np.arange(n) / RATE
    a = np.clip(x / attack, 0, 1)
    return a * np.exp(-x * decay)


def tone(freq, seconds, decay=8.0, harmonics=(1.0,)):
    x = t(seconds)
    out = sum(h * np.sin(2 * np.pi * freq * (i + 1) * x) for i, h in enumerate(harmonics))
    return out * env(len(x), decay=decay)


def sweep(f0, f1, seconds, decay=6.0):
    x = t(seconds)
    f = np.geomspace(f0, f1, len(x))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return np.sin(phase) * env(len(x), decay=decay)


def lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def drum_low(seconds=0.45):
    """The dhol's bass side (dagga): a pitch-dropping thump."""
    x = t(seconds)
    f = 55 + 95 * np.exp(-x * 18)
    body = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(len(x), 0.002, 7)
    click = lowpass(rng.standard_normal(len(x)), 0.3) * env(len(x), 0.001, 60) * 0.3
    return body + click


def drum_high(seconds=0.22):
    """The dhol's treble side (tilli): a bright slap."""
    x = t(seconds)
    ring = np.sin(2 * np.pi * 410 * x) * env(len(x), 0.001, 22) * 0.6
    slap = rng.standard_normal(len(x)) * env(len(x), 0.001, 45) * 0.5
    return ring + slap


def pluck(freq, seconds=0.6):
    """Karplus-Strong string, a little like a santoor or rabab."""
    n = int(RATE * seconds)
    period = max(2, int(RATE / freq))
    buf = rng.uniform(-1, 1, period)
    out = np.empty(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = 0.996 * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out * env(n, 0.002, 2.5)


def mix_at(track, clip, start, gain=1.0):
    i = int(start * RATE)
    end = min(len(track), i + len(clip))
    track[i:end] += clip[: end - i] * gain


def save(name, x, peak=0.85):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    # Short fades so nothing clicks.
    fade = min(len(x) // 4, int(0.004 * RATE))
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype("<i2").tobytes()
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, name + ".wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(data)
        subprocess.run(["sox", wav, "-C", "3", os.path.join(OUT, name + ".ogg")], check=True)


def silence(seconds):
    return np.zeros(int(RATE * seconds))


def main():
    os.makedirs(OUT, exist_ok=True)

    # A bubbly pop for taps.
    save("pop", sweep(380, 1100, 0.09, decay=30), peak=0.6)

    # Two notes up when Sheru starts listening, two down when he stops.
    up = silence(0.32)
    mix_at(up, tone(660, 0.16, 18, (1, 0.3)), 0)
    mix_at(up, tone(990, 0.2, 14, (1, 0.3)), 0.11)
    save("listen_on", up, peak=0.6)
    down = silence(0.32)
    mix_at(down, tone(990, 0.16, 18, (1, 0.3)), 0)
    mix_at(down, tone(660, 0.2, 14, (1, 0.3)), 0.11)
    save("listen_off", down, peak=0.6)

    # A kite whoosh: band-limited noise that swells and fades.
    n = int(RATE * 0.6)
    noise = rng.standard_normal(n)
    shaped = lowpass(noise, 0.18) - lowpass(noise, 0.02)
    swell = np.sin(np.linspace(0, np.pi, n)) ** 2
    save("whoosh", shaped * swell, peak=0.55)

    # Camera shutter.
    shut = silence(0.18)
    mix_at(shut, rng.standard_normal(600) * env(600, 0.0005, 120), 0)
    mix_at(shut, rng.standard_normal(900) * env(900, 0.0005, 80) * 0.7, 0.07)
    save("shutter", shut, peak=0.5)

    # Sparkle: a bright rising arpeggio, for new words and stars.
    sp = silence(0.9)
    for i, f in enumerate([1047, 1319, 1568, 2093]):
        mix_at(sp, tone(f, 0.5, 9, (1, 0.25, 0.1)), i * 0.07, 0.8)
    save("sparkle", sp, peak=0.5)

    # Dhol celebration: dha . dhin dhin dha . dhin dhin, then a big hit.
    dh = silence(1.6)
    beat = 0.13
    pattern = ["L", "H", "H", "L", "H", "H", "LH", None, "LH"]
    for i, hit in enumerate(pattern):
        if hit and "L" in hit:
            mix_at(dh, drum_low(), i * beat)
        if hit and "H" in hit:
            mix_at(dh, drum_high(), i * beat, 0.8)
    save("dhol", dh, peak=0.9)

    # Oops: a soft wobble down, never harsh.
    save("oops", sweep(520, 260, 0.35, decay=6) * (1 + 0.3 * np.sin(2 * np.pi * 9 * t(0.35))), peak=0.45)

    music()


def music():
    """A gentle 8-bar garba loop: dhol in the 3-clap garba feel under a
    plucked melody in Bilawal (the major scale), 112 bpm."""
    bpm = 112
    beat = 60 / bpm
    bars = 8
    length = bars * 4 * beat
    track = silence(length + 1.0)

    # Rhythm: low on 1, highs on the off-beats, clap-like high on 3.
    for bar in range(bars):
        for step in range(8):
            when = (bar * 8 + step) * beat / 2
            if step in (0, 3, 6):
                mix_at(track, drum_low(0.4), when, 0.55)
            if step in (2, 4, 5, 7):
                mix_at(track, drum_high(0.18), when, 0.32)

    sa = 293.66  # D4
    scale = {"S": 0, "R": 2, "G": 4, "m": 5, "P": 7, "D": 9, "N": 11, "S'": 12, "R'": 14}
    melody = [
        # (note, length in beats)
        ("S", 1), ("R", 0.5), ("G", 0.5), ("P", 1), ("G", 1),
        ("m", 0.5), ("G", 0.5), ("R", 1), ("S", 2),
        ("G", 1), ("P", 0.5), ("D", 0.5), ("S'", 1), ("D", 1),
        ("P", 0.5), ("D", 0.5), ("P", 1), ("G", 2),
        ("S'", 1), ("R'", 0.5), ("S'", 0.5), ("D", 1), ("P", 1),
        ("G", 0.5), ("P", 0.5), ("D", 1), ("P", 2),
        ("G", 1), ("m", 0.5), ("G", 0.5), ("R", 1), ("G", 1),
        ("R", 0.5), ("N", 0.5), ("S", 3),
    ]
    when = 0.0
    for note, beats in melody:
        semis = scale[note] - (12 if note == "N" else 0)
        f = sa * 2 ** (semis / 12)
        mix_at(track, pluck(f, min(1.4, beats * beat + 0.5)), when, 0.5)
        when += beats * beat

    # Tanpura-like drone on Sa and Pa underneath.
    x = t(len(track) / RATE)
    drone = 0.05 * (np.sin(2 * np.pi * sa / 2 * x) + 0.6 * np.sin(2 * np.pi * sa * 0.75 * x))
    track += drone * (0.8 + 0.2 * np.sin(2 * np.pi * 0.25 * x))

    # Fold the tail back onto the start so the loop is seamless.
    n = int(length * RATE)
    tail = track[n:]
    track = track[:n]
    track[: len(tail)] += tail
    save("garba_loop", track, peak=0.7)


if __name__ == "__main__":
    main()
