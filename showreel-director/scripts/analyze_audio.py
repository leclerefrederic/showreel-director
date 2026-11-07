#!/usr/bin/env python3
"""Analyse a music track for a beat-synced reel (numpy + ffmpeg only).

Usage: python3 analyze_audio.py TRACK [--out DIR] [--bpm-hint N]
Writes DIR/beats.json (bpm, beats, bars, bar energy, drops, breakdowns, returns) and DIR/env.json
(50 fps kick/hat/energy envelopes, 0-255). Prints a bar table to review with the user.
Always cross-check the printed bar times by ear/waveform: tempo drift or tempo changes
need manual correction. Never count beats by hand: use beats.json.
"""
import argparse, json, os, subprocess, sys
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

def onset_env(mag):
    m = np.log1p(mag * 10)
    flux = np.maximum(0, np.diff(m, axis=0, prepend=m[:1])).sum(axis=1)
    return norm(flux)

def estimate_tempo(env, fr, hint=None):
    e = env - env.mean()
    ac = np.correlate(e, e, "full")[len(e) - 1:]
    lo, hi = int(fr * 60 / 200), int(fr * 60 / 60)
    lags = np.arange(lo, hi)
    bpms = 60 * fr / lags
    w = np.exp(-0.5 * (np.log2(bpms / (hint or 120)) / 0.9) ** 2)
    best = lags[np.argmax(ac[lags] * w)]
    return 60 * fr / best

def refine(env, fr, bpm):
    best = (-1, bpm, 0)
    n = len(env)
    for b in np.arange(bpm - 3, bpm + 3, 0.05):
        period = fr * 60 / b
        for ph in np.arange(0, period, 0.5):
            pos = np.arange(ph, n - 1, period)
            s = np.interp(pos, np.arange(n), env).sum() / len(pos)
            if s > best[0]: best = (s, b, ph / fr)
    return best[1], best[2]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("track"); ap.add_argument("--out", default="."); ap.add_argument("--bpm-hint", type=float)
    a = ap.parse_args()
    x = decode(a.track); dur = len(x) / SR
    mag = stft_mag(x); fr = SR / HOP
    env = onset_env(mag)
    low = band(mag, 30, 150); high = band(mag, 6000, 11000); full = mag.sum(axis=1)
    bpm, phase = refine(env, fr, estimate_tempo(env, fr, a.bpm_hint))
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
               "bars": [round(float(b), 3) for b in bars], "drops_bar_index": drops,
               "bar_energy": [round(v, 2) for v in be], "breakdowns": breakdowns, "returns": returns}, open(os.path.join(a.out, "beats.json"), "w"))
    json.dump({"fps": 50, "kick": at50(low), "hat": at50(high), "energy": at50(full)}, open(os.path.join(a.out, "env.json"), "w"))
    print(f"duration {dur:.2f}s  tempo {bpm:.2f} BPM  bar {4*spb:.3f}s  first beat {beats[0]:.3f}s  downbeat offset {down}")
    print("bar  start(s)  energy  note")
    for i, (b, e) in enumerate(zip(bars, be)):
        print(f"{i+1:3d}  {b:8.2f}  {e:6.2f}  {'<- probable drop' if i in drops else ''}")
    if breakdowns:
        print("\nbreakdowns (bass out, 4+ beats) and returns (bass back = best place for a hit):")
        for b in breakdowns:
            r = b.get("return")
            if r: print(f"  {b['start']:.2f}s -> {b['end']:.2f}s ({b['beats']} beats)  bass back at {r['t']:.2f}s (beat {r['beat']}); hit on bar {r['next_bar']} at {r['next_bar_t']:.2f}s")
            else: print(f"  {b['start']:.2f}s -> end of track ({b['beats']} beats)  outro: the bass fades out, no return")
    else:
        print("\nno breakdown found (bass never drops out for 4+ beats): choose emphasis moments from the bar energy table or by ear.")
    print("\nCheck by ear: tempo changes, a late first beat or an ending that rings out need manual fixes.")

if __name__ == "__main__":
    main()
