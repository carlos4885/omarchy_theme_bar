#!/usr/bin/env python3
"""Synthesises sounds/nfs-engine-start.wav: starter motor, a few compression strokes,
the engine catching with a cold-start flare, then settling to a flat-six idle.
Needs numpy only.  Usage: python3 tools/make_engine_sound.py"""
import wave
from pathlib import Path
import numpy as np

SR = 44100
DUR = 3.3
CRANK_END = 0.95          # the key lets go of START just after this (see nfs-ignition.qml)
CYL = 6                   # flat-six: firing frequency = rpm / 60 * CYL / 2

rng = np.random.default_rng(11)
n = int(SR * DUR)
t = np.arange(n) / SR


def lowpass(x, fc, order=4):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / (1 + (f / fc) ** order), len(x))


def highpass(x, fc, order=2):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    r = (f / fc) ** order
    return np.fft.irfft(X * r / (1 + r), len(x))


# ---- rpm curve -----------------------------------------------------------------
tc = np.clip(t - CRANK_END, 0, None)
crank_rpm = 170 + 30 * np.sin(2 * np.pi * 3.3 * t)
settle = 940 + 1500 * np.exp(-tc / 0.62)              # flare, then back to idle
ramp = np.clip(tc / 0.30, 0, 1) ** 0.7
run_rpm = 170 + (settle - 170) * ramp
rpm = np.where(t < CRANK_END, crank_rpm, run_rpm)
rpm = lowpass(rpm, 12, 2)

# a touch of irregular combustion
jitter = lowpass(rng.standard_normal(n), 25, 2)
jitter /= np.abs(jitter).max()
rpm = rpm * (1 + 0.012 * jitter)

# ---- engine body: harmonics of the firing frequency ----------------------------------
fire = rpm / 60 * CYL / 2
phase = np.cumsum(fire) / SR
body = np.zeros(n)
for h in range(1, 17):
    amp = 1.0 / h ** 0.85
    if h in (2, 4):
        amp *= 1.25                                     # warm, boxer-ish growl
    body += amp * np.sin(2 * np.pi * h * phase + h * 0.7)
pulse = 0.5 + 0.5 * np.cos(2 * np.pi * phase)           # each cylinder's bang
body *= 0.7 + 0.5 * pulse ** 2
body *= 1 + 0.10 * lowpass(rng.standard_normal(n), 60, 2) / 0.3

# exhaust rasp / intake
noise = lowpass(rng.standard_normal(n), 700, 2) * (0.15 + 0.85 * pulse ** 3)

running = np.clip((t - CRANK_END + 0.05) / 0.12, 0, 1)   # fades in as it fires
cranking = 1 - running * 0.82
engine = np.tanh(1.8 * (body * 0.55 + noise * 0.9)) * (0.30 * cranking + 0.70 * running)

# compression thuds while cranking: dull, low, one per stroke
thud = lowpass(body, 160) * 0.5 * (1 - running)

# ---- starter motor ---------------------------------------------------------------------
starter_on = ((t > 0.04) & (t < CRANK_END + 0.12)).astype(float)
starter_on = lowpass(starter_on, 40, 2)
labour = np.cos(2 * np.pi * np.cumsum(crank_rpm / 60 * CYL / 2) / SR)   # slows on each compression
f_s = 235 + 30 * labour
ph_s = np.cumsum(f_s) / SR
starter = (np.sin(2 * np.pi * ph_s) + 0.5 * np.sin(4 * np.pi * ph_s) + 0.25 * np.sin(6 * np.pi * ph_s))
starter *= starter_on * 0.17 * (1 - np.clip((t - CRANK_END) / 0.25, 0, 1))
starter += highpass(rng.standard_normal(n), 2500, 2) * starter_on * 0.012

# ---- solenoid clunk when the key reaches START ----------------------------------------
clunk = np.exp(-np.clip(t - 0.02, 0, None) / 0.018) * (t > 0.02)
clunk = (clunk * np.sin(2 * np.pi * 95 * t) * 0.9
         + clunk * lowpass(rng.standard_normal(n), 1800, 2) * 0.5) * 0.55

# ---- rumble underneath ---------------------------------------------------------------
rumble = lowpass(rng.standard_normal(n), 70, 4) * 2.2 * (0.35 + 0.65 * running)

mix = engine + thud + starter + clunk + rumble * 0.25
mix = highpass(mix, 28, 2)                     # nothing speakers can't play
mix = lowpass(mix, 7500, 2)

# envelope: soft in, long tail out
env = np.ones(n)
env[: int(0.004 * SR)] = np.linspace(0, 1, int(0.004 * SR))
tail = int(0.9 * SR)
env[-tail:] = np.linspace(1, 0, tail) ** 1.6
mix *= env
mix = mix / np.abs(mix).max() * 0.82

out = Path(__file__).resolve().parent.parent / "sounds" / "nfs-engine-start.wav"
out.parent.mkdir(exist_ok=True)
with wave.open(str(out), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((mix * 32767).astype("<i2").tobytes())
print(f"wrote {out}  ({n / SR:.2f} s, {out.stat().st_size // 1024} KB)")
