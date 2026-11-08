#!/usr/bin/env python3
"""Analyse a music track for a beat-synced reel (numpy + ffmpeg only).

Usage: python3 analyze_audio.py TRACK [--out DIR] [--bpm-hint N] [--bpm N] [--first-beat SECONDS]
Writes DIR/beats.json (bpm, beats, bars, bar energy, drops, breakdowns, returns) and DIR/env.json
(50 fps kick/hat/energy envelopes, 0-255). Prints a bar table to review with the user.
Always cross-check the printed bar times by ear/waveform: tempo drift or tempo changes
need manual correction. Never count beats by hand: use beats.json.
If the printed tempo is wrong (a half or double tempo, hi-hats mistaken for the beat), rerun with --bpm N (the real tempo) and, if the
beats are still off, --first-beat S (time of a real kick, in seconds). The run prints other plausible tempi to choose from.
"""
import argparse, json, os, subprocess
import numpy as np

SR = 22050; HOP = 256; NFFT = 1024
OFF = NFFT / 2 / SR  # frame i is centred at i*HOP/SR + OFF

def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)

def stft_mag(x):
    win = np.hanning(NFFT)
    n = 1 + (len(x) - NFFT) // HOP
    idx = np.arange(NFFT)[None, :] + HOP * np.arange(n)[:, None]
    return np.abs(np.fft.rfft(x[idx] * win, axis=1))

def band(mag, lo, hi):
    f = np.fft.rfftfreq(NFFT, 1 / SR)
    return mag[:, (f >= lo) & (f < hi)].sum(axis=1)

def norm(v):
    v = v - v.min()
    return v / (v.max() + 1e-9)

def onset_env(mag, lo=None, hi=None):
    if lo is not None:
        f = np.fft.rfftfreq(NFFT, 1 / SR); mag = mag[:, (f >= lo) & (f < hi)]
    m = np.log1p(mag * 10)
    flux = np.maximum(0, np.diff(m, axis=0, prepend=m[:1])).sum(axis=1)
    return norm(flux)

def tempo_scores(env, fr, hint=None):
    e = env - env.mean()
    ac = np.correlate(e, e, "full")[len(e) - 1:]
    lo, hi = int(fr * 60 / 200), int(fr * 60 / 60)
    lags = np.arange(lo, hi)
    bpms = 60 * fr / lags
    w = np.exp(-0.5 * (np.log2(bpms / (hint or 120)) / 0.9) ** 2)
    return bpms, ac[lags] * w, ac[lags]

def estimate_tempo(env, fr, hint=None):
    bpms, sc, _ = tempo_scores(env, fr, hint)
    return float(bpms[np.argmax(sc)])

def candidates(env, fr, hint=None, k=4):
    bpms, sc, raw = tempo_scores(env, fr, hint); out = []
    for i in np.argsort(-sc):
        if all(abs(bpms[i] / b - 1) > 0.04 for b, _ in out): out.append((float(bpms[i]), float(sc[i] / (sc.max() + 1e-9))))
        if len(out) >= k: break
    return out

def refine(env, fr, bpm, span=3.0):
    best = (-1, bpm, 0)
    n = len(env)
    for b in (np.arange(bpm - span, bpm + span, 0.05) if span else [bpm]):
        period = fr * 60 / b
        for ph in np.arange(0, period, 0.5):
            pos = np.arange(ph, n - 1, period)
            s = np.interp(pos, np.arange(n), env).sum() / len(pos)
            if s > best[0]: best = (s, b, ph / fr)
    return best[1], best[2]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("track"); ap.add_argument("--out", default="."); ap.add_argument("--bpm-hint", type=float); ap.add_argument("--bpm", type=float); ap.add_argument("--first-beat", type=float)
    a = ap.parse_args()
    x = decode(a.track); dur = len(x) / SR
    mag = stft_mag(x); fr = SR / HOP
    env = onset_env(mag)
    low = band(mag, 30, 150); high = band(mag, 6000, 11000); full = mag.sum(axis=1)
    # the kick (low band) carries the beat; hi-hats on the off-beat fool a full-band envelope, so the tempo is read on the kick
    kenv = onset_env(mag, 30, 150)
    base = kenv if kenv.std() > 0.02 else env
    cands = candidates(base, fr, a.bpm_hint)
    if a.bpm:
        bpm, phase = refine(base, fr, a.bpm, 0 if a.first_beat is not None else 0.3)
        if a.first_beat is not None: phase = a.first_beat - OFF
    else:
        bpm, phase = refine(base, fr, estimate_tempo(base, fr, a.bpm_hint))
    phase += OFF
    spb = 60 / bpm
    first = phase - np.floor((phase + 0.1) / spb) * spb  # allow a beat just before 0
    beats = list(np.arange(first, dur, spb))
    lowb = norm(low)
    sc = [np.interp((b - OFF) * fr, np.arange(len(lowb)), lowb) for b in beats]
    down = max(range(4), key=lambda k: np.mean(sc[k::4]) if len(sc[k::4]) else 0)
    bars = beats[down::4]
    # energy per bar, sections and drops
    en = norm(np.convolve(full, np.ones(5) / 5, "same"))
    be = [float(np.mean(en[max(0, int((b - OFF) * fr)):max(1, int((b + 4 * spb - OFF) * fr)) + 1])) if b + spb < dur else 0.0 for b in bars]
    mx = max(be) or 1.0
    drops = [i for i in range(1, len(be)) if be[i] - be[i - 1] > 0.35 * mx]
    # merge consecutive
    drops = [d for j, d in enumerate(drops) if j == 0 or d - drops[j - 1] > 2]
    # breakdowns = runs of 4+ beats where the bass nearly disappears; returns = the beat where the bass comes back.
    # Works on tracks with no loud/quiet jump (where the energy-based drop test above finds nothing).
    def beat_mean(v, b0, b1):
        i0, i1 = int((b0 - OFF) * fr), int((b1 - OFF) * fr)
        return float(np.mean(v[max(0, i0):max(1, i1) + 1])) if b1 < dur and i1 > 0 else 0.0
    bb = [beat_mean(lowb, beats[k], beats[k + 1]) if k + 1 < len(beats) else 0.0 for k in range(len(beats))]
    med = float(np.median([v for v in bb if v > 0]) or 1.0)
    low_flags = [v < 0.4 * med for v in bb[:-1]]
    breakdowns, returns, k = [], [], 0
    while k < len(low_flags):
        if low_flags[k]:
            j = k
            while j + 1 < len(low_flags) and low_flags[j + 1]: j += 1
            if j - k + 1 >= 4:
                tr = float(beats[j + 1]); bd = {"start": round(float(beats[k]), 3), "end": round(tr, 3), "beats": j - k + 1}
                if tr >= dur - 2 * spb:
                    bd["ends_track"] = True  # the bass fades at the end of the track: an outro, not a return
                else:
                    nb = next((q for q in range(len(bars)) if bars[q] >= tr - 0.25 * spb), len(bars) - 1)
                    rt = {"t": round(tr, 3), "beat": j + 1, "next_bar": nb + 1, "next_bar_t": round(float(bars[nb]), 3)}
                    bd["return"] = rt; returns.append(rt)
                if k == 0 or float(beats[k]) < 2 * 4 * spb and k < 8: bd["intro"] = True  # the bass is simply not in yet: an intro, not a breakdown
                breakdowns.append(bd)
            k = j + 1
        else:
            k += 1
    # 50 fps envelopes
    t50 = np.arange(0, dur, 1 / 50)
    def at50(v): return np.clip(np.interp((t50 - OFF) * fr, np.arange(len(v)), norm(v)) * 255, 0, 255).astype(int).tolist()
    os.makedirs(a.out, exist_ok=True)
    json.dump({"duration": round(dur, 3), "bpm": round(bpm, 2), "first_beat": round(float(beats[0]), 3),
               "beats": [round(float(b), 3) for b in beats], "downbeat_offset": down,
               "bars": [round(float(b), 3) for b in bars], "drops_bar_index": drops, "drops_bar_number": [d + 1 for d in drops],
               "bar_energy": [round(v, 2) for v in be], "breakdowns": breakdowns, "returns": returns}, open(os.path.join(a.out, "beats.json"), "w"))
    json.dump({"fps": 50, "kick": at50(low), "hat": at50(high), "energy": at50(full)}, open(os.path.join(a.out, "env.json"), "w"))
    print("other plausible tempi (score relative to the best): " + (", ".join(f"{b:.1f} BPM ({sc:.2f})" for b, sc in cands if abs(b - bpm) / bpm > .03) or "none") + "  (candidates within 3% of the chosen tempo are the same tempo and are left out; confirm by ear)  -> if the tempo above is wrong, rerun with --bpm N [--first-beat S]")
    print(f"duration {dur:.2f}s  tempo {bpm:.2f} BPM  bar {4*spb:.3f}s  first beat {beats[0]:.3f}s  downbeat offset {down}")
    print("bar  start(s)  energy  note")
    for i, (b, e) in enumerate(zip(bars, be)):
        print(f"{i+1:3d}  {b:8.2f}  {e:6.2f}  {'<- probable drop (bar ' + str(i + 1) + ', 1-based like this table)' if i in drops else ''}")
    if breakdowns:
        print("\nbreakdowns (bass out, 4+ beats) and returns (bass back = best place for a hit):")
        for b in breakdowns:
            r = b.get("return")
            if r: print(f"  {'(intro) ' if b.get('intro') else ''}{b['start']:.2f}s -> {b['end']:.2f}s ({b['beats']} beats)  bass back at {r['t']:.2f}s (beat {r['beat']}); hit on bar {r['next_bar']} at {r['next_bar_t']:.2f}s")
            else: print(f"  {b['start']:.2f}s -> end of track ({b['beats']} beats)  outro: the bass fades out, no return")
    else:
        print("\nno breakdown found (bass never drops out for 4+ beats): choose emphasis moments from the bar energy table or by ear.")
    print("\nCheck by ear: tempo changes, a late first beat or an ending that rings out need manual fixes.")

if __name__ == "__main__":
    main()
