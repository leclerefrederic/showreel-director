#!/usr/bin/env python3
"""Build one self-contained HTML from project.json + engine files.

Usage: python3 build.py PROJECT_DIR [--out FILE]
Inlines: CSS tokens, fonts (woff2 base64, falls back to the raw file), the track (base64), beat map and
envelopes (from analysis_dir/beats.json + env.json), core.js + kit.js (window.SR, window.SRK), main.js, player.js. Prints a weight report and
fails if the budget in project.json is exceeded. No track: omit "track" (the reel then runs silent).
"""
import argparse, base64, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _common as C

ENGINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "engine")

def font_css(fonts, root):
    css, report = [], []
    for f in fonts:
        p = os.path.join(root, f["path"])
        data, mime, fmt = C.font_blob(p, flavor="auto", only_sfnt=True)  # woff2 needs the brotli package, else woff, else the raw file
        css.append(C.font_face(f["family"], data, mime, fmt, weight=f.get("weight", 400), style=f.get("style", "normal")))
        report.append((f["path"], len(data)))
    return "\n".join(css), report

def guard_assets(cfg, root, allow_unlisted=False):
    """Build only from prepared/ or generated/ assets that the manifest lists and the user did not exclude."""
    import csv
    paths = [cfg.get("track")] + [f.get("path") for f in cfg.get("fonts", [])] + list((cfg.get("images") or {}).values())
    assets = os.path.normpath(os.path.join(root, "..", "assets")); man = os.path.join(assets, "MANIFEST.csv")
    rows = list(csv.DictReader(open(man, newline="", encoding="utf-8"))) if os.path.exists(man) else []
    errs = []
    for p in filter(None, paths):
        full = os.path.normpath(os.path.join(root, p)); rel = os.path.relpath(full, assets).replace(os.sep, "/")
        if rel.startswith("source/"): errs.append(f"{p}: points into assets/source (originals are never embedded); use the prepared copy")
        elif not (rel.startswith("prepared/") or rel.startswith("generated/")): print(f"warning: {p} is outside assets/prepared and assets/generated (run scripts/organize_assets.py)")
        elif rows:
            r = next((x for x in rows if x["file"] == rel), None)
            if not r and allow_unlisted: print(f"warning: {rel} is not listed in assets/MANIFEST.csv (allowed for scratch work)")
            elif not r: errs.append(f"{rel}: not listed in assets/MANIFEST.csv; register it (organize_assets.py) or pass --allow-unlisted for scratch work")
            elif r["status"] in ("excluded", "hold"): errs.append(f"{rel}: status is {r['status']} in the manifest, it must not be embedded")
            elif r["status"] == "proposed": print(f"warning: {rel} is still 'proposed' in the manifest (not approved yet)")
    if errs: sys.exit("asset guard:\n  " + "\n  ".join(errs))

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("project"); ap.add_argument("--out")
    ap.add_argument("--qa", help="comma-separated times (s): write a contact-sheet page instead of the player")
    ap.add_argument("--qa-step", type=float, help="contact sheet every N seconds")
    ap.add_argument("--qa-tile", type=int, default=420, help="tile width in px")
    ap.add_argument("--qa-langs"); ap.add_argument("--qa-modes")
    ap.add_argument("--cut", help="build the named cut declared under \"cuts\" in project.json (own duration, optional track_start_bar)")
    ap.add_argument("--allow-unlisted", action="store_true", help="scratch work: embed files that are not in assets/MANIFEST.csv")
    a = ap.parse_args(); root = a.project
    cfg = json.load(open(os.path.join(root, "project.json")))
    cut = a.cut
    if cut:
        if cut not in (cfg.get("cuts") or {}): sys.exit(f"unknown cut {cut!r}; declared cuts: {', '.join((cfg.get('cuts') or {}).keys()) or 'none'}")
        cfg = dict(cfg); cfg.update(cfg["cuts"][cut])
    guard_assets(cfg, root, a.allow_unlisted)
    report = []
    data = {"beats": [], "dur": 60, "env": None, "downbeat_offset": 0}
    track_tag = ""
    if cfg.get("track"):
        tp = os.path.join(root, cfg["track"])
        if not os.path.exists(tp): sys.exit(f"track file not found: {cfg['track']}. For a silent film, remove the \"track\" key (and \"analysis_dir\") from project.json and set \"duration\".")
        raw = open(tp, "rb").read()
        ad0 = os.path.join(root, cfg.get("analysis_dir", "analysis")); tdur = json.load(open(os.path.join(ad0, "beats.json")))["duration"]
        want = cfg.get("duration"); sbar = cfg.get("track_start_bar"); tstart = 0.0
        bt0 = json.load(open(os.path.join(ad0, "beats.json")))
        if sbar:
            if sbar < 1 or sbar > len(bt0["bars"]): sys.exit(f"track_start_bar {sbar} is outside the track (it has {len(bt0['bars'])} bars)")
            tstart = float(bt0["bars"][sbar - 1])
        if want and want > tdur - tstart + .01: print(f"warning: duration {want}s is longer than the track from the start point ({tdur - tstart:.1f}s)")
        if tstart > 0 or (want and tdur > want + 2):
            import shutil, subprocess, tempfile
            if shutil.which("ffmpeg"):
                tmpf = os.path.join(tempfile.mkdtemp(), "trim.mp3")
                cmd = ["ffmpeg", "-y", "-v", "error", "-ss", str(tstart), "-i", tp] + (["-t", str(want + 1)] if want else []) + ["-c:a", "libmp3lame", "-q:a", "2", tmpf]
                r = subprocess.run(cmd, capture_output=True)
                if r.returncode == 0: raw = open(tmpf, "rb").read(); print(f"track cut from {tstart:.2f}s" + (f" to {tstart + want + 1:.0f}s" if want else "") + " for embedding (the beat map and bars are shifted to match; bar 1 of this cut is track bar " + str(sbar or 1) + ")")
                elif tstart > 0: sys.exit("ffmpeg failed to cut the track: " + r.stderr.decode()[-200:])
            elif tstart > 0: sys.exit("track_start_bar needs ffmpeg to cut the track")
            else: print(f"warning: the track ({tdur:.0f}s) is much longer than the reel ({want}s) and ffmpeg is missing to trim it: the whole track will be embedded")
        elif not want and tdur: print(f"note: no \"duration\" in project.json, the reel lasts as long as the track ({tdur:.1f}s)")
        track_tag = '<script type="text/plain" id="trackdata">data:audio/mpeg;base64,%s</script>' % base64.b64encode(raw).decode()
        report.append((cfg["track"], len(raw) * 4 // 3))
        ad = os.path.join(root, cfg.get("analysis_dir", "analysis"))
        bt = json.load(open(os.path.join(ad, "beats.json"))); ev = json.load(open(os.path.join(ad, "env.json")))
        n = len(ev["kick"]); buf = bytearray()
        for i in range(n): buf += bytes([ev["kick"][i], ev["hat"][i], ev["energy"][i]])
        beats_l, down_l = bt["beats"], bt["downbeat_offset"]
        if tstart > 0:  # the cut starts on a bar: drop the earlier beats and envelope samples, bar 1 of the cut is the first beat
            keep = [b for b in beats_l if b >= tstart - 0.001]; beats_l = [round(b - tstart, 3) for b in keep]; down_l = 0
            buf = bytearray(bytes(buf)[3 * int(round(tstart * 50)):])
        data = {"beats": beats_l, "dur": cfg.get("duration", bt["duration"] - tstart), "downbeat_offset": down_l,
                "env": {"fps": 50, "b64": base64.b64encode(bytes(buf)).decode()}}
        if tstart > 0: data["track_start"] = round(tstart, 3)
    elif cfg.get("duration"): data["dur"] = cfg["duration"]
    imgs = {}
    for key, rel in (cfg.get("images") or {}).items():
        ip = os.path.join(root, rel); ext = rel.lower().rsplit(".", 1)[-1]
        if not os.path.exists(ip): sys.exit(f"images.{key}: file not found: {rel}")
        mime = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "svg": "image/svg+xml", "webp": "image/webp", "gif": "image/gif"}.get(ext)
        if not mime: sys.exit(f"images.{key}: unsupported type .{ext}")
        raw_i = open(ip, "rb").read(); imgs[key] = "data:%s;base64,%s" % (mime, base64.b64encode(raw_i).decode()); report.append((f"image {key}", len(raw_i) * 4 // 3))
    if imgs: data["images"] = imgs
    if cut: data["cut"] = cut
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
                 ("__CORE__", rd(os.path.join(ENGINE, "core.js")) + "\n" + rd(os.path.join(ENGINE, "kit.js")) + ("\n" + rd(os.path.join(ENGINE, "backgrounds.js")) if re.search(r"\bSRB\b", re.sub(r"/\*.*?\*/|//[^\n]*", "", rd(os.path.join(root, cfg["main"])), flags=re.S)) else "")), ("__MAIN__", rd(os.path.join(root, cfg["main"]))),
                 ("__PLAYER__", rd(os.path.join(ENGINE, "player.js")))]:
        html = html.replace(k, v)
    out = a.out or (os.path.join(root, "..", "qa", "contact-" + os.path.basename(os.path.normpath(root)) + ("-" + cut if cut else "") + ".html") if qa else os.path.join(root, "dist", "index" + ("-" + cut if cut else "") + ".html")); os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, "w", encoding="utf-8").write(html)
    total = len(html.encode()) / 1e6
    print("Weight report:")
    for n, s in report: print(f"  {n:45s}{s/1e6:8.2f} MB")
    print(f"  {'TOTAL HTML':45s}{total:8.2f} MB  (budget {cfg.get('weight_budget_mb','-')} MB)")
    if cfg.get("weight_budget_mb") and total > cfg["weight_budget_mb"]: sys.exit("Over budget")
    print("wrote", os.path.normpath(out))

if __name__ == "__main__":
    main()
