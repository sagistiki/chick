#!/usr/bin/env python3
"""
Generates 22 chick (Gallus gallus domesticus) peep variants grounded in
published bioacoustics of broiler and layer chicks.

Empirical anchors
-----------------
Broiler-chick acoustic studies distinguish four main vocalization classes
in the first weeks of life: distress calls, pleasure notes, short peeps,
and warbles. Across these classes, fundamental frequency (F0) in week-1
chicks clusters around 2.8–3.0 kHz, gradually dropping toward 1.2–2.0 kHz
by week 5, with most call energy between 2 and 6.5 kHz.[1]

Spectrograms of developing chick peeps show 2–3 nearly-parallel components,
typically near ~3, ~6, and ~8 kHz — a strong fundamental plus a small
number of upper partials.[2] Maternal-recognition experiments highlight
spectral components at 2, 3, 4 and 5 kHz as critical for distress
recognition.[3] In the avian syrinx, two labia can produce two independent
voiced sources simultaneously — the “two-voiced” phenomenon.[4] Hens
hear best around 1.5–2 kHz with reasonable sensitivity to ~7–8 kHz, so a
fundamental near 3 kHz with harmonics up to 8 kHz sits well inside the
species' audiogram.[5]

Spec table (tuned per call class)
---------------------------------
                    F0 primary    duration     contour          level
  Pleasure peep     2.8–4.5 kHz   0.16–0.22 s  rising           0.62–0.72
  Distress-style   ~2.7–4.8 kHz   0.16–0.25 s  falling          0.72–0.78
  Medium arc        3.0–4.8 kHz   0.13–0.18 s  rise-then-fall   0.66–0.72
  Short peep        2.7–3.5 kHz   0.10–0.14 s  short falling    0.60–0.68
  Warble / trill    2.8–4.2 kHz   0.28–0.37 s  bow / vibrato    0.60–0.70
Secondary syrinx voice runs +1.0–1.5 kHz above primary, at ~30–50% level —
matching the multi-component bands seen in real spectrograms.[2]

Envelope physics
----------------
Real peeps have an almost instantaneous onset (the syrinx opens with a sudden
burst of air). Each segment uses a fast cubic attack (1 − (1 − x)^3) over
2–5 ms for a percussive transient without digital clicking, followed by a
cosine-shaped release. During release, higher harmonics decay faster than
the fundamental (h_env = env^(1 + (n−1)·decay_rate)), so the call ends on
its pure fundamental — consistent with damped oscillator physics and with
chick spectrograms where upper components fade first.[2]

Output: 16-bit mono WAV @ 44.1 kHz.

References
----------
[1] Vocalization-based acoustic analyses of broiler chicks (PMC11960626):
    https://pmc.ncbi.nlm.nih.gov/articles/PMC11960626/
[2] Variations in the structure of the peep vocalization of female domestic
    chicks (escholarship): https://escholarship.org/content/qt55c106rt/qt55c106rt.pdf
[3] Frequency and intensity of chick distress calls — effects on maternal
    food-calling: https://pubmed.ncbi.nlm.nih.gov/24923498/
[4] Two-voiced sound production in the avian syrinx (PMC2807973):
    https://pmc.ncbi.nlm.nih.gov/articles/PMC2807973/
[5] Audiogram of the chicken (Gallus gallus domesticus) from 2 Hz to 9 kHz:
    https://www.tuttosullegalline.it/newsite/wp-content/uploads/2018/07/Audiogramofthechicken.pdf
"""

import wave
import struct
import math
import os
import random

SAMPLE_RATE = 44100


def make_lp_walker(rng, smoothing_tau, magnitude):
    """Smoothed random walk in [−magnitude, +magnitude]. Implements a one-pole
    low-pass over white noise; smoothing_tau (seconds) sets the corner frequency.

    Use for biological micro-fluctuations: F0 jitter and amplitude shimmer.
    Without these, fully periodic synthesis sounds artificial — real voiced
    sources never hold a perfectly steady frequency or amplitude.
    """
    alpha = math.exp(-1.0 / (SAMPLE_RATE * max(smoothing_tau, 1e-6)))
    state = [0.0]
    # Compensate gain: the LP attenuates white noise by (1-alpha) in steady-state std.
    gain = magnitude * math.sqrt(1.0 - alpha * alpha) / max(1.0 - alpha, 1e-6)
    def step():
        state[0] = alpha * state[0] + (1.0 - alpha) * rng.gauss(0.0, 1.0)
        v = state[0] * gain
        # Clip to ±magnitude to be safe.
        if v > magnitude: v = magnitude
        elif v < -magnitude: v = -magnitude
        return v
    return step
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sounds")
os.makedirs(OUT_DIR, exist_ok=True)

for f in os.listdir(OUT_DIR):
    if f.startswith("chirp_") and f.endswith(".wav"):
        try: os.remove(os.path.join(OUT_DIR, f))
        except OSError: pass


def render_segment(seg, sample_rate=SAMPLE_RATE, rng=None):
    duration = seg["duration"]
    n = int(duration * sample_rate)
    out = [0.0] * n
    rng = rng or random.Random()

    # Sharp default attack — mimics real chick syrinx burst.
    attack = seg.get("attack", 0.003)
    release = seg.get("release", 0.04)
    overall_level = seg.get("level", 0.70)
    sweep_curve = seg.get("sweep", "ease")
    seg_vrate = seg.get("vibrato_rate", 0.0)
    seg_vdepth = seg.get("vibrato_depth", 0.0)
    decay_rate = seg.get("harmonic_decay", 0.6)

    # Biological micro-fluctuations — small random F0 wobble and amplitude
    # shimmer that no perfectly periodic source has. Without these the synth
    # sounds "school project clean"; with them, alive.
    f0_jitter_pct = seg.get("f0_jitter", 0.015)   # ±1.5 % default
    amp_shimmer_pct = seg.get("amp_shimmer", 0.05) # ±5 %  default

    voices = seg.get("voices", [{
        "f_start": seg.get("f_start"),
        "f_end": seg.get("f_end"),
        "harmonics": seg.get("harmonics", [(1, 1.0)]),
        "level": 1.0,
    }])
    voice_total = sum(v.get("level", 1.0) for v in voices)

    # Each voice gets its own jitter/shimmer walker so the two syrinx voices
    # decorrelate (real avian labia move semi-independently).
    for v_index, v in enumerate(voices):
        phase = 0.0
        f0 = v["f_start"]
        f1 = v["f_end"]
        v_harm = v.get("harmonics", [(1, 1.0)])
        v_norm = sum(abs(a) for _, a in v_harm)
        v_lvl = v.get("level", 1.0) / voice_total
        v_vrate = v.get("vibrato_rate", seg_vrate)
        v_vdepth = v.get("vibrato_depth", seg_vdepth)
        # Asymmetric onset: voice 2 of the syrinx attacks ~1.5–2.5 ms after voice 1.
        # The two labia in a real chick syrinx don't fire at exactly the same
        # millisecond, and that micro-timing gives the chirp its body.
        onset_delay = 0.0 if v_index == 0 else 0.0015 + 0.001 * rng.random()
        onset_ramp = 0.0015  # quick ramp after onset_delay so voice 2 fades in

        f_jitter = make_lp_walker(rng, smoothing_tau=0.025, magnitude=f0_jitter_pct)
        a_shimmer = make_lp_walker(rng, smoothing_tau=0.040, magnitude=amp_shimmer_pct)

        for i in range(n):
            t = i / sample_rate
            prog = t / duration if duration > 0 else 0.0
            if sweep_curve == "linear":
                ease = prog
            elif sweep_curve == "exp":
                ease = prog * prog
            else:
                ease = 0.5 - 0.5 * math.cos(math.pi * prog)
            f = f0 + (f1 - f0) * ease
            if v_vrate > 0:
                f *= 1.0 + v_vdepth * math.sin(2 * math.pi * v_vrate * t)
            f *= 1.0 + f_jitter()  # micro-jitter
            phase += 2 * math.pi * f / sample_rate

            in_release = False
            if attack > 0 and t < attack:
                x = t / attack
                env_base = 1.0 - (1.0 - x) ** 3
            elif release > 0 and t > duration - release:
                x = max(0.0, (duration - t) / release)
                env_base = 0.5 - 0.5 * math.cos(math.pi * x)
                in_release = True
            else:
                env_base = 1.0

            # Voice-specific onset gate (asymmetric attack between voices).
            if t < onset_delay:
                onset_env = 0.0
            elif t < onset_delay + onset_ramp:
                onset_env = (t - onset_delay) / onset_ramp
            else:
                onset_env = 1.0
            env_base *= onset_env

            # Mix harmonics; high harmonics decay faster during release.
            s = 0.0
            for mult, amp in v_harm:
                if in_release and mult > 1:
                    h_env = env_base ** (1.0 + (mult - 1) * decay_rate)
                else:
                    h_env = env_base
                s += amp * math.sin(phase * mult) * h_env
            s /= v_norm
            # Amplitude shimmer applied per voice.
            s *= 1.0 + a_shimmer()
            out[i] += s * v_lvl

    for i in range(n):
        out[i] *= overall_level

    gap = seg.get("gap", 0.0)
    if gap > 0:
        out += [0.0] * int(gap * sample_rate)
    return out


def write_wav(path, segments, seed=None):
    rng = random.Random(seed)
    samples = []
    for seg in segments:
        samples += render_segment(seg, rng=rng)
    tail = int(0.005 * SAMPLE_RATE)
    if len(samples) > tail:
        for i in range(tail):
            samples[-tail + i] *= 1.0 - (i / tail)
    with wave.open(path, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        for s in samples:
            v = max(-1.0, min(1.0, s))
            wf.writeframes(struct.pack("<h", int(v * 32767 * 0.85)))


# Harmonic presets — match chick spectra: strong fundamental + decaying partials.
H_BRIGHT = [(1, 1.0), (2, 0.30), (3, 0.10)]
H_WARM   = [(1, 1.0), (2, 0.22), (3, 0.10), (4, 0.05)]
H_PURE   = [(1, 1.0)]
H_RICH   = [(1, 1.0), (2, 0.55), (3, 0.30), (4, 0.12)]


def dual(f1s, f1e, f2s, f2e, h1=H_BRIGHT, h2=H_WARM, l1=1.0, l2=0.45,
         v_rate=0, v_depth=0):
    """Helper: build a `voices` list with primary + syrinx-like secondary voice."""
    return [
        {"f_start": f1s, "f_end": f1e, "harmonics": h1, "level": l1,
         "vibrato_rate": v_rate, "vibrato_depth": v_depth},
        {"f_start": f2s, "f_end": f2e, "harmonics": h2, "level": l2,
         "vibrato_rate": v_rate, "vibrato_depth": v_depth},
    ]


SOUNDS = [
    # ============== 1–6: PLEASURE PEEPS (rising F0, low energy, ~0.18–0.22 s) ==============
    # 1. Classic pleasure peep — week-1 mean F0 region (~2.8–3.7 kHz), syrinx +1.4 kHz.
    [{"duration": 0.20, "attack": 0.003, "release": 0.060, "level": 0.70,
      "voices": dual(2800, 3700, 4200, 5100)}],

    # 2. Higher pleasure peep
    [{"duration": 0.18, "attack": 0.003, "release": 0.055, "level": 0.68,
      "voices": dual(3000, 4200, 4400, 5500, l2=0.40)}],

    # 3. Quick pleasure peep (sharper 2 ms attack)
    [{"duration": 0.16, "attack": 0.002, "release": 0.045, "level": 0.70,
      "voices": dual(2900, 3800, 4300, 5200, h2=H_PURE, l2=0.35)}],

    # 4. Long pleasure peep with subtle vibrato (warble-leaning)
    [{"duration": 0.22, "attack": 0.005, "release": 0.075, "level": 0.70,
      "voices": dual(2800, 4000, 4200, 5300, h1=H_WARM, h2=H_PURE, l2=0.40,
                     v_rate=7, v_depth=0.018)}],

    # 5. Soft up-peep (single pure voice for delicate timbre)
    [{"duration": 0.20, "attack": 0.003, "release": 0.075, "level": 0.62,
      "voices": [{"f_start": 2900, "f_end": 3700, "harmonics": H_PURE, "level": 1.0}]}],

    # 6. Delicate high pleasure note (top end of pleasure range)
    [{"duration": 0.18, "attack": 0.002, "release": 0.060, "level": 0.66,
      "voices": dual(3200, 4300, 4500, 5500, h2=H_PURE, l2=0.30)}],

    # ============== 7–10: DISTRESS-STYLE (descending F0, higher energy, ~0.18–0.25 s) =====
    # 7. Soft falling peep — distress mid-range, gentle for UI use
    [{"duration": 0.20, "attack": 0.004, "release": 0.075, "level": 0.74,
      "voices": dual(4200, 2900, 5400, 4100, h1=H_WARM, l2=0.50)}],

    # 8. Long falling peep — wide descent, longest in this group
    [{"duration": 0.25, "attack": 0.005, "release": 0.085, "level": 0.76,
      "voices": dual(4500, 2700, 5700, 3900, h1=H_WARM, h2=H_PURE, l2=0.35)}],

    # 9. Sharp descent (2 ms attack — most percussive distress)
    [{"duration": 0.16, "attack": 0.002, "release": 0.055, "level": 0.74,
      "voices": dual(4400, 3000, 5500, 4100)}],

    # 10. Mid-range falling peep
    [{"duration": 0.20, "attack": 0.003, "release": 0.075, "level": 0.72,
      "voices": dual(4000, 2900, 5200, 4100, h1=H_WARM, h2=H_PURE, l2=0.40)}],

    # ============== 11–13: MEDIUM PEEPS — "upper inversion" (rise-then-fall arc) ===========
    # 11. Standard arc peep — total ~0.16 s
    [{"duration": 0.07, "attack": 0.002, "release": 0.0, "level": 0.70, "sweep": "linear",
      "voices": dual(3200, 4400, 4500, 5500, l2=0.40)},
     {"duration": 0.09, "attack": 0.0, "release": 0.045, "level": 0.70,
      "voices": dual(4400, 3200, 5500, 4400, l2=0.40)}],

    # 12. Wide arc peep — total ~0.18 s
    [{"duration": 0.07, "attack": 0.002, "release": 0.0, "level": 0.70, "sweep": "linear",
      "voices": dual(2900, 4500, 4400, 5700, h1=H_WARM, h2=H_PURE, l2=0.40)},
     {"duration": 0.11, "attack": 0.0, "release": 0.060, "level": 0.72,
      "voices": dual(4500, 2900, 5700, 4100, h1=H_WARM, h2=H_PURE, l2=0.40)}],

    # 13. Subtle arc — total ~0.13 s
    [{"duration": 0.05, "attack": 0.002, "release": 0.0, "level": 0.66, "sweep": "linear",
      "voices": dual(3300, 3900, 4700, 5300, h2=H_PURE, l2=0.30)},
     {"duration": 0.08, "attack": 0.0, "release": 0.040, "level": 0.66,
      "voices": dual(3900, 3300, 5300, 4700, h2=H_PURE, l2=0.30)}],

    # ============== 14–16: SHORT PEEPS (short falling, narrow band, low energy) ============
    # 14. Tiny short peep — narrow descent ~0.10 s
    [{"duration": 0.10, "attack": 0.002, "release": 0.040, "level": 0.62,
      "voices": dual(3200, 2900, 4400, 4100, h2=H_PURE, l2=0.30)}],

    # 15. Soft contentment hum — long-end of short peep range, warm
    [{"duration": 0.13, "attack": 0.003, "release": 0.050, "level": 0.64,
      "voices": dual(2900, 2700, 4200, 4000, h1=H_WARM, h2=H_PURE, l2=0.35)}],

    # 16. Mid-range short
    [{"duration": 0.11, "attack": 0.002, "release": 0.045, "level": 0.66,
      "voices": dual(3300, 3050, 4500, 4250, l2=0.35)}],

    # ============== 17–19: SEQUENCES (pairs / triples — social / contact calls) ============
    # 17. Two-note pleasure pair (both rising)
    [{"duration": 0.08, "attack": 0.002, "release": 0.030, "level": 0.68, "gap": 0.06,
      "voices": dual(3000, 3800, 4400, 5100, l2=0.40)},
     {"duration": 0.09, "attack": 0.002, "release": 0.035, "level": 0.70,
      "voices": dual(3100, 4000, 4500, 5300, l2=0.40)}],

    # 18. Triple rapid peep (~3.5 kHz)
    [{"duration": 0.06, "attack": 0.002, "release": 0.024, "level": 0.66, "gap": 0.04,
      "voices": dual(3500, 3600, 4800, 4900, h2=H_PURE, l2=0.35)},
     {"duration": 0.06, "attack": 0.002, "release": 0.024, "level": 0.66, "gap": 0.04,
      "voices": dual(3500, 3600, 4800, 4900, h2=H_PURE, l2=0.35)},
     {"duration": 0.07, "attack": 0.002, "release": 0.030, "level": 0.68,
      "voices": dual(3550, 3750, 4850, 5050, h2=H_PURE, l2=0.35)}],

    # 19. Cascade descent (4.2 → 3.7 → 3.3 kHz)
    [{"duration": 0.07, "attack": 0.002, "release": 0.025, "level": 0.66, "gap": 0.04,
      "voices": dual(4200, 4150, 5400, 5350, h1=H_WARM, h2=H_PURE, l2=0.35)},
     {"duration": 0.07, "attack": 0.002, "release": 0.025, "level": 0.66, "gap": 0.04,
      "voices": dual(3700, 3650, 4900, 4850, h1=H_WARM, h2=H_PURE, l2=0.35)},
     {"duration": 0.08, "attack": 0.002, "release": 0.035, "level": 0.66,
      "voices": dual(3300, 3250, 4500, 4450, h1=H_WARM, h2=H_PURE, l2=0.35)}],

    # ============== 20–22: WARBLES & SPECIALS (~0.30–0.37 s) ==============================
    # 20. Trill / warble — rapid vibrato around 3.0–3.5 kHz, 0.30 s
    [{"duration": 0.30, "attack": 0.003, "release": 0.090, "level": 0.66,
      "voices": dual(3000, 3300, 4300, 4600, h2=H_PURE, l2=0.40,
                     v_rate=28, v_depth=0.045)}],

    # 21. Rich-harmonic peep — closer to real chick voice texture, ~0.18 s
    [{"duration": 0.18, "attack": 0.003, "release": 0.060, "level": 0.62,
      "voices": dual(3000, 3500, 4400, 5000, h1=H_RICH, h2=H_WARM, l2=0.45)}],

    # 22. Sleepy warble — long, low, very soft (warble-class duration ~0.35 s)
    [{"duration": 0.35, "attack": 0.005, "release": 0.110, "level": 0.60,
      "voices": dual(2700, 2900, 4000, 4200, h1=H_WARM, h2=H_PURE, l2=0.30,
                     v_rate=5, v_depth=0.012)}],
]


def main():
    for i, sound in enumerate(SOUNDS, start=1):
        path = os.path.join(OUT_DIR, f"chirp_{i:02d}.wav")
        # Deterministic per-preset seed so re-running gives identical output
        # while each chirp gets its own unique micro-jitter pattern.
        write_wav(path, sound, seed=1000 + i)
        print(f"wrote {path}")
    print(f"\nTotal: {len(SOUNDS)} chirps in {OUT_DIR}")


if __name__ == "__main__":
    main()
