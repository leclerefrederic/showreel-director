#!/usr/bin/env python3
"""Repository consistency checks. Exit code 1 if anything fails.

Usage: python3 tools/check.py [--fix]   (--fix regenerates the effects index and the sample lab, then re-checks)
Checks: SKILL.md frontmatter, Python and JS syntax, effects index and sample lab up to date, every file named in
SKILL.md exists, no accented or stray non-ASCII text in the skill's text files (English only), no caches or
.DS_Store, the .skill matches the folder byte for byte, demo harness has no real issues.
"""
import argparse, hashlib, os, re, subprocess, sys, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"; sys.dont_write_bytecode = True
import package

ROOT = package.ROOT; SK = os.path.join(ROOT, package.SKILL); fails = []; notes = []

def ok(msg): print("  ok   " + msg)
def bad(msg): fails.append(msg); print("  FAIL " + msg)
def run(cmd, **kw): return subprocess.run(cmd, capture_output=True, text=True, **kw)

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--fix", action="store_true"); a = ap.parse_args()
    if a.fix:
        run([sys.executable, os.path.join(SK, "scripts", "export_effects_index.py")])
        run([sys.executable, os.path.join(SK, "scripts", "build_effects_lab.py"), "--out", os.path.join(SK, "engine", "effects-lab-sample.html")])
        print("regenerated effects index and sample lab")
    # frontmatter
    s = open(os.path.join(SK, "SKILL.md"), encoding="utf-8").read()
    m = re.match(r"---\nname: \"?([\w-]+)\"?\ndescription: \"(.+)\"\n---\n", s, re.S)
    if m and m.group(1) == package.SKILL and 100 < len(m.group(2)) <= 1024: ok("SKILL.md frontmatter (description %d of 1024 characters)" % len(m.group(2)))
    else: bad("SKILL.md frontmatter (name must be showreel-director, description present and at most 1024 characters)")
    # files named in SKILL.md
    names = set(re.findall(r"`((?:references|engine|scripts|demo)/[\w./-]+)`", s))
    missing = sorted(n for n in names if not os.path.exists(os.path.join(SK, n)) and "<" not in n and "*" not in n and not n.startswith("demo/"))  # demo/ is optional, outside the package
    ok(f"{len(names)} files named in SKILL.md exist") if not missing else bad("named in SKILL.md but missing: " + ", ".join(missing))
    # cross-references between SKILL.md, references and scripts
    refs = os.path.join(SK, "references"); texts = {f: open(os.path.join(refs, f), encoding="utf-8").read() for f in sorted(os.listdir(refs)) if f.endswith(".md")}
    texts["SKILL.md"] = s; allnamed = set(); broken = []
    for f, t in texts.items():
        for n in re.findall(r"`((?:references|engine|scripts)/[\w./-]+)`", t):
            allnamed.add(n)
            if "<" in n or "*" in n or n.endswith("/"): continue
            if not os.path.exists(os.path.join(SK, n)): broken.append(f + " -> " + n)
    ok("every file named in the references exists") if not broken else bad("broken references: " + "; ".join(broken[:6]))
    orphan = [f for f in texts if f != "SKILL.md" and "references/" + f not in s]
    ok("every reference file is linked from SKILL.md") if not orphan else bad("reference not linked from SKILL.md: " + ", ".join(orphan))
    docs = s + texts.get("engine.md", "")
    unused = [f for f in sorted(os.listdir(os.path.join(SK, "scripts"))) if f.endswith((".py", ".js")) and "scripts/" + f not in docs]  # helpers (_name) are documented as a group
    ok("every script is documented in SKILL.md or engine.md") if not unused else bad("script not documented: " + ", ".join(unused))
    rules = []
    if "Gates (guardrails)" not in s: rules.append("gates table missing in SKILL.md")
    for h in ("Step 0", "Step 1", "Step 2", "Step 2b", "Step 3", "Step 4", "Step 5", "Step 6"):
        if "## " + h + " " not in s: rules.append("heading missing: " + h)
    if "never skipped" not in s: rules.append("express mode must state what is never skipped")
    if "replace rounds 1" in texts.get("interview.md", ""): rules.append("interview.md redefines express mode (single definition lives in SKILL.md)")
    if "Not for PowerPoint" not in s.split("---")[1]: rules.append("description should say it is not for PowerPoint decks")
    if "Untrusted content" not in s: rules.append("untrusted-content rule missing")
    if len(s) > 32000: rules.append("SKILL.md over 32 KB: move detail to references")
    ok("process rules present (gates, steps, express, untrusted content, description)") if not rules else bad("; ".join(rules))
    # effect names used in the catalogue (tables and packs) must exist in the generated index, so the user can find them in the lab
    idxs = open(os.path.join(SK, "references", "effects-index.md"), encoding="utf-8").read()
    names = {m.group(1).strip().lower() for m in re.finditer(r"^\| ([^|]+) \|", idxs, re.M)}
    cat = open(os.path.join(SK, "references", "effects-catalogue.md"), encoding="utf-8").read(); miss = []; cl = cat.splitlines(); i = 0
    while i < len(cl):
        if cl[i].startswith("| Effect |"):
            j = i + 2
            while j < len(cl) and cl[j].startswith("|"):
                n = cl[j].split("|")[1].strip()
                if n.lower() not in names: miss.append(n)
                j += 1
            i = j
        else: i += 1
    pk = re.search(r"## Packs.*?\n\n", cat, re.S)
    for ln in (pk.group(0).splitlines()[3:] if pk else []):
        if ln.startswith("|"):
            for e in re.sub(r"\([^)]*\)", "", ln.split("|")[3]).split(","):
                if e.strip().lower() not in names: miss.append(e.strip())
    ok("effect names in the catalogue and packs all exist in the effects index") if not miss else bad("catalogue names missing from the index: " + ", ".join(sorted(set(miss))[:8]))
    # build self-test: a project with an embedded image and a duration shorter than nothing builds, passes the guard and the harness
    import base64 as _b64, tempfile, json as _json, shutil as _sh
    td = tempfile.mkdtemp()
    bp = os.path.join(td, "bp"); os.makedirs(os.path.join(bp, "v1")); os.makedirs(os.path.join(bp, "assets", "prepared"))
    png = _b64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
    open(os.path.join(bp, "assets", "prepared", "shot-01-pixel.png"), "wb").write(png)
    _json.dump({"title": "T", "main": "main.js", "duration": 6, "fonts": [], "tokens": {}, "images": {"shot-01": "../assets/prepared/shot-01-pixel.png"}}, open(os.path.join(bp, "v1", "project.json"), "w"))
    _sh.copy(os.path.join(SK, "engine", "main.template.js"), os.path.join(bp, "v1", "main.js"))
    rb = run([sys.executable, os.path.join(SK, "scripts", "build.py"), os.path.join(bp, "v1")]); built = os.path.join(bp, "v1", "dist", "index.html")
    rh = run(["node", os.path.join(SK, "scripts", "harness.js"), built, "--step", "0.5"]) if os.path.exists(built) else None
    _json.dump({"title": "T", "main": "main.js", "duration": 6, "fonts": [], "tokens": {}, "images": {"shot-01": "../assets/source/x.png"}}, open(os.path.join(bp, "v1", "project.json"), "w"))
    rg = run([sys.executable, os.path.join(SK, "scripts", "build.py"), os.path.join(bp, "v1")])
    # a project with a track must carry it (regression guard): tiny silent mp3 made with ffmpeg when available
    trk_ok = True
    if _sh.which("ffmpeg"):
        tp2 = os.path.join(td, "tp"); os.makedirs(os.path.join(tp2, "v1")); os.makedirs(os.path.join(tp2, "assets", "prepared")); os.makedirs(os.path.join(tp2, "analysis"))
        mp3 = os.path.join(tp2, "assets", "prepared", "audio-01-test.mp3")
        run(["ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", "sine=frequency=110:duration=6", mp3])
        run([sys.executable, os.path.join(SK, "scripts", "analyze_audio.py"), mp3, "--out", os.path.join(tp2, "analysis")])
        _json.dump({"title": "T", "main": "main.js", "track": "../assets/prepared/audio-01-test.mp3", "analysis_dir": "../analysis", "duration": 5, "fonts": [], "tokens": {}}, open(os.path.join(tp2, "v1", "project.json"), "w"))
        _sh.copy(os.path.join(SK, "engine", "main.template.js"), os.path.join(tp2, "v1", "main.js"))
        rt = run([sys.executable, os.path.join(SK, "scripts", "build.py"), os.path.join(tp2, "v1")]); out2 = os.path.join(tp2, "v1", "dist", "index.html")
        trk_ok = rt.returncode == 0 and os.path.exists(out2) and 'id="trackdata"' in open(out2, encoding="utf-8").read()
    good = trk_ok and rb.returncode == 0 and rh is not None and rh.returncode == 0 and '"images"' in open(built, encoding="utf-8").read() and rg.returncode != 0
    ok("build self-test: track and image embedded, harness passes, guard refuses assets/source") if good else bad("build self-test failed: " + (rb.stdout + rb.stderr + (rh.stdout if rh else ""))[-300:])
    # tools self-test: decision sheet builder accepts a good spec and refuses a bad one; scene cards build
    import tempfile, json as _json
    td = tempfile.mkdtemp(); good = os.path.join(td, "g.json"); badf = os.path.join(td, "b.json")
    _json.dump({"title": "T", "items": [{"id": "a", "title": "A", "options": [{"label": "x", "recommended": True}, {"label": "y"}]}]}, open(good, "w"))
    _json.dump({"title": "T", "items": [{"id": "a", "title": "A", "options": [{"label": "x"}]}]}, open(badf, "w"))
    r1 = run([sys.executable, os.path.join(SK, "scripts", "build_decision_sheet.py"), good, "--out", os.path.join(td, "o.html")])
    r2 = run([sys.executable, os.path.join(SK, "scripts", "build_decision_sheet.py"), badf, "--out", os.path.join(td, "o2.html")])
    ok("decision sheet builder: good spec builds, bad spec refused") if r1.returncode == 0 and r2.returncode != 0 else bad("decision sheet builder self-test failed")
    # organiser self-test on the eval assets: plan, apply, held files, check
    import shutil as _sh
    pj = os.path.join(td, "proj"); fx = os.path.join(SK, "evals", "ploma-full-interview", "files", "assets")
    if os.path.isdir(fx):
        _sh.copytree(fx, os.path.join(pj, "assets")); org = [sys.executable, os.path.join(SK, "scripts", "organize_assets.py"), pj]
        r1 = run(org + ["--apply"]); r2 = run(org + ["--check", "--allow-hold"]); man = open(os.path.join(pj, "assets", "MANIFEST.csv")).read()
        held = man.count(",hold,"); r3 = run(org + ["--set", "shot-04=approved"])
        good = r1.returncode == 0 and r2.returncode == 0 and held >= 3 and r3.returncode != 0 and not os.path.exists(os.path.join(pj, "assets", "prepared", "shot-04-screen-customers.png"))
        ok("asset organiser: typed names, held files stay held, check passes") if good else bad("asset organiser self-test failed: " + (r1.stdout + r1.stderr + r2.stdout)[-300:])
    sb = os.path.join(SK, "evals", "scene-by-scene-review", "files", "storyboard.md")
    if os.path.exists(sb):
        r3 = run([sys.executable, os.path.join(SK, "scripts", "build_scene_cards.py"), sb, "--out", os.path.join(td, "c.html")])
        ok("scene cards build from the eval storyboard") if r3.returncode == 0 else bad("scene cards failed on the eval storyboard: " + r3.stderr[-200:])
    # syntax
    for f in package.skill_files():
        if f.endswith(".py"):
            r = run([sys.executable, "-c", "import ast,sys;ast.parse(open(sys.argv[1],encoding='utf-8').read())", f])
            if r.returncode: bad("python syntax " + os.path.relpath(f, ROOT))
        elif f.endswith(".js"):
            r = run(["node", "--check", f])
            if r.returncode: bad("js syntax " + os.path.relpath(f, ROOT))
    if not fails: ok("python and js syntax")
    # effects index and lab
    idx = os.path.join(SK, "references", "effects-index.md"); before = open(idx, encoding="utf-8").read()
    run([sys.executable, os.path.join(SK, "scripts", "export_effects_index.py")]); after = open(idx, encoding="utf-8").read()
    if before == after: ok("effects index up to date")
    else: open(idx, "w", encoding="utf-8").write(before); bad("effects index out of date (run: python3 tools/check.py --fix)")
    tmp = os.path.join(ROOT, ".lab-check.html")
    run([sys.executable, os.path.join(SK, "scripts", "build_effects_lab.py"), "--out", tmp])
    lab = os.path.join(SK, "engine", "effects-lab-sample.html")
    same = os.path.exists(tmp) and open(tmp, "rb").read() == open(lab, "rb").read()
    if os.path.exists(tmp): os.remove(tmp)
    ok("sample lab up to date") if same else bad("sample lab out of date (run: python3 tools/check.py --fix)")
    # language and junk
    junk, nonascii = [], []
    for r, dirs, files in os.walk(SK):
        dirs[:] = [d for d in dirs if d != "node_modules"]
        if "__pycache__" in r.split(os.sep): junk.append(r)
        for f in files:
            p = os.path.join(r, f); rel = os.path.relpath(p, ROOT)
            if f == ".DS_Store" or f.endswith(".pyc"): junk.append(rel)
            if f.endswith((".md", ".py", ".js", ".json", ".yaml", ".txt", ".csv")) and "evals" + os.sep + "ploma" not in rel:
                t = open(p, encoding="utf-8", errors="ignore").read()
                if re.search("[\u00c0-\u00d6\u00d8-\u00f6\u00f8-\u00ff]", t): nonascii.append(rel)
    ok("no cache or .DS_Store files in the skill") if not junk else bad("junk: " + ", ".join(junk[:5]))
    ok("no accented text in skill text files (English only)") if not nonascii else bad("accented text in: " + ", ".join(nonascii[:8]))
    # package
    pk = os.path.join(ROOT, package.SKILL + ".skill")
    if not os.path.exists(pk): bad(".skill missing (run: python3 tools/package.py)")
    else:
        z = zipfile.ZipFile(pk); inzip = {n: z.read(n) for n in z.namelist()}
        disk = {os.path.relpath(f, ROOT): open(f, "rb").read() for f in package.skill_files()}
        if set(inzip) != set(disk): bad(".skill file list differs from the folder: " + ", ".join(sorted(set(inzip) ^ set(disk))[:6]))
        elif any(hashlib.md5(inzip[n]).digest() != hashlib.md5(disk[n]).digest() for n in disk): bad(".skill content differs from the folder (run: python3 tools/package.py)")
        else: ok(f".skill identical to the folder ({len(disk)} files)")
    # demo harness
    demo = os.path.join(ROOT, "demo", "showreel-director-demo.html")
    if os.path.exists(demo):
        r = run(["node", os.path.join(SK, "scripts", "harness.js"), demo, "--step", "0.5"])
        line = next((l for l in r.stdout.splitlines() if l.startswith("issues:")), "issues: ?")
        ok("demo harness " + line) if line == "issues: 0" else bad("demo harness " + line)
    print("\n" + ("all checks passed" if not fails else f"{len(fails)} check(s) failed"))
    sys.exit(1 if fails else 0)

if __name__ == "__main__":
    main()
