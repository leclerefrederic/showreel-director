#!/usr/bin/env python3
"""List and flag assets before the interview's round 5 or the brief's manifest.

Usage: python3 audit_assets.py ASSET_DIR [--budget-mb 20]
Per file: type, size, pixel size (images), duration (audio/video via ffprobe), licence/consent note found next to it,
and flags: heavy, small, personal-data keywords in text-like files, no licence note, proprietary/unknown font licence.
Read only; never modifies files. Treat flags as questions for the user, not verdicts.
"""
import argparse, json, os, re, subprocess

PII = re.compile(r"[\w.+-]+@[\w-]+\.[\w.]+|(?<!\d)(?:\+\d{1,3}[ .-]?)?(?:\d[ .-]?){9,}\d(?!\d)|\b[A-Z]{2}\d{2}[ ]?(?:\d{4}[ ]?){3,}|\b(?:iban|passport|ssn|password|secret|api[_-]?key)\b", re.I)

def probe(path):
    try:
        o = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration:stream=width,height", "-of", "json", path],
                           capture_output=True, text=True, timeout=30).stdout
        j = json.loads(o); d = float(j.get("format", {}).get("duration", 0) or 0)
        s = next((x for x in j.get("streams", []) if x.get("width")), {})
        return d, s.get("width"), s.get("height")
    except Exception:
        return 0, None, None

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("dir"); ap.add_argument("--budget-mb", type=float, default=20)
    a = ap.parse_args(); total = 0; rows = []
    notes = {}  # dir -> list of (filename, text)
    for r, _, fs in os.walk(a.dir):
        for f in fs:
            if re.search(r"licen|consent|info|readme|rights|notice", f, re.I) and f.lower().endswith((".txt", ".md")):
                notes.setdefault(r, []).append((f, open(os.path.join(r, f), errors="ignore").read()[:600]))
    def note_for(r, fname):
        """Licence text for a file: a note whose name shares a token with the file, else all notes of the folder."""
        toks = set(re.findall(r"[a-z]{4,}", re.sub(r"\.[a-z0-9]+$", "", fname.lower())))
        pick = [t for n, t in notes.get(r, []) if toks & set(re.findall(r"[a-z]{4,}", n.lower()))]
        return " ".join(pick) if pick else " ".join(t for _, t in notes.get(r, []))
    for r, _, fs in sorted(os.walk(a.dir)):
        for f in sorted(fs):
            p = os.path.join(r, f); ext = f.lower().rsplit(".", 1)[-1]; sz = os.path.getsize(p); total += sz; flags = []
            dur = w = h = None
            if ext in ("png", "jpg", "jpeg", "gif", "webp", "mp4", "mov", "webm", "mp3", "wav", "m4a", "ogg"):
                dur, w, h = probe(p)
            if ext in ("png", "jpg", "jpeg") and w and (w < 800 or h < 450): flags.append(f"small {w}x{h}")
            if ext in ("mp4", "mov", "webm") and sz > 5e6: flags.append("heavy video: canvas cannot seek video exactly; prefer stills/frame sequence")
            if sz > 3e6 and ext not in ("mp3", "wav"): flags.append(f"heavy {sz/1e6:.1f} MB")
            if ext in ("txt", "md", "csv", "json", "html") and PII.search(open(p, errors="ignore").read()[:20000]):
                flags.append("possible personal/secret data: confirm before using, never copy into the brief")
            if ext == "svg":
                sv = open(p, errors="ignore").read(20000)
                if re.search(r"<text[ >]", sv): flags.append("SVG draws text with a live font: as an image it falls back to a system font; convert the text to paths")
                if re.search(r"<rect[^>]*(width=.100%.|x=.0.[^>]*y=.0.)[^>]*fill=", sv) or re.search(r"<rect[^>]*fill=[^>]*(width=.100%.)", sv): flags.append("SVG has a full-size background rectangle: check it suits the film's base colour (light or dark variant)")
            if ext in ("png", "jpg", "jpeg") and re.search(r"client|customer|personal|data|real", f, re.I): flags.append("filename suggests real data")
            note = note_for(r, f)
            if ext in ("ttf", "otf", "woff", "woff2"):
                if not note: flags.append("font without licence note")
                elif re.search(r"proprietary|forbidden|not allowed|desktop only|workstation", note, re.I): flags.append("font licence forbids embedding")
            if ext in ("jpg", "jpeg", "png", "mp3", "wav", "mp4") and not note: flags.append("no licence/consent note next to it")
            if re.search(r"not confirmed|unconfirmed|unknown", note, re.I) and ext in ("jpg", "jpeg", "png", "mp4"): flags.append("rights/consent not confirmed")
            rows.append((os.path.relpath(p, a.dir), ext, sz, f"{w}x{h}" if w else "", f"{dur:.1f}s" if dur else "", flags))
    print(f"{'file':52s}{'KB':>8s}  {'px':>10s} {'len':>7s}  flags")
    for n, e, s, px, d, fl in rows: print(f"{n:52s}{s/1024:8.0f}  {px:>10s} {d:>7s}  {'; '.join(fl)}")
    print(f"\ntotal {total/1e6:.1f} MB on disk (embedded base64 adds ~33%); budget {a.budget_mb} MB for the final HTML")

if __name__ == "__main__":
    main()
