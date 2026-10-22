"""Synthesises the app's sound effects and music loops into
assets/sounds/*.ogg, so every sound is our own and needs no licence.

    python3 tool/make_sounds.py              # everything
    python3 tool/make_sounds.py blocks obby  # only the named music loops

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


def reverb(x, seconds=2.4, wet=0.28):
    """A soft room: convolution with a fading, darkened noise tail."""
    ir = lowpass(rng.standard_normal(int(RATE * seconds)), 0.25) * np.exp(-t(seconds) * 3.2)
    ir /= np.sqrt(np.sum(ir**2))
    n = 1 << int(np.ceil(np.log2(len(x) + len(ir))))
    tail = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)[: len(x) + len(ir)]
    out = np.concatenate([x, np.zeros(len(ir))]) * (1 - wet)
    return out + tail * wet * 0.5


def piano(freq, seconds, vel=1.0):
    """A soft felt piano: a few slightly stretched partials, the higher ones
    fading faster, and a gentle hammer."""
    x = t(seconds)
    out = sum(
        a * np.sin(2 * np.pi * freq * k * (1 + 0.0004 * k * k) * x) * np.exp(-x * (0.9 + 0.8 * k))
        for k, a in enumerate((1.0, 0.4, 0.18, 0.08, 0.04), start=1)
    )
    out *= np.clip(x / 0.01, 0, 1)
    return out * vel


def fold_loop(track, length):
    """Folds the tail back onto the start so the loop is seamless."""
    n = int(length * RATE)
    tail = track[n:]
    track = track[:n].copy()
    track[: len(tail)] += tail
    return track


def note(name):
    """'C4', 'F#3' -> Hz."""
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    return 440 * 2 ** ((names[name[:-1]] + 12 * (int(name[-1]) - 4)) / 12)


def blocks():
    """Block World: a calm, spacious piano loop in the mood of block-building
    games. Slow chords, a few high notes, lots of room. 66 bpm, 8 bars."""
    bpm = 66
    beat = 60 / bpm
    bars = 8
    length = bars * 4 * beat
    track = silence(length + 6)
    chords = [
        ["F2", "C3", "A3", "E4"], ["C3", "G3", "E4", "B4"], ["A2", "E3", "C4", "G4"], ["G2", "D3", "B3", "D4"],
        ["F2", "C3", "A3", "E4"], ["C3", "G3", "E4", "G4"], ["D3", "A3", "F4", "C5"], ["G2", "D3", "B3", "F4"],
    ]
    melody = [  # (bar, beat, note)
        (0, 2, "A4"), (0, 3, "C5"), (1, 1.5, "B4"), (1, 3, "G4"), (2, 2, "E5"), (2, 3, "C5"), (3, 2, "D5"),
        (4, 2, "A4"), (4, 3, "E5"), (5, 1.5, "D5"), (5, 3, "B4"), (6, 2, "A4"), (6, 3, "F5"), (7, 2.5, "D5"),
    ]
    for bar, chord in enumerate(chords):
        start = bar * 4 * beat
        # Rolled gently, low to high.
        for i, n in enumerate(chord):
            mix_at(track, piano(note(n), 5.5, 0.55 if i == 0 else 0.32), start + i * 0.09)
        mix_at(track, piano(note(chord[1]), 3.5, 0.18), start + 2 * beat)
    for bar, b, n in melody:
        mix_at(track, piano(note(n), 4.0, 0.42), (bar * 4 + b) * beat)
    track = lowpass(track, 0.35)
    track = reverb(track)
    save("blocks_loop", fold_loop(track, length), peak=0.6)


def square(freq, seconds, decay=5.0):
    """A chiptune square wave, softened to its first few odd harmonics."""
    x = t(seconds)
    out = sum(np.sin(2 * np.pi * freq * k * x) / k for k in (1, 3, 5, 7))
    return out * env(len(x), 0.003, decay)


def triangle(freq, seconds, decay=4.0):
    x = t(seconds)
    out = sum(((-1) ** i) * np.sin(2 * np.pi * freq * k * x) / (k * k) for i, k in enumerate((1, 3, 5)))
    return out * env(len(x), 0.003, decay)


def obby():
    """Obby Dash: a bouncy, cheerful chiptune loop in the mood of obstacle-
    course games. 128 bpm, 8 bars in C major."""
    bpm = 128
    beat = 60 / bpm
    bars = 8
    length = bars * 4 * beat
    track = silence(length + 1.5)
    for b in range(bars * 4):
        when = b * beat
        kick = sweep(150, 45, 0.18, decay=16)
        mix_at(track, kick, when, 0.7)
        hat = lowpass(rng.standard_normal(int(RATE * 0.05)), 0.9) - lowpass(rng.standard_normal(int(RATE * 0.05)), 0.2)
        mix_at(track, hat * env(len(hat), 0.001, 70), when + beat / 2, 0.18)
        if b % 2 == 1:
            snare = rng.standard_normal(int(RATE * 0.12)) * env(int(RATE * 0.12), 0.001, 28)
            mix_at(track, snare, when, 0.22)
    bass = ["C3", "C3", "A2", "A2", "F2", "F2", "G2", "G2"]
    for bar, n in enumerate(bass):
        for e in range(8):
            f = note(n) * (2 if e % 2 else 1)
            mix_at(track, triangle(f, beat / 2 + 0.05, 6), (bar * 4 + e / 2) * beat, 0.45)
    tune = [
        ("E5", 0.5), ("G5", 0.5), ("C6", 1), ("G5", 0.5), ("E5", 0.5), ("D5", 1),
        ("C5", 0.5), ("E5", 0.5), ("A5", 1), ("G5", 0.5), ("E5", 0.5), ("C5", 1),
        ("F5", 0.5), ("A5", 0.5), ("C6", 1), ("A5", 0.5), ("G5", 0.5), ("F5", 1),
        ("G5", 0.5), ("A5", 0.5), ("B5", 0.5), ("D6", 0.5), ("C6", 2),
        ("E5", 0.5), ("G5", 0.5), ("C6", 1), ("D6", 0.5), ("C6", 0.5), ("A5", 1),
        ("C5", 0.5), ("D5", 0.5), ("E5", 1), ("G5", 0.5), ("E5", 0.5), ("C5", 1),
        ("F5", 0.5), ("E5", 0.5), ("D5", 1), ("A5", 0.5), ("G5", 0.5), ("F5", 1),
        ("D5", 0.5), ("E5", 0.5), ("G5", 0.5), ("B5", 0.5), ("C6", 2),
    ]
    when = 0.0
    for n, beats in tune:
        mix_at(track, square(note(n), beats * beat + 0.08, 4.5), when, 0.22)
        when += beats * beat
    save("obby_loop", fold_loop(track, length), peak=0.65)


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


LOOPS = {"blocks": blocks, "obby": obby}

if __name__ == "__main__":
    import sys

    os.makedirs(OUT, exist_ok=True)
    if sys.argv[1:]:
        for name in sys.argv[1:]:
            LOOPS[name]()
    else:
        main()
        for make in LOOPS.values():
            make()
