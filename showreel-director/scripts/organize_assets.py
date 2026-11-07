#!/usr/bin/env python3
"""Put every asset of a project in one predictable place, with a typed name, and keep a manifest.

Layout (inside <project>/assets/):
  source/      originals as received, original names, never modified, never read by the build
  prepared/    supplied files made ready to embed (copied, converted, resized, redacted), convention names
  generated/   everything the skill makes itself (procedural images, frame sequences, rendered icons, synthetic voice)
  MANIFEST.csv one row per file: id, file, original, origin, type, status, licence_note, scene, notes

Naming convention for prepared/ and generated/:   <type>-<nn>-<slug>[_<variant>].<ext>
  type     logo icon shot photo illus img font audio voice sfx video frames
  nn       two digits, counted per type, never reused (a removed asset keeps its number in the manifest)
  slug     lowercase ascii words joined by hyphens, what it is (ploma-clair, customers-list, poppins-bold)
  variant  optional, after an underscore: dark, light, redacted, 2x, fr ...
  examples logo-01-ploma-clair.svg  shot-04-customers-list_redacted.png  font-02-poppins-bold.ttf  audio-01-track-124bpm.mp3
Files that are not embedded (data, notes, brand guides, licences) stay in source/ and are only listed with their type.

Usage:
  python3 organize_assets.py PROJECT                  plan: show what would be done (default, changes nothing)
  python3 organize_assets.py PROJECT --apply          do it (files already loose in assets/ are moved into source/, files from --from are copied)
  python3 organize_assets.py PROJECT --from DIR       take supplied files from DIR (uploads folder, connected folder)
  python3 organize_assets.py PROJECT --set logo-01=approved,shot-04=excluded     record decisions (status: proposed approved excluded placeholder hold)
  python3 organize_assets.py PROJECT --redacted shot-04=PATH     add a redacted copy (pixels painted over) of a held sensitive file; then approve it with --set
  python3 organize_assets.py PROJECT --register                  add the files the skill put in generated/ to the manifest (names must follow the convention)
  python3 organize_assets.py PROJECT --md             print the manifest as a Markdown table for brief.md
  python3 organize_assets.py PROJECT --check          verify names, manifest, stray files, held files and version paths (tracks, fonts, images); exit 1 on problems
                                                      (--allow-hold while decisions are still being taken)
Files that look sensitive (real customer data, secrets) or whose licence note forbids use are recorded as `hold`: they are
kept in source/ and NOT copied to prepared/ until the user decides. Originals' contents are never changed.
"""
import argparse, csv, json, os, re, shutil, sys, unicodedata
sys.dont_write_bytecode = True  # no __pycache__ inside the skill folder
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    from audit_assets import probe
except Exception:
    probe = None

EMBED = {"logo", "icon", "shot", "photo", "illus", "img", "font", "audio", "voice", "sfx", "video", "frames"}
NAME = re.compile(r"^(logo|icon|shot|photo|illus|img|font|audio|voice|sfx|video|frames)-(\d{2})-([a-z0-9]+(?:-[a-z0-9]+)*)(?:_([a-z0-9]+(?:-[a-z0-9]+)*))?(\.[a-z0-9]+)?$")
SENSITIVE = re.compile(r"real[-_ ]?data|customer|client|personal|confidential|internal|secret|password|api[-_]?key|token", re.I)
NOTE_FILE = re.compile(r"licen|consent|info|readme|rights|notice", re.I)
COLS = ["id", "file", "original", "origin", "type", "status", "licence_note", "scene", "notes"]
STATUS = {"proposed", "approved", "excluded", "placeholder", "hold"}
ORIGINS = ("source", "prepared", "generated")

def classify(rel):
    f = os.path.basename(rel).lower(); ext = f.rsplit(".", 1)[-1] if "." in f else ""; d = rel.lower()
    if ext in ("ttf", "otf", "woff", "woff2"): return "font"
    if ext in ("mp3", "wav", "m4a", "ogg", "flac"): return "voice" if re.search(r"voice|narrat|\bvo\b", f) else "sfx" if "sfx" in f else "audio"
    if ext in ("mp4", "mov", "webm"): return "video"
    if ext in ("png", "jpg", "jpeg", "webp", "gif", "svg"):
        if "logo" in f: return "logo"
        if "icon" in f: return "icon"
        if re.search(r"screen|shot|\bui\b|app[-_]", f) or re.search(r"(^|/)(product|screens?|ui)/", d): return "shot"
        if ext in ("jpg", "jpeg") or re.search(r"(^|/)photos?/", d): return "photo"
        if ext == "svg": return "illus"
        return "img"
    if ext in ("md", "txt", "pdf", "docx"): return "note" if NOTE_FILE.search(f) else "doc"
    if ext in ("csv", "json", "xlsx"): return "data"
    return "misc"

def slugify(rel, typ):
    base = os.path.splitext(os.path.basename(rel))[0]
    base = unicodedata.normalize("NFKD", base).encode("ascii", "ignore").decode().lower()
    base = re.sub(r"(real[-_ ]?data)", "", base)
    words = [w for w in re.split(r"[^a-z0-9]+", base) if w and w != typ and not re.fullmatch(r"\d{1,2}", w)]
    s = "-".join(words)[:40].strip("-")
    return s or "untitled"

def load(man):
    if not os.path.exists(man): return []
    with open(man, newline="", encoding="utf-8") as fh: return list(csv.DictReader(fh))

def save(man, rows):
    with open(man, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=COLS); w.writeheader()
        for r in rows: w.writerow({c: r.get(c, "") for c in COLS})

def note_text(dirpath, fname):
    toks = set(re.findall(r"[a-z]{4,}", re.sub(r"\.[a-z0-9]+$", "", fname.lower()))); notes = []
    for f in sorted(os.listdir(dirpath)):
        if NOTE_FILE.search(f) and f.lower().endswith((".txt", ".md")):
            notes.append((f, open(os.path.join(dirpath, f), errors="ignore").read()[:800]))
    pick = [n for n in notes if toks & set(re.findall(r"[a-z]{4,}", n[0].lower()))] or notes
    return pick

def scan(root, assets, extra):
    """Files to organise: loose in assets/ (outside source, prepared, generated) plus those under the --from folder."""
    found = []
    def walk(base, loose):
        for r, dirs, fs in os.walk(base):
            rel_r = os.path.relpath(r, assets)
            if loose and (rel_r.split(os.sep)[0] in ORIGINS):
                dirs[:] = []; continue
            for f in sorted(fs):
                if f.startswith(".") or f == "MANIFEST.csv": continue
                if loose and rel_r == "." and f == "MANIFEST.csv": continue
                found.append((os.path.join(r, f), os.path.relpath(os.path.join(r, f), base), loose))
    if os.path.isdir(assets): walk(assets, True)
    if extra: walk(extra, False)
    return found

def plan(root, extra):
    assets = os.path.join(root, "assets"); rows = load(os.path.join(assets, "MANIFEST.csv")); known = {r["original"] for r in rows}
    counters = {}
    for r in rows:
        m = NAME.match(os.path.basename(r["file"])) if r["file"] else re.match(r"^([a-z]+)-(\d{2})$", r["id"])
        t, n = (m.group(1), int(m.group(2))) if m else (None, 0)
        if t: counters[t] = max(counters.get(t, 0), n)
    items = []
    for path, rel, loose in sorted(scan(root, assets, extra), key=lambda x: x[1]):
        if rel in known: continue
        typ = classify(rel); status = "proposed"; reason = ""
        if typ in EMBED:
            notes = note_text(os.path.dirname(path), os.path.basename(path)); txt = " ".join(t for _, t in notes)
            if SENSITIVE.search(os.path.basename(rel)): status, reason = "hold", "name suggests real or confidential data: decide first"
            elif typ == "font" and re.search(r"proprietary|forbidden|not allowed|desktop only|workstation", txt, re.I): status, reason = "hold", "font licence forbids embedding"
            elif typ != "font" and re.search(r"not confirmed|unconfirmed|unknown", txt, re.I): status, reason = "hold", "rights or consent not confirmed"
            elif typ in ("logo", "shot", "photo", "img") and probe and path.lower().endswith((".png", ".jpg", ".jpeg", ".webp")) and (lambda d: d[1] and (d[1] < 800 or d[2] < 450))(probe(path)) and typ != "logo":
                status, reason = "hold", "low resolution (under 800x450): replace, accept or exclude"
            elif typ == "logo" and probe and path.lower().endswith((".png", ".jpg", ".jpeg", ".webp")) and (lambda d: d[1] and d[1] < 200)(probe(path)):
                status, reason = "hold", "logo bitmap is small: use a vector version, or accept or exclude"
            elif typ == "video" and os.path.getsize(path) > 5e6: status, reason = "hold", "heavy video: the canvas cannot seek video exactly; stills or frames are better"
            elif typ in ("audio", "voice", "sfx") and os.path.getsize(path) > 8e6: status, reason = "hold", "heavy audio file: check the weight budget"

            counters[typ] = counters.get(typ, 0) + 1
            nm = f"{typ}-{counters[typ]:02d}-{slugify(rel, typ)}" + os.path.splitext(path)[1].lower()
            items.append(dict(src=path, rel=rel, loose=loose, type=typ, id=f"{typ}-{counters[typ]:02d}", name=nm, status=status, reason=reason,
                              note=notes[0][0] if notes else ""))
        else:
            items.append(dict(src=path, rel=rel, loose=loose, type=typ, id="", name="", status="source-only", reason="not embedded", note=""))
    return assets, rows, items

def cmd_plan(a, apply):
    assets, rows, items = plan(a.project, a.src)
    if not items: print("nothing new to organise"); return 0
    print(f"{'id':10s}{'original':44s} {'type':6s} {'-> prepared name':48s} status")
    for it in items:
        print(f"{(it['id'] or '-'):10s}{it['rel'][:44]:44s} {it['type']:6s} {(('prepared/' + it['name']) if it['name'] and it['status'] != 'hold' else '(source only)')[:48]:48s} {it['status']}" + (f"  ({it['reason']})" if it["reason"] else ""))
    clash = [it["name"] for it in items if it["name"] and it["status"] != "hold" and os.path.exists(os.path.join(assets, "prepared", it["name"]))]
    if clash: print("name already exists, aborting: " + ", ".join(clash)); return 1
    if not apply: print("\nplan only. Run again with --apply to do it."); return 0
    for d in ORIGINS: os.makedirs(os.path.join(assets, d), exist_ok=True)
    for it in items:
        dst = os.path.join(assets, "source", it["rel"]); os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst):
            (shutil.move if it["loose"] else shutil.copy2)(it["src"], dst)
        if it["name"] and it["status"] != "hold":
            shutil.copy2(dst, os.path.join(assets, "prepared", it["name"]))
        if it["id"]:
            rows.append(dict(id=it["id"], file=("prepared/" + it["name"]) if it["status"] != "hold" else "", original=it["rel"], origin="prepared" if it["status"] != "hold" else "source",
                             type=it["type"], status=it["status"], licence_note=it["note"], scene="", notes=it["reason"]))
    for d in sorted(os.listdir(assets)):  # loose folders emptied by the move are removed (only empty ones)
        dp = os.path.join(assets, d)
        if d not in ORIGINS and os.path.isdir(dp):
            for r, _, _ in sorted(os.walk(dp), reverse=True):
                try: os.rmdir(r)
                except OSError: pass
    save(os.path.join(assets, "MANIFEST.csv"), rows)
    print(f"\ndone: {len(items)} files; manifest has {len(rows)} rows. Held files stay in source/ until you decide (--set ID=approved or excluded).")
    return 0

def cmd_set(a):
    man = os.path.join(a.project, "assets", "MANIFEST.csv"); rows = load(man); ok = True
    for pair in a.set.split(","):
        i, _, st = pair.partition("=")
        if st not in STATUS: print(f"bad status in {pair!r} (use: {', '.join(sorted(STATUS))})"); ok = False; continue
        r = next((x for x in rows if x["id"] == i), None)
        if not r: print(f"unknown id {i}"); ok = False; continue
        if r["status"] == "hold" and st == "approved" and "name suggests" in r["notes"]:
            print(f"{i}: looks like real or confidential data; paint over the sensitive parts in a copy, then run --redacted {i}=PATH_TO_REDACTED_FILE"); ok = False; continue
        if r["status"] == "hold" and st == "approved" and not r["file"]:
            src = os.path.join(a.project, "assets", "source", r["original"]); t = r["type"]
            nm = f"{t}-{i.split('-')[1]}-{slugify(r['original'], t)}" + os.path.splitext(src)[1].lower()
            os.makedirs(os.path.join(a.project, "assets", "prepared"), exist_ok=True); shutil.copy2(src, os.path.join(a.project, "assets", "prepared", nm)); r["file"] = "prepared/" + nm; r["origin"] = "prepared"
        if st == "excluded" and r["file"].startswith("prepared/"):  # an excluded asset must not stay in prepared/ (our copy only; the original is untouched)
            fp = os.path.join(a.project, "assets", r["file"])
            if os.path.exists(fp): os.remove(fp)
            r["file"] = ""; r["origin"] = "source"
        r["status"] = st
    save(man, rows); print("manifest updated" if ok else "manifest updated for the valid entries"); return 0 if ok else 1

def cmd_redacted(a):
    i, _, path = a.redacted.partition("=")
    man = os.path.join(a.project, "assets", "MANIFEST.csv"); rows = load(man); r = next((x for x in rows if x["id"] == i), None)
    if not r or not os.path.isfile(path): print("unknown id or file not found"); return 1
    t = r["type"]; nm = f"{t}-{i.split('-')[1]}-{slugify(r['original'], t)}_redacted" + os.path.splitext(path)[1].lower()
    os.makedirs(os.path.join(a.project, "assets", "prepared"), exist_ok=True); shutil.copy2(path, os.path.join(a.project, "assets", "prepared", nm))
    r["file"] = "prepared/" + nm; r["origin"] = "prepared"; r["status"] = "proposed"; r["notes"] = "redacted copy; check the pixels before approving"
    save(man, rows); print(f"{nm} added; open it, check that nothing sensitive is left, then --set {i}=approved"); return 0

def cmd_register(a):
    assets = os.path.join(a.project, "assets"); man = os.path.join(assets, "MANIFEST.csv"); rows = load(man); known = {r["file"] for r in rows}; added = 0; bad = []
    gd = os.path.join(assets, "generated")
    for f in sorted(os.listdir(gd)) if os.path.isdir(gd) else []:
        if f.startswith(".") or f"generated/{f}" in known: continue
        m = NAME.match(f)
        if not m: bad.append(f"generated/{f}: rename to <type>-<nn>-<slug>[_<variant>] first"); continue
        rows.append(dict(id=f"{m.group(1)}-{m.group(2)}", file=f"generated/{f}", original="", origin="generated", type=m.group(1), status="proposed", licence_note="", scene="", notes="made by the skill")); added += 1
    ids = [r["id"] for r in rows]
    if len(ids) != len(set(ids)): bad.append("an id is used twice: pick the next free number for the new file")
    if bad: print("\n".join("  FAIL " + b for b in bad)); return 1
    save(man, rows); print(f"{added} generated file(s) registered"); return 0

def cmd_md(a):
    rows = load(os.path.join(a.project, "assets", "MANIFEST.csv"))
    print("| id | file | original | origin | status | licence note | scene |\n|---|---|---|---|---|---|---|")
    for r in rows: print(f"| {r['id']} | {r['file'] or '-'} | {r['original']} | {r['origin']} | {r['status']} | {r['licence_note'] or '-'} | {r['scene'] or '-'} |")
    return 0

def cmd_check(a):
    assets = os.path.join(a.project, "assets"); rows = load(os.path.join(assets, "MANIFEST.csv")); bad = []
    ids = [r["id"] for r in rows]
    if len(ids) != len(set(ids)): bad.append("duplicate ids in MANIFEST.csv")
    listed = {r["file"] for r in rows if r["file"]}
    for d in ("prepared", "generated"):
        p = os.path.join(assets, d)
        if not os.path.isdir(p): continue
        for f in sorted(os.listdir(p)):
            if f.startswith("."): continue
            if not NAME.match(f): bad.append(f"{d}/{f}: name does not follow <type>-<nn>-<slug>[_<variant>]")
            if f"{d}/{f}" not in listed: bad.append(f"{d}/{f}: not in MANIFEST.csv")
    for r in rows:
        if r["status"] == "hold" and not a.allow_hold: bad.append(f"{r['id']} ({r['original'] or r['file']}) is still on hold: decide it (--set {r['id']}=approved or excluded)")
        if r["status"] == "excluded" and r["file"]: bad.append(f"{r['id']}: excluded but still in {r['file']}")
        if r["status"] == "placeholder": print(f"  note: {r['id']} is a placeholder: it must be listed in the release gate of brief.md")
        if r["file"] and not os.path.exists(os.path.join(assets, r["file"])): bad.append(f"{r['file']}: listed but missing")
        if r["status"] not in STATUS: bad.append(f"{r['id']}: bad status {r['status']!r}")
    if os.path.isdir(assets):
        for f in sorted(os.listdir(assets)):
            if f not in ORIGINS and f != "MANIFEST.csv" and not f.startswith("."): bad.append(f"assets/{f}: stray, run the organiser (plan, then --apply)")
    for v in sorted(os.listdir(a.project)) if os.path.isdir(a.project) else []:
        pj = os.path.join(a.project, v, "project.json")
        if re.fullmatch(r"v\d+", v) and os.path.exists(pj):
            cfg = json.load(open(pj))
            paths = [cfg.get("track")] + [x.get("path") for x in cfg.get("fonts", [])] + list((cfg.get("images") or {}).values())
            for p in filter(None, paths):
                if "/source/" in p.replace("\\", "/") or ("assets/" in p and not re.search(r"assets/(prepared|generated)/", p)):
                    bad.append(f"{v}/project.json: {p} must point to assets/prepared or assets/generated")
    print("\n".join("  FAIL " + b for b in bad) if bad else "assets OK: names, manifest, layout and version paths")
    return 1 if bad else 0

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("project"); ap.add_argument("--from", dest="src"); ap.add_argument("--apply", action="store_true")
    ap.add_argument("--set"); ap.add_argument("--register", action="store_true"); ap.add_argument("--redacted"); ap.add_argument("--md", action="store_true"); ap.add_argument("--check", action="store_true"); ap.add_argument("--allow-hold", action="store_true")
    a = ap.parse_args()
    if not os.path.isdir(a.project): sys.exit("project folder not found")
    if a.check: sys.exit(cmd_check(a))
    if a.register: sys.exit(cmd_register(a))
    if a.redacted: sys.exit(cmd_redacted(a))
    if a.md: sys.exit(cmd_md(a))
    if a.set: sys.exit(cmd_set(a))
    sys.exit(cmd_plan(a, a.apply))

if __name__ == "__main__":
    main()
