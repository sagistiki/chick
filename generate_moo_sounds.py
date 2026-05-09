#!/usr/bin/env python3
"""
Generates 10 cow (Bos taurus) moo variants grounded in published acoustic
analyses of bovine contact calls.

Empirical anchors
-----------------
Mother–offspring contact calls in cattle fall into two main acoustic types,
distinguished by mouth posture and communicative range:[1][2]

  - LOW-FREQUENCY CALLS (LFCs): produced with the mouth closed or partially
    closed for close-distance contact. Mean F0 ≈ 81 Hz in beef cows.[1]
  - HIGH-FREQUENCY CALLS (HFCs): produced with the mouth open, projecting
    over longer distance. Mean F0 ≈ 153 Hz.[1]

Cow and calf calls in these contexts typically last 1.3–1.5 s and display
a clear harmonic structure.[3] Formant analyses report the first two
vocal-tract resonances cluster around F1 ≈ 790 Hz and F2 ≈ 1942 Hz, yielding
a vowel-like timbre comparable to a mid-back adult-male vowel.[4] These
resonances are set by the supralaryngeal vocal tract and remain approximately
stable across F0 changes — standard source–filter theory.[5]

In high-arousal contexts (separation, distress, calf calls) cattle can push
F0 well above the typical mean, occasionally beyond 1 kHz, but the day-to-day
band sits in roughly 80–200 Hz.[2] We bracket calf-like / high-arousal calls
up to ~230 Hz here to add expressive variety while remaining well inside
the reported envelope.

Spec table (this file)
----------------------
                       F0 here       duration here   contour          arousal
  LFC (closed mouth)   100–130 Hz    0.95–1.20 s     flat / gentle    calm, close
  HFC (open mouth)     140–200 Hz    0.55–1.40 s     flat / slight    contact / call
  Calf / high-arousal  200–230 Hz    0.55–1.00 s     rising, vibrato  excited
F0 slope and vibrato depth gesture at affective state: HFCs and rising
contours correlate with higher arousal and more dynamic F0 trajectories,[6]
while LFCs sit lower and flatter.

Synthesis approach
------------------
Each moo is a single periodic source with a 15-harmonic stack whose
amplitudes are shaped by two Gaussian spectral envelopes centred on F1 and
F2. The one-sided σ values (280 Hz around F1, 380 Hz around F2) approximate
the formant bandwidths — a few hundred Hz wide is consistent with mammalian
vocal-tract resonance widths.[5] Higher harmonics decay faster than the
fundamental during release (env^(1+(n-1)·k)), so calls fade toward a
fundamental-dominated spectrum, matching the natural decay of damped voiced
signals visible in cattle spectrograms.[3]

Attack is a smooth ~40 ms ramp (vs the 2–4 ms percussive onset we use for
chick peeps): moos begin with a soft mouth-opening, not a syrinx burst.
Release is long enough to carry the vibrato that characterises calling and
contact moos.[3]

Output: 16-bit mono WAV @ 44.1 kHz.

References
----------
[1] Padilla de la Torre et al. — Acoustic analysis of cattle (Bos taurus)
    mother–offspring contact calls (source–filter perspective):
    https://www.sciencedirect.com/science/article/abs/pii/S0168159114003049
[2] BovineTalk — ML for vocalization analysis of dairy cattle:
    https://pmc.ncbi.nlm.nih.gov/articles/PMC10867142/
[3] Padilla de la Torre — mother–offspring contact calls (full text):
    http://ecology.nottingham.ac.uk/tomreader/assets/pdf/Padilla%20de%20la%20Torre-mother-offspring%20contact%20calls%20cattle-2015.pdf
[4] Bioneers — formant summary (F1 ≈ 790 Hz, F2 ≈ 1942 Hz):
    https://bioneers.org/cowpuppy-what-cows-are-really-saying-when-they-moo-ze0z2601/
[5] Source–filter theory primer (USC SAIL):
    https://sail.usc.edu/~lgoldste/General_Phonetics/Source_Filter/SFc.html
[6] Cattle vocalization & affective state — Frontiers Veterinary Science:
    https://www.frontiersin.org/journals/veterinary-science/articles/10.3389/fvets.2025.1549100/full
"""

import wave
import struct
import math
import os
import random

SAMPLE_RATE = 44100


def make_lp_walker(rng, smoothing_tau, magnitude):
    """Smoothed random walk in [−magnitude, +magnitude] (one-pole LP over
    white noise). Used for biological micro-fluctuations: F0 jitter and
    amplitude shimmer. Without these, fully periodic synthesis sounds
    "school project clean"; with them the moo gains a living quality.
    """
    alpha = math.exp(-1.0 / (SAMPLE_RATE * max(smoothing_tau, 1e-6)))
    state = [0.0]
    gain = magnitude * math.sqrt(1.0 - alpha * alpha) / max(1.0 - alpha, 1e-6)
    def step():
        state[0] = alpha * state[0] + (1.0 - alpha) * rng.gauss(0.0, 1.0)
        v = state[0] * gain
        if v > magnitude: v = magnitude
        elif v < -magnitude: v = -magnitude
        return v
    return step
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sounds")
os.makedirs(OUT_DIR, exist_ok=True)

# Wipe any prior moo_*.wav so old runs don't linger.
for f in os.listdir(OUT_DIR):
    if f.startswith("moo_") and f.endswith(".wav"):
        try: os.remove(os.path.join(OUT_DIR, f))
        except OSError: pass


# Formant centres (Hz) and bandwidths (one-sided σ) — from cattle acoustic studies.
F1_CENTER, F1_SIGMA = 790.0, 280.0
F2_CENTER, F2_SIGMA = 1940.0, 380.0


def moo_harmonics(f0, max_n=15):
    """Harmonic amplitudes shaped by Gaussian formant peaks at F1 and F2.

    The fundamental sets where peaks land in harmonic-number space, so a 150 Hz
    moo has F1≈5th harmonic and F2≈13th, and a 100 Hz moo has F1≈8th harmonic.
    """
    out = []
    for n in range(1, max_n + 1):
        f = f0 * n
        # Gentle 1/n decay as the unforced base.
        base = 0.55 / (1.0 + 0.18 * (n - 1))
        f1_gain = 0.55 * math.exp(-((f - F1_CENTER) / F1_SIGMA) ** 2)
        f2_gain = 0.40 * math.exp(-((f - F2_CENTER) / F2_SIGMA) ** 2)
        out.append((n, base + f1_gain + f2_gain))
    return out


def render_moo(f0_start, f0_end, duration,
               attack=0.04, release=0.22, level=0.62,
               vibrato_rate=0.0, vibrato_depth=0.0,
               sweep="ease", harmonic_decay=0.55,
               onset_noise_ms=6.0, onset_noise_level=0.10,
               f0_jitter=0.012, amp_shimmer=0.05,
               rng=None,
               sample_rate=SAMPLE_RATE):
    n = int(duration * sample_rate)
    out = [0.0] * n
    rng = rng or random.Random()

    # Harmonic profile based on mid F0 — formants don't shift with F0 sweep
    # (the throat resonator stays the same shape).
    h = moo_harmonics((f0_start + f0_end) / 2.0)
    norm = sum(abs(a) for _, a in h)

    f_jitter = make_lp_walker(rng, smoothing_tau=0.030, magnitude=f0_jitter)
    a_shimmer = make_lp_walker(rng, smoothing_tau=0.045, magnitude=amp_shimmer)

    phase = 0.0
    for i in range(n):
        t = i / sample_rate
        prog = t / duration if duration > 0 else 0.0
        if sweep == "linear":
            ease = prog
        elif sweep == "exp":
            ease = prog * prog
        else:
            ease = 0.5 - 0.5 * math.cos(math.pi * prog)
        f = f0_start + (f0_end - f0_start) * ease
        if vibrato_rate > 0:
            f *= 1.0 + vibrato_depth * math.sin(2 * math.pi * vibrato_rate * t)
        f *= 1.0 + f_jitter() # biological F0 wobble
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

        s = 0.0
        for mult, amp in h:
            if in_release and mult > 1:
                h_env = env_base ** (1.0 + (mult - 1) * harmonic_decay)
            else:
                h_env = env_base
            s += amp * math.sin(phase * mult) * h_env
        s /= norm
        s *= 1.0 + a_shimmer() # amplitude micro-modulation
        out[i] = s * level

    # Onset noise burst — simulates the brief turbulent airflow as the cow's
    # mouth opens before voicing fully engages. Triangular envelope over the
    # first few ms, white noise loosely band-limited by a one-pole LP. Subtle
    # but adds the "muh" feel that pure tones lack.
    burst_n = int(onset_noise_ms / 1000.0 * sample_rate)
    burst_n = min(burst_n, n)
    if burst_n > 0 and onset_noise_level > 0:
        noise_lp = 0.0
        lp_alpha = 0.55  # ~half-band low-pass to avoid hissy high frequencies
        for i in range(burst_n):
            w = (rng.random() - 0.5) * 2.0
            noise_lp = lp_alpha * noise_lp + (1.0 - lp_alpha) * w
            tent = 1.0 - abs(2.0 * i / burst_n - 1.0)
            out[i] += noise_lp * onset_noise_level * tent * level

    return out


def write_wav(path, samples, _unused_seed=None):
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


# 10 moo variants spanning the spec table above.
# Each entry is annotated with its acoustic class (LFC / HFC / calf-or-HA)
# so the relationship to the published anchors is explicit.
MOOS = [
    # 1. Standard HFC — mid-range adult open-mouth contact call.
    {"f0_start": 165, "f0_end": 140, "duration": 1.05, "level": 0.62, "release": 0.28},

    # 2. Calf / high-arousal — higher pitch, subtle vibrato (excited timbre).
    {"f0_start": 215, "f0_end": 230, "duration": 0.85, "level": 0.58,
     "vibrato_rate": 4.0, "vibrato_depth": 0.020, "release": 0.25},

    # 3. HFC long mellow — toward the LFC/HFC boundary, slow vibrato.
    {"f0_start": 145, "f0_end": 130, "duration": 1.40, "level": 0.62,
     "vibrato_rate": 5.0, "vibrato_depth": 0.025, "release": 0.38},

    # 4. HFC short — quick contact call.
    {"f0_start": 195, "f0_end": 175, "duration": 0.55, "level": 0.60, "release": 0.18},

    # 5. HFC + arousal — rising F0 (questioning / curious intonation).
    {"f0_start": 165, "f0_end": 215, "duration": 1.00, "level": 0.60,
     "sweep": "linear", "release": 0.28},

    # 6. HFC drawn-out — calling, with vibrato.
    {"f0_start": 160, "f0_end": 145, "duration": 1.30, "level": 0.62,
     "vibrato_rate": 6.0, "vibrato_depth": 0.030, "release": 0.32},

    # 7. LFC — low rumble, closed-mouth (~100–110 Hz, near reported LFC mean).
    {"f0_start": 110, "f0_end": 100, "duration": 1.20, "level": 0.62, "release": 0.32},

    # 8. HFC projecting — loud distance call, mid-high F0 with slight dip.
    {"f0_start": 200, "f0_end": 175, "duration": 1.20, "level": 0.68, "release": 0.30},

    # 9. LFC-leaning — gentle, quiet, soft attack (close-contact).
    {"f0_start": 130, "f0_end": 120, "duration": 0.95, "level": 0.50,
     "attack": 0.06, "release": 0.32},

    # 10. Two-syllable phrase — short pre-grunt (LFC-like) + main HFC moo.
    {"_two_syllable": True},
]


def generate_two_syllable(rng):
    a = render_moo(155, 145, 0.25, attack=0.03, release=0.06, level=0.55, rng=rng)
    a += [0.0] * int(0.10 * SAMPLE_RATE)  # gap between syllables
    a += render_moo(170, 150, 1.00, attack=0.04, release=0.30, level=0.63, rng=rng)
    return a


def main():
    for i, m in enumerate(MOOS, start=1):
        # Deterministic per-preset seed: each moo gets unique jitter/noise but
        # repeated runs are reproducible.
        rng = random.Random(2000 + i)
        if m.get("_two_syllable"):
            samples = generate_two_syllable(rng)
        else:
            samples = render_moo(rng=rng, **m)
        path = os.path.join(OUT_DIR, f"moo_{i:02d}.wav")
        write_wav(path, samples)
        print(f"wrote {path}")
    print(f"\nTotal: {len(MOOS)} moos in {OUT_DIR}")


if __name__ == "__main__":
    main()
