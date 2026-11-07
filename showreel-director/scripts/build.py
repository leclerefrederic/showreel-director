#!/usr/bin/env python3
"""Build one self-contained HTML from project.json + engine files.

Usage: python3 build.py PROJECT_DIR [--out FILE]
Inlines: CSS tokens, fonts (woff2 base64, falls back to the raw file), the track (base64), beat map and
envelopes (from analysis_dir/beats.json + env.json), core.js + kit.js (window.SR, window.SRK), main.js, player.js. Prints a weight report and
fails if the budget in project.json is exceeded. No track: omit "track" (the reel then runs silent).
"""
import argparse, base64, io, json, os, sys

ENGINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "engine")

def b64(path): return base64.b64encode(open(path, "rb").read()).decode()

def font_css(fonts, root):
    css, report = [], []
    for f in fonts:
        p = os.path.join(root, f["path"])
        data, mime, fmt = open(p, "rb").read(), "font/ttf", "truetype"
        if p.lower().endswith(".ttf") or p.lower().endswith(".otf"):
            try:
                import importlib.util
                from fontTools.ttLib import TTFont
                flavor = "woff2" if importlib.util.find_spec("brotli") else "woff"  # woff2 needs the brotli package
                tt = TTFont(p); tt.flavor = flavor; buf = io.BytesIO(); tt.save(buf)
                data, mime, fmt = buf.getvalue(), "font/" + flavor, flavor
            except Exception:
                pass  # fontTools missing: embed the raw font file
        elif p.lower().endswith(".woff2"): mime, fmt = "font/woff2", "woff2"
        css.append('@font-face{font-family:"%s";font-weight:%s;font-style:%s;src:url(data:%s;base64,%s) format("%s")}'
                   % (f["family"], f.get("weight", 400), f.get("style", "normal"), mime, base64.b64encode(data).decode(), fmt))
        report.append((f["path"], len(data)))
    return "\n".join(css), report

def guard_assets(cfg, root):
    """Build only from prepared/ or generated/ assets that the manifest lists and the user did not exclude."""
    import csv
    paths = [cfg.get("track")] + [f.get("path") for f in cfg.get("fonts", [])]
    assets = os.path.normpath(os.path.join(root, "..", "assets")); man = os.path.join(assets, "MANIFEST.csv")
    rows = list(csv.DictReader(open(man, newline="", encoding="utf-8"))) if os.path.exists(man) else []
    errs = []
    for p in filter(None, paths):
        full = os.path.normpath(os.path.join(root, p)); rel = os.path.relpath(full, assets).replace(os.sep, "/")
        if rel.startswith("source/"): errs.append(f"{p}: points into assets/source (originals are never embedded); use the prepared copy")
        elif not (rel.startswith("prepared/") or rel.startswith("generated/")): print(f"warning: {p} is outside assets/prepared and assets/generated (run scripts/organize_assets.py)")
        elif rows:
            r = next((x for x in rows if x["file"] == rel), None)
            if not r: print(f"warning: {rel} is not listed in assets/MANIFEST.csv")
            elif r["status"] in ("excluded", "hold"): errs.append(f"{rel}: status is {r['status']} in the manifest, it must not be embedded")
            elif r["status"] == "proposed": print(f"warning: {rel} is still 'proposed' in the manifest (not approved yet)")
    if errs: sys.exit("asset guard:\n  " + "\n  ".join(errs))

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("project"); ap.add_argument("--out")
    ap.add_argument("--qa", help="comma-separated times (s): write a contact-sheet page instead of the player")
    ap.add_argument("--qa-step", type=float, help="contact sheet every N seconds")
    ap.add_argument("--qa-tile", type=int, default=420, help="tile width in px")
    ap.add_argument("--qa-langs"); ap.add_argument("--qa-modes")
    a = ap.parse_args(); root = a.project
    cfg = json.load(open(os.path.join(root, "project.json")))
    guard_assets(cfg, root)
    report = []
    data = {"beats": [], "dur": 60, "env": None, "downbeat_offset": 0}
    track_tag = ""
    if cfg.get("track"):
        tp = os.path.join(root, cfg["track"]); raw = open(tp, "rb").read()
        track_tag = '<script type="text/plain" id="trackdata">data:audio/mpeg;base64,%s</script>' % base64.b64encode(raw).decode()
        report.append((cfg["track"], len(raw) * 4 // 3))
        ad = os.path.join(root, cfg.get("analysis_dir", "analysis"))
        bt = json.load(open(os.path.join(ad, "beats.json"))); ev = json.load(open(os.path.join(ad, "env.json")))
        n = len(ev["kick"]); buf = bytearray()
        for i in range(n): buf += bytes([ev["kick"][i], ev["hat"][i], ev["energy"][i]])
        data = {"beats": bt["beats"], "dur": cfg.get("duration", bt["duration"]), "downbeat_offset": bt["downbeat_offset"],
                "env": {"fps": 50, "b64": base64.b64encode(bytes(buf)).decode()}}
    elif cfg.get("duration"): data["dur"] = cfg["duration"]
    fcss, frep = font_css(cfg.get("fonts", []), root); report += frep
    tokens = ";".join("%s:%s" % kv for kv in cfg.get("tokens", {}).items())
    rd = lambda p: open(p, encoding="utf-8").read()
    qa = a.qa is not None or a.qa_step is not None
    html = rd(os.path.join(ENGINE, "qa-shell.html" if qa else "shell.html"))
    qa_json = "null"
    if qa:
        times = [float(x) for x in a.qa.split(",")] if a.qa else [round(i * a.qa_step, 2) for i in range(int(data["dur"] / a.qa_step) + 1)]
        langs = a.qa_langs.split(",") if a.qa_langs else None; modes = a.qa_modes.split(",") if a.qa_modes else None
        qa_json = json.dumps({"times": times, "langs": langs or ["__ALL__"], "modes": modes or ["__ALL__"]})
        html = html.replace("__TILEW__", str(a.qa_tile))
    for k, v in [("__QA__", qa_json), ("__TITLE__", cfg["title"]), ("__TOKENS__", tokens), ("__FONTS_CSS__", fcss), ("__TRACK_TAG__", track_tag),
                 ("__DATA__", json.dumps(data, separators=(",", ":"))),
                 ("__CORE__", rd(os.path.join(ENGINE, "core.js")) + "\n" + rd(os.path.join(ENGINE, "kit.js"))), ("__MAIN__", rd(os.path.join(root, cfg["main"]))),
                 ("__PLAYER__", rd(os.path.join(ENGINE, "player.js")))]:
        html = html.replace(k, v)
    out = a.out or (os.path.join(root, "..", "qa", "contact-sheet.html") if qa else os.path.join(root, "dist", "index.html")); os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, "w", encoding="utf-8").write(html)
    total = len(html.encode()) / 1e6
    print("Weight report:")
    for n, s in report: print(f"  {n:45s}{s/1e6:8.2f} MB")
    print(f"  {'TOTAL HTML':45s}{total:8.2f} MB  (budget {cfg.get('weight_budget_mb','-')} MB)")
    if cfg.get("weight_budget_mb") and total > cfg["weight_budget_mb"]: sys.exit("Over budget")
    print("wrote", os.path.normpath(out))

if __name__ == "__main__":
    main()
