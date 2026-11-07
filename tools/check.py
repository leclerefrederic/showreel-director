#!/usr/bin/env python3
"""Repository consistency checks. Exit code 1 if anything fails.

Usage: python3 tools/check.py [--fix]   (--fix regenerates the effects index and the sample lab, then re-checks)
Checks: SKILL.md frontmatter, Python and JS syntax, effects index and sample lab up to date, every file named in
SKILL.md exists, no accented or stray non-ASCII text in the skill's text files (English only), no caches or
.DS_Store, the .skill matches the folder byte for byte, demo harness has no real issues.
"""
import argparse, hashlib, os, re, subprocess, sys, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
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
    if m and m.group(1) == package.SKILL and len(m.group(2)) > 100: ok("SKILL.md frontmatter")
    else: bad("SKILL.md frontmatter (name must be showreel-director, description present)")
    # files named in SKILL.md
    names = set(re.findall(r"`((?:references|engine|scripts|demo)/[\w./-]+)`", s))
    missing = sorted(n for n in names if not os.path.exists(os.path.join(SK, n)) and "<" not in n and "*" not in n and not n.startswith("demo/"))  # demo/ is optional, outside the package
    ok(f"{len(names)} files named in SKILL.md exist") if not missing else bad("named in SKILL.md but missing: " + ", ".join(missing))
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
