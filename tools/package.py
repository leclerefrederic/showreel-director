#!/usr/bin/env python3
"""Build showreel-director.skill from the showreel-director/ folder.

Usage: python3 tools/package.py [--out showreel-director.skill]
The package is a zip of the skill folder without evals/, __pycache__/ and .DS_Store, with entries sorted so
the same content always gives the same archive. Run tools/check.py afterwards (or instead: it calls the same rules).
"""
import argparse, os, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILL = "showreel-director"
SKIP_DIRS = {"evals", "__pycache__", "node_modules", ".git"}
SKIP_FILES = {".DS_Store"}

def skill_files():
    out = []
    for r, dirs, files in os.walk(os.path.join(ROOT, SKILL)):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for f in sorted(files):
            if f in SKIP_FILES or f.endswith(".pyc"): continue
            out.append(os.path.join(r, f))
    return out

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--out", default=os.path.join(ROOT, SKILL + ".skill")); a = ap.parse_args()
    files = skill_files()
    if not any(f.endswith(os.path.join(SKILL, "SKILL.md")) for f in files): sys.exit("SKILL.md not found")
    tmp = a.out + ".tmp"
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
        for f in files:
            zi = zipfile.ZipInfo(os.path.relpath(f, ROOT), date_time=(2026, 1, 1, 0, 0, 0)); zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = 0o644 << 16; z.writestr(zi, open(f, "rb").read())
    os.replace(tmp, a.out)
    print(f"wrote {os.path.relpath(a.out, ROOT)}: {len(files)} files, {os.path.getsize(a.out)/1e6:.2f} MB")

if __name__ == "__main__":
    main()
