#!/usr/bin/env python3
"""Export a project made in a chat to Showreel Studio: writes <project>/showreel.json (schema 1) from the files the skill keeps.

Usage: python3 export_studio.py PROJECT [--facts facts.json] [--force] [--dry-run]
Reads brief.md, style-sheet.md, storyboard.md (first table), assets/MANIFEST.csv and analysis/beats.json when they exist.
Hex colours, fonts, languages, duration and the storyboard table are read from the files; what the files cannot say reliably
(audience, message, tone, fonts, gate states, formats, mood, track) goes in --facts, a JSON file shaped like showreel.json
(only the keys you know; it overrides what was read). The file is documented in references/studio-export.md.
Never overwrites a showreel.json written by the app (origin.tool "studio") unless --force. Never touches the other files.
"""
import argparse, csv, json, os, re, sys, datetime
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_scene_cards import parse_table, find, norm, clean, seconds

LANGS = {"english": "en", "french": "fr", "german": "de", "spanish": "es", "italian": "it", "portuguese": "pt", "dutch": "nl", "swedish": "sv",
         "polish": "pl", "japanese": "ja", "chinese": "zh", "korean": "ko"}
GATES = ["interview", "assets", "style", "storyboard", "review", "build", "verify", "publish"]

def read(p):
    return open(p, encoding="utf-8").read() if os.path.isfile(p) else ""

def section(text, title):
    lines = text.split("\n"); st = next((i for i, l in enumerate(lines) if l.startswith("#") and title in l.lower()), None)
    if st is None: return ""
    lvl = len(lines[st]) - len(lines[st].lstrip("#")); end = len(lines)
    for i in range(st + 1, len(lines)):
        if lines[i].startswith("#") and len(lines[i]) - len(lines[i].lstrip("#")) <= lvl: end = i; break
    return "\n".join(lines[st + 1:end])

def hexes(text):
    out = []
    for m in re.findall(r"#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})\b", text):
        if m.upper() not in out: out.append(m.upper())
    return out

def grab(pat, text):
    m = re.search(pat, text, re.I | re.M)
    return m.group(1).strip(" *_`\"'") if m else None

def languages(text):
    line = grab(r"^[\s\-*]*(?:reel\s+)?languages?\s*[:=]\s*([^\n]+)", text)
    out = []
    for part in re.split(r"[,;/&]", line or ""):
        w = part.strip().lower(); c = LANGS.get(w) or (w if re.fullmatch(r"[a-z]{2}", w) else None)
        if c and c not in out: out.append(c)
    return out

def storyboard(text):
    """The scene library and the master montage from the first table of storyboard.md: (scenes, items). A row is a scene of the library with its
    own duration (end minus start); the montage lists the rows in order. A start that differs from where the order puts the scene is kept as
    the item's manual start. A DITCH row is archived and switched off; a Time of "off" switches the scene off."""
    head, rows = parse_table(text)
    if not rows: return [], []
    cid = find(head, "id", "#", "scene", "sequence", "plan") or head[0]
    ctime = find(head, "time", "temps", "duree", "duration") or next((h for h in head if sum(1 for r in rows if seconds(r.get(h, "")) is not None) >= max(1, len(rows) // 2)), None)
    ctext = find(head, "text", "texte", "texto", "titre", "line"); cimg = find(head, "image", "motion", "visuel")
    cfeel = find(head, "feeling", "tension", "ressenti", "emotion"); cgag = find(head, "gag", "handoff", "transition")
    ccut = find(head, "in cuts", "cuts")
    xtext = [h for h in head if h != ctext and any(k in norm(h) for k in ("text", "texte", "texto"))]
    used = {cid, ctime, ctext, cimg, cfeel, cgag, ccut, *xtext}
    out, items, t0 = [], [], 0.0
    for k, r in enumerate(rows):
        sid = clean(r.get(cid, "")).strip() or str(k + 1)
        sid = sid if re.match(r"^S\d+", sid) else "S%02d" % (int(sid) if sid.isdigit() else k + 1)
        tcell = r.get(ctime, "") if ctime else ""
        t = [float(x.replace(",", ".")) for x in re.findall(r"\d+(?:[.,]\d+)?", tcell)]
        off = bool(re.search(r"\boff\b", tcell, re.I))
        ditched = bool(re.search(r"ditch", " ".join(r.values()), re.I))
        dur = round(t[1] - t[0], 3) if len(t) > 1 and t[1] > t[0] else (t[0] if len(t) == 1 and t[0] > 0 else None)
        sc = {"id": sid, "duration": dur, "archived": ditched,
              "text": clean(r.get(ctext, "")) if ctext else "", "visual": clean(r.get(cimg, "")) if cimg else "",
              "feeling": clean(r.get(cfeel, "")) if cfeel else "", "handoff": clean(r.get(cgag, "")) if cgag else "",
              "inCuts": clean(r.get(ccut, "")) if ccut else "", "texts": {h: clean(r.get(h, "")) for h in xtext if r.get(h, "").strip()},
              "extra": {h: clean(r.get(h, "")) for h in head if h not in used and r.get(h, "").strip()},
              "status": "ditched" if ditched else "open", "note": ""}
        if sc["duration"] is None: del sc["duration"]
        out.append(sc)
        item = {"scene": sid, "enabled": not (ditched or off), "transition": {"type": "cut"}}
        if item["enabled"]:
            if len(t) > 1 and abs(t[0] - t0) > 0.001: item["start"] = t[0]; t0 = t[0]
            t0 += dur or 0
        items.append(item)
    return out, items

def deep(a, b):
    for k, v in b.items(): a[k] = deep(a[k], v) if isinstance(v, dict) and isinstance(a.get(k), dict) else v
    return a

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("project"); ap.add_argument("--facts"); ap.add_argument("--force", action="store_true"); ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args(); root = a.project; out = os.path.join(root, "showreel.json")
    if not os.path.isdir(root): sys.exit("no such folder: " + root)
    if os.path.isfile(out) and not a.force:
        try: old = json.load(open(out, encoding="utf-8"))
        except Exception: old = {}
        if (old.get("origin") or {}).get("tool") == "studio": sys.exit("showreel.json was written by Showreel Studio: not overwritten (use --force to replace it)")
    brief, style, sb = read(os.path.join(root, "brief.md")), read(os.path.join(root, "style-sheet.md")), read(os.path.join(root, "storyboard.md"))
    if not (brief or style or sb): sys.exit("nothing to export: no brief.md, style-sheet.md or storyboard.md in " + root)
    look = section(brief, "look"); pal = hexes(look) or hexes(style)
    d = {"palette": pal} if pal else {}
    f = {}
    t = grab(r"(?:titles?|headings?|headlines?|display)(?:\s+(?:font|type|face))?\s*[:=]\s*([A-Z][A-Za-z0-9 ]{1,40})", look + "\n" + style)
    b = grab(r"(?:body|text|copy)(?:\s+(?:font|type|face))?\s*[:=]\s*([A-Z][A-Za-z0-9 ]{1,40})", look + "\n" + style)
    if t: f["titles"] = t
    if b: f["text"] = b
    if f: d["fonts"] = f
    dur = grab(r"(?:duration|length)\s*[:=]\s*(\d+)\s*(?:s|sec|seconds)", brief)
    if dur: d["duration"] = float(dur)
    bp = os.path.join(root, "analysis", "beats.json")
    if os.path.isfile(bp):
        try:
            bj = json.load(open(bp, encoding="utf-8")); bpm = bj.get("bpm") or bj.get("tempo")
            if bpm: d["track"] = {"bpm": float(bpm)}
        except Exception: pass
    scenes, items = storyboard(sb)
    step = "storyboard" if scenes else "style" if style else "interview"
    doc = {"schema": 1, "name": os.path.basename(os.path.abspath(root)), "created": datetime.date.today().isoformat(), "step": step,
           "reelLanguages": languages(brief + "\n" + style), "parameters": {}, "decisions": d, "gates": {}, "scenes": scenes,
           "storyboards": [{"id": "main", "name": "Master", "items": items}],
           "origin": {"tool": "skill", "exportedAt": datetime.date.today().isoformat(), "files": [n for n, s in (("brief.md", brief), ("style-sheet.md", style), ("storyboard.md", sb)) if s]}}
    cl = grab(r"conversation\s+language\s*[:=]\s*([A-Za-z]+)", brief)
    if cl: doc["conversationLanguage"] = LANGS.get(cl.lower(), cl.lower() if len(cl) == 2 else None)
    if a.facts: deep(doc, json.load(open(a.facts, encoding="utf-8")))
    doc["schema"] = 1; doc.setdefault("origin", {})["tool"] = "skill"
    bad = [g for g in doc.get("gates", {}) if g not in GATES]
    if bad: sys.exit("unknown gate id(s): " + ", ".join(bad) + " (known: " + ", ".join(GATES) + ")")
    text = json.dumps(doc, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    if a.dry_run: print(text); return
    open(out, "w", encoding="utf-8").write(text)
    man = os.path.join(root, "assets", "MANIFEST.csv"); n = len(list(csv.DictReader(open(man, encoding="utf-8")))) if os.path.isfile(man) else 0
    print(f"wrote {out}: {len(scenes)} scenes, palette {len(pal)} colours, languages {', '.join(doc['reelLanguages']) or 'unknown'}, {n} assets stay in assets/MANIFEST.csv")
    missing = [k for k, v in (("palette", pal), ("fonts", f), ("scenes", scenes), ("reel languages", doc["reelLanguages"])) if not v]
    if missing: print("not found in the files (pass them with --facts if known): " + ", ".join(missing))

if __name__ == "__main__":
    main()
