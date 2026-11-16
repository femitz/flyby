#!/usr/bin/env python3
"""Synthesizes an original 23 s ambient track for the Flyby promo (pure Python, no deps).

Structure: Am - F - C - Am pad, a soft ping-pong arpeggio from 1.5 s, a noise riser into
the end card and a bell on the logo reveal (21.3 s). Usage: python3 scripts/make-music.py out.wav
"""
import math
import random
import struct
import sys
import wave

SR = 44100
DUR = 23.0
N = int(SR * DUR)
random.seed(7)

L = [0.0] * N
R = [0.0] * N


def hz(name):
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    note, octave = name[0], int(name[-1])
    semis = names[note] + (1 if "#" in name else 0) + (octave - 4) * 12 - 9
    return 440.0 * 2 ** (semis / 12)


def smooth(x):
    return x * x * (3 - 2 * x)


# ---- Pad + sub: Am, F, C, Am ------------------------------------------------
CHORDS = [
    ["A2", "E3", "A3", "C4"],
    ["F2", "C3", "F3", "A3"],
    ["C3", "G3", "C4", "E4"],
    ["A2", "E3", "A3", "C4"],
]
BAR = DUR / len(CHORDS)
ATT = REL = 1.8

for ci, chord in enumerate(CHORDS):
    t0 = ci * BAR - (0.0 if ci == 0 else 0.0)
    t1 = (ci + 1) * BAR + REL
    s0, s1 = int(max(t0, 0) * SR), min(int(t1 * SR), N)
    for vi, name in enumerate(chord):
        f = hz(name)
        pan = (-0.4, 0.4, -0.2, 0.2)[vi]
        gl, gr = 1 - max(pan, 0), 1 + min(pan, 0)
        amp = 0.045
        for detune, side in ((0.9985, 0), (1.0015, 1)):
            ff = f * detune
            for s in range(s0, s1):
                t = s / SR
                env = smooth(min((t - t0) / ATT, 1)) if t >= t0 else 0
                env *= smooth(min(max((t1 - t) / REL, 0), 1))
                ph = 2 * math.pi * ff * t
                v = (math.sin(ph) + 0.33 * math.sin(2 * ph) + 0.12 * math.sin(3 * ph)) * amp * env
                if side == 0:
                    L[s] += v * gl
                    R[s] += v * gl * 0.55
                else:
                    L[s] += v * gr * 0.55
                    R[s] += v * gr
    root = hz(chord[0]) / 2
    for s in range(s0, s1):
        t = s / SR
        env = smooth(min((t - t0) / ATT, 1)) if t >= t0 else 0
        env *= smooth(min(max((t1 - t) / REL, 0), 1))
        v = math.sin(2 * math.pi * root * t) * 0.11 * env
        L[s] += v
        R[s] += v

# ---- Arpeggio through a ping-pong delay ----------------------------------------
AL = [0.0] * N
AR = [0.0] * N
step = 60 / 96 / 4  # 16th notes at 96 BPM
PATTERN = [0, 1, 2, 3, 2, 1, 2, 1, 0, 2, 3, 2, 1, 2, 3, 1]
i = 0
t = 1.5
while t < 21.0:
    chord = CHORDS[min(int(t / BAR), len(CHORDS) - 1)]
    f = hz(chord[PATTERN[i % len(PATTERN)]]) * 4
    accent = 1.0 if i % 4 == 0 else 0.65
    fade_in = smooth(min((t - 1.5) / 5.0, 1))
    pan = 0.35 if i % 2 == 0 else -0.35
    s0 = int(t * SR)
    for s in range(s0, min(s0 + int(1.3 * SR), N)):
        tt = (s - s0) / SR
        env = math.exp(-tt * 5.5) * min(tt / 0.004, 1)
        ph = 2 * math.pi * f * tt
        v = (math.sin(ph) + 0.28 * math.sin(2 * ph)) * 0.055 * accent * fade_in * env
        AL[s] += v * (1 - max(pan, 0))
        AR[s] += v * (1 + min(pan, 0))
    t += step
    i += 1

delay = int(step * 3 * SR)  # dotted eighth
fb, wet = 0.42, 0.55
for s in range(N):
    if s >= delay:
        AL[s] += AR[s - delay] * fb
        AR[s] += AL[s - delay] * fb
for s in range(N):
    L[s] += AL[s] * (1 + wet) * 0.8
    R[s] += AR[s] * (1 + wet) * 0.8

# ---- Riser into the end card (19.4 -> 21.3 s) ------------------------------------
r0, r1 = int(19.4 * SR), int(21.3 * SR)
lp = 0.0
for s in range(r0, r1):
    x = (s - r0) / (r1 - r0)
    a = 0.02 + 0.45 * x * x
    lp += a * (random.gauss(0, 1) - lp)
    env = smooth(x) * 0.12
    L[s] += lp * env
    R[s] += lp * env * 0.9

# ---- Bell on the logo reveal (21.3 s) ----------------------------------------------
b0 = int(21.3 * SR)
for s in range(b0, N):
    tt = (s - b0) / SR
    v = 0.0
    for ratio, amp, decay in ((1.0, 0.16, 1.1), (2.76, 0.07, 1.8), (5.4, 0.035, 3.0), (0.5, 0.10, 0.9)):
        v += amp * math.sin(2 * math.pi * 880.0 * ratio * tt) * math.exp(-tt * decay * 1.4)
    v *= min(tt / 0.003, 1)
    L[s] += v * 0.9
    R[s] += v * 1.0

# ---- Master: fades, normalize, write ---------------------------------------------------
peak = 0.0
for s in range(N):
    t = s / SR
    g = min(t / 0.8, 1) * min(max((DUR - t) / 1.8, 0), 1)
    L[s] *= g
    R[s] *= g
    peak = max(peak, abs(L[s]), abs(R[s]))

scale = 0.85 / peak
out = sys.argv[1] if len(sys.argv) > 1 else "out/flyby-trilha.wav"
with wave.open(out, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    frames = bytearray()
    for s in range(N):
        frames += struct.pack("<hh", int(max(-1, min(1, L[s] * scale)) * 32767), int(max(-1, min(1, R[s] * scale)) * 32767))
    w.writeframes(bytes(frames))
print("wrote", out)
