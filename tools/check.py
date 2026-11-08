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
    try: import numpy  # the track test needs numpy and ffmpeg; without numpy it is skipped (CI installs both)
    except ImportError: numpy = None
    if _sh.which("ffmpeg") and numpy:
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
    # font picker and guided lab: the curated list is well formed, both pages build, the lab opens on the moods
    fl = _json.load(open(os.path.join(SK, "engine", "fonts-free.json"), encoding="utf-8")); fnames = [x["name"] for x in fl]
    flist_ok = len(fnames) == len(set(fnames)) and all(x.get("dir") and x.get("cat") and x.get("moods") and x.get("note") for x in fl)
    rp = run([sys.executable, os.path.join(SK, "scripts", "build_font_picker.py"), "--out", os.path.join(td, "fp.html")])
    rl = run([sys.executable, os.path.join(SK, "scripts", "build_effects_lab.py"), "--out", os.path.join(td, "lab.html")])
    lab_ok = rl.returncode == 0 and "const GUIDED=true" in open(os.path.join(td, "lab.html"), encoding="utf-8").read() and '"effects": [' in open(os.path.join(td, "lab.html"), encoding="utf-8").read()
    ok("font picker builds from a well-formed curated list; effects lab opens on the moods") if flist_ok and rp.returncode == 0 and lab_ok else bad("font picker or guided lab self-test failed: " + (rp.stderr + rl.stderr)[-200:])
    lj = os.path.join(td, "look.json")
    pk = lambda i, bgc, f1, f2, pack: {"id": i, "name": "N" + i, "palette": {"bg": bgc, "fg": "#ffffff", "accent": "#ff0000"}, "background": "solid", "fonts": {"titles": f1, "text": f2}, "effects_pack": pack}
    _json.dump({"message": "Hello", "packages": [pk("A", "#000000", "Poppins", "Inter", "Deadpan"), pk("B", "#112233", "Lora", "Inter", "Cinematic")]}, open(lj, "w"))
    rb1 = run([sys.executable, os.path.join(SK, "scripts", "build_look_board.py"), lj, "--out", os.path.join(td, "lb.html")])
    _json.dump({"message": "Hello", "packages": [pk("A", "#000000", "Poppins", "Inter", "Deadpan"), pk("B", "#000000", "Poppins", "Inter", "Nope")]}, open(lj, "w"))
    rb2 = run([sys.executable, os.path.join(SK, "scripts", "build_look_board.py"), lj, "--out", os.path.join(td, "lb2.html")])
    ok("look board: good spec builds, unknown effects mood refused") if rb1.returncode == 0 and rb2.returncode != 0 else bad("look board self-test failed: " + (rb1.stdout + rb1.stderr + rb2.stdout)[-200:])
    # backgrounds: every one draws (normal and reduced) with a stub canvas, the picker builds, build.py inlines the library only when main.js uses SRB
    stub = "const g=new Proxy({},{get:(t,k)=>k in t?t[k]:(/Gradient|Pattern/.test(String(k))?()=>({addColorStop(){}}):()=>undefined),set:(t,k,v)=>(t[k]=v,true)});"
    js = "global.window={};eval(require('fs').readFileSync(process.argv[1],'utf8'));const SRB=window.SRB;" + stub + "const p={bg:'#101010',fg:'#ffffff',accent:'#ff0000',accent2:'#0000ff'};for(const b of SRB.list){SRB.draw(b.id,g,640,360,2.5,p,{});SRB.draw(b.id,g,640,360,2.5,p,{reduced:true})}console.log(SRB.list.length);"
    rbg = run(["node", "-e", js, os.path.join(SK, "engine", "backgrounds.js")])
    rpk = run([sys.executable, os.path.join(SK, "scripts", "build_background_picker.py"), "--out", os.path.join(td, "bgp.html")])
    ids = re.findall(r"add\('([a-z0-9-]+)',", open(os.path.join(SK, "engine", "backgrounds.js"), encoding="utf-8").read())
    mj = os.path.join(bp, "v1", "main.js"); orig = open(mj).read(); open(mj, "a").write("\n// a comment mentioning SRB does not count\nwindow.__bgtest = typeof SRB;\n")
    _json.dump({"title": "T", "main": "main.js", "duration": 6, "fonts": [], "tokens": {}}, open(os.path.join(bp, "v1", "project.json"), "w"))
    run([sys.executable, os.path.join(SK, "scripts", "build.py"), os.path.join(bp, "v1")]); with_bg = "SRB.sequence = function" in open(built, encoding="utf-8").read()
    open(mj, "w").write(orig); run([sys.executable, os.path.join(SK, "scripts", "build.py"), os.path.join(bp, "v1")]); without_bg = "SRB.sequence = function" not in open(built, encoding="utf-8").read()
    ok("backgrounds: all %s draw (normal and reduced), picker builds, library inlined only when used" % len(ids)) if rbg.returncode == 0 and rbg.stdout.strip() == str(len(ids)) and rpk.returncode == 0 and with_bg and without_bg else bad("backgrounds self-test failed: " + (rbg.stderr + rpk.stderr)[-250:] + f" inlined={with_bg}/{without_bg}")
    # music guard rails: reactions are finite at extreme signals, react only with music signals, never in reduced motion; SR.signals is null without music, muted or reduced
    rj = os.path.join(td, "react.js")
    open(rj, "w").write("""global.window={};eval(require('fs').readFileSync(process.argv[2],'utf8'));const SRB=window.SRB;
const mk=()=>{const log=[];const g=new Proxy({},{get:(t,k)=>k in t?t[k]:(/Gradient/.test(String(k))?()=>({addColorStop(){}}):(...a)=>{a.forEach(v=>{if(typeof v==='number'&&!isFinite(v))throw new Error('non-finite in '+String(k))});log.push(String(k)+a.map(v=>typeof v==='number'?v.toFixed(3):'').join(','))}),set:(t,k,v)=>(t[k]=v,true)});return{g,log}};
const p={bg:'#101010',fg:'#ffffff',accent:'#ff0000',accent2:'#0000ff'};let bad=[];
for(const b of SRB.list){for(const mood of Object.keys(SRB.moods)){const x=mk();try{SRB.draw(b.id,x.g,640,360,3.3,p,{sig:{pulse:1,energy:1,beat:.5},mood})}catch(e){bad.push(b.id+': '+e.message)}}
 const a=mk(),r=mk(),n=mk();SRB.draw(b.id,a.g,640,360,3.3,p,{});SRB.draw(b.id,r.g,640,360,3.3,p,{sig:{pulse:1,energy:1},mood:'punch',reduced:true});SRB.draw(b.id,n.g,640,360,3.3,p,{sig:{pulse:1,energy:1},mood:'punch',react:false});
 if(a.log.join()!==n.log.join())bad.push(b.id+': react:false changed the drawing');}
const q=mk(),w=mk();SRB.draw('particles',q.g,640,360,3.3,p,{});SRB.draw('particles',w.g,640,360,3.3,p,{sig:{pulse:1,energy:1},mood:'punch'});if(q.log.join()===w.log.join())bad.push('particles do not react to the beat');
const z=mk(),y=mk();SRB.draw('particles',z.g,640,360,3.3,p,{reduced:true});SRB.draw('particles',y.g,640,360,3.3,p,{reduced:true,sig:{pulse:1,energy:1},mood:'punch'});if(z.log.join()!==y.log.join())bad.push('reduced motion still reacts');
const sg=mk();SRB.sequence(sg.g,640,360,5.0,p,{},[{id:'solid',from:0},{id:'grid',from:5}],.6);
console.log(bad.length?bad.join('; '):'ok');""")
    rr = run(["node", rj, os.path.join(SK, "engine", "backgrounds.js")])
    sj = os.path.join(td, "sig.js")
    open(sj, "w").write("""const {loadReel}=require(process.argv[2]);const {SR}=loadReel(process.argv[3],null);const env={kick:1,hat:.2,energy:.5};
const a=SR.signals({music:false,env}),b=SR.signals({music:true,env,reduced:true}),c=SR.signals({music:true,env,beat:{bf:.25}}),d=SR.signals({music:true,reduced:false});
console.log(a===null&&b===null&&d===null&&c&&c.pulse===1&&c.beat===.25?'ok':'bad '+JSON.stringify([a,b,c,d]));""")
    rs = run(["node", sj, os.path.join(SK, "scripts", "_reel.js"), built])
    ok("music guard rails: reactions finite and mood-scaled, off without music signals, muted or reduced motion; SR.signals gated") if rr.stdout.strip() == "ok" and rs.stdout.strip() == "ok" else bad("music guard rails failed: " + (rr.stdout + rr.stderr + rs.stdout + rs.stderr)[-300:])
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
        if set(inzip) != set(disk): bad(".skill file list differs from the folder. Only in the .skill (not in the folder): " + (", ".join(sorted(set(inzip) - set(disk))[:6]) or "none") + ". Only in the folder (not in the .skill): " + (", ".join(sorted(set(disk) - set(inzip))[:6]) or "none"))
        elif any(hashlib.md5(inzip[n]).digest() != hashlib.md5(disk[n]).digest() for n in disk): bad(".skill content differs from the folder (run: python3 tools/package.py)")
        else: ok(f".skill identical to the folder ({len(disk)} files)")
    # demo harness
    demo = os.path.join(ROOT, "demo", "showreel-director-demo.html")
    if os.path.exists(demo):
        r = run(["node", os.path.join(SK, "scripts", "harness.js"), demo, "--step", "0.5"])
        line = next((l for l in r.stdout.splitlines() if l.startswith("issues:")), "issues: ?")
        ok("demo harness " + line) if line == "issues: 0" else bad("demo harness " + line)
    # native app: shared files exist, every tool is implemented, UI script parses
    sdir = os.path.join(ROOT, "app-swift")
    if os.path.isdir(sdir):
        import json
        need = ["shared/tools.json", "shared/addendum.md", "shared/capabilities.json", "Package.swift"] + ["Sources/ShowreelStudio/" + f for f in ("App.swift", "ChatModel.swift", "ChatView.swift", "PreviewPane.swift", "EnvModel.swift", "SetupView.swift", "Agent.swift", "Tools.swift")]
        gone = [n for n in need if not os.path.exists(os.path.join(sdir, n))]
        ok("swift app files present") if not gone else bad("app-swift missing: " + ", ".join(gone))
        capf = os.path.join(sdir, "shared", "capabilities.json")
        port = os.path.join(SK, "references", "portability.md")
        if os.path.exists(capf) and os.path.exists(port):
            declared = {x["need"] for x in json.load(open(capf))["capabilities"]}
            rows, inside = [], False
            for ln in open(port, encoding="utf-8").read().splitlines():
                if ln.startswith("| Step needs"): inside = True; continue
                if inside and ln.startswith("|---"): continue
                if inside and ln.startswith("|"): rows.append(ln.split("|")[1].strip())
                elif inside: break
            miss = [r for r in rows if r not in declared]; extra = sorted(declared - set(rows))
            if rows and not miss and not extra: ok("app capabilities match the skill's portability table (%d)" % len(rows))
            else: bad("capabilities.json out of step with portability.md: undeclared %s, unknown %s" % (miss, extra))
        setup = os.path.join(ROOT, "tools", "setup-env.sh")
        envm = os.path.join(sdir, "Sources", "ShowreelStudio", "EnvModel.swift")
        if os.path.exists(setup) and os.path.exists(envm):
            r = run(["bash", setup, "--check"])
            keys = [l.split("=")[0] for l in r.stdout.split() if l.split("=")[-1] in ("ok", "missing")]
            swift_ids = re.findall(r'EnvItem\(id: "(\w+)"', open(envm).read())
            want = [k for k in keys if k != "brew"]
            ok("setup-env.sh --check keys match the app's checklist (%d)" % len(want)) if r.returncode == 0 and want == swift_ids \
                else bad("setup-env.sh keys %s vs EnvModel items %s" % (want, swift_ids))
        import skill_hash
        ok("skill fingerprint is stable (" + skill_hash.fingerprint() + ")") if skill_hash.fingerprint() == skill_hash.fingerprint() else bad("skill fingerprint not deterministic")
        sw = os.path.join(sdir, "Sources", "ShowreelStudio", "Tools.swift")
        tj = os.path.join(sdir, "shared", "tools.json")
        if os.path.exists(sw) and os.path.exists(tj):
            names = [d["name"] for d in json.load(open(tj))]
            code = open(sw).read()
            missing = [n for n in names if '"%s"' % n not in code]
            ok("swift app implements every shared tool") if not missing else bad("Tools.swift lacks tools: " + ", ".join(missing))
    print("\n" + ("all checks passed" if not fails else f"{len(fails)} check(s) failed"))
    sys.exit(1 if fails else 0)

if __name__ == "__main__":
    main()
