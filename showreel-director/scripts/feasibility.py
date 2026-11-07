#!/usr/bin/env python3
"""Feasibility check for a showreel brief (rules of thumb from references/feasibility.md).

Usage: python3 feasibility.py --duration 60 [--scenes N] [--text-scenes N] [--words N] [--bpm 124]
                               [--langs 2] [--portrait] [--narration-words N] [--transition 0.4]
Prints budgets and a verdict per check (OK / TIGHT / NOT FEASIBLE) with the numbers to quote to the user.
Exit code 1 if anything is NOT FEASIBLE.
"""
import argparse, math, sys

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--duration", type=float, required=True, help="seconds")
    ap.add_argument("--scenes", type=int, help="total scenes/shots requested")
    ap.add_argument("--text-scenes", type=int, help="of which carry text to read (default: all)")
    ap.add_argument("--words", type=int, help="total on-screen words in the master language")
    ap.add_argument("--langs", type=int, default=1)
    ap.add_argument("--expansion", type=float, default=1.3, help="translated text length factor (default 1.3)")
    ap.add_argument("--bpm", type=float)
    ap.add_argument("--portrait", action="store_true")
    ap.add_argument("--narration-words", type=int)
    ap.add_argument("--transition", type=float, default=0.4, help="seconds per transition")
    a = ap.parse_args(); D = a.duration; rows = []; bad = False
    def add(name, verdict, detail):
        nonlocal bad; rows.append((name, verdict, detail)); bad |= verdict == "NOT FEASIBLE"
    comf, stretch = D / 5, D / 3
    print(f"Duration {D:g} s. Text-bearing scenes: comfortable <= {math.floor(comf)}, stretch <= {math.floor(stretch)}. "
          f"Visual-only montage up to ~{math.floor(D / 1.5)} (down to 0.5 s each only in dense montage).")
    if a.scenes:
        ts = a.text_scenes if a.text_scenes is not None else a.scenes
        vs = a.scenes - ts
        per = D / a.scenes
        # budget: transitions eat time
        usable = D - a.scenes * a.transition * 0.5  # half of each transition overlaps the neighbours
        if per < 0.5:
            add("scene count", "NOT FEASIBLE", f"{a.scenes} scenes in {D:g} s = {per:.2f} s each: below 0.5 s they are flashes, not scenes (and flashes must stay under 3 per second)")
        elif ts > math.floor(stretch) and ts > 0:
            add("text scenes", "NOT FEASIBLE", f"{ts} scenes carrying text in {D:g} s leaves {D/ts:.1f} s each; text needs about 3 s (floor 1.5 s for 1-3 words)")
        elif ts > math.floor(comf):
            add("text scenes", "TIGHT", f"{ts} text scenes = {D/ts:.1f} s each: above the comfortable count ({math.floor(comf)}); keep lines short (about 6-8 words max)")
        else:
            add("text scenes", "OK", f"{ts} text scenes = {D/max(ts,1):.1f} s each")
        if vs and (D - ts * 3) / vs < 0.5:
            add("visual beats", "NOT FEASIBLE", f"{vs} visual-only beats do not fit in the {max(D - ts*3, 0):.1f} s left after text scenes")
        if a.transition * a.scenes > D * 0.4:
            add("transitions", "TIGHT", f"{a.scenes} transitions of {a.transition:g} s take {a.transition*a.scenes:.1f} s ({100*a.transition*a.scenes/D:.0f}% of the film): shorten them or cut scenes")
    if a.words is not None:
        eff = a.words * (a.expansion if a.langs > 1 else 1)
        wps = eff / D; limit = 2.0
        if a.portrait: limit = 1.6
        add("words on screen", "OK" if wps <= limit else "TIGHT" if wps <= limit * 1.5 else "NOT FEASIBLE",
            f"{eff:.0f} words{' (longest translation)' if a.langs > 1 else ''} in {D:g} s = {wps:.1f} words/s; target <= {limit:g} (reading capacity is ~4 w/s with full attention, far less with visuals)")
        chars = eff * 6; need = chars / 17 + 0.7 * (a.text_scenes or a.scenes or 1)
        if need > D:
            add("reading time", "NOT FEASIBLE", f"~{chars:.0f} characters need ~{chars/17:.0f} s of pure reading at 17 characters/s plus animation: more than {D:g} s")
    if a.narration_words is not None:
        wps = a.narration_words / D
        add("narration", "OK" if wps <= 2.2 else "TIGHT" if wps <= 2.7 else "NOT FEASIBLE",
            f"{a.narration_words} words = {wps:.1f} words/s; about 2.2 words/s (~130 wpm net of pauses) is comfortable")
    if a.bpm:
        bar = 240 / a.bpm; bars = D / bar
        note = "ends on a bar boundary" if abs(bars - round(bars)) < 0.15 else f"does not end on a bar boundary: use {math.floor(bars)} or {math.ceil(bars)} bars = {math.floor(bars)*bar:.1f} s or {math.ceil(bars)*bar:.1f} s"
        add("music", "OK" if "ends" in note else "TIGHT", f"bar = {bar:.2f} s, {bars:.1f} bars; {note}")
        if a.scenes:
            add("scene length vs bars", "OK" if D / a.scenes >= bar / 2 else "TIGHT", f"average scene {D/a.scenes:.2f} s vs half-bar {bar/2:.2f} s" + ("" if D / a.scenes >= bar / 2 else ": scenes shorter than a half bar cannot sit on the beat grid"))
    for n, v, d in rows: print(f"[{v:12s}] {n}: {d}")
    if bad: print("\nNot feasible as asked: propose a longer film, fewer or bigger scenes, text moved out of the film, or a short and a long version.")
    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    main()
