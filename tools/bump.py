#!/usr/bin/env python3
"""Ship a new version of the skill.

Usage: python3 tools/bump.py patch|minor|major "what changed, one line" [--date YYYY-MM-DD]
First write the section "## X.Y.Z - date" of the new version in RELEASE-NOTES-SKILL.md: this script refuses to publish without it.
Sets metadata.version in showreel-director/SKILL.md, adds an entry at the top of CHANGELOG.md, records the fingerprint in
tools/released.json, repackages showreel-director.skill and runs tools/check.py. tools/check.py warns when the skill changed
after the last release and fails when version, changelog and record disagree."""
import datetime, json, os, re, subprocess, sys
sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE); sys.path.insert(0, HERE)
import skill_hash

def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("patch", "minor", "major"): sys.exit(__doc__)
    kind, note = sys.argv[1], sys.argv[2]; date = sys.argv[sys.argv.index("--date") + 1] if "--date" in sys.argv else datetime.date.today().isoformat()
    sp = os.path.join(ROOT, "showreel-director", "SKILL.md"); s = open(sp, encoding="utf-8").read()
    m = re.search(r'(metadata:\n  version: ")(\d+)\.(\d+)\.(\d+)(")', s)
    if not m: sys.exit("no metadata.version in SKILL.md")
    a, b, c = int(m.group(2)), int(m.group(3)), int(m.group(4))
    a, b, c = (a + 1, 0, 0) if kind == "major" else (a, b + 1, 0) if kind == "minor" else (a, b, c + 1)
    ver = f"{a}.{b}.{c}"
    rn = os.path.join(ROOT, "RELEASE-NOTES-SKILL.md"); notes = open(rn, encoding="utf-8").read() if os.path.exists(rn) else ""
    if not re.search(r"^## " + re.escape(ver) + r"\b", notes, re.M): sys.exit(f"RELEASE-NOTES-SKILL.md has no section '## {ver} - {date}': write it first (What's new, Changed, What you need to do), then run this again.")
    s = s[:m.start()] + m.group(1) + ver + m.group(5) + s[m.end():]; open(sp, "w", encoding="utf-8").write(s)
    cp = os.path.join(ROOT, "CHANGELOG.md"); cl = open(cp, encoding="utf-8").read(); i = cl.index("\n## ") + 1
    open(cp, "w", encoding="utf-8").write(cl[:i] + f"## {ver} - {date}\n\n{note}\n\n" + cl[i:])
    json.dump({"version": ver, "fingerprint": skill_hash.fingerprint()}, open(os.path.join(HERE, "released.json"), "w"), indent=1); open(os.path.join(HERE, "released.json"), "a").write("\n")
    subprocess.run([sys.executable, os.path.join(HERE, "package.py")], check=True)
    r = subprocess.run([sys.executable, os.path.join(HERE, "check.py")]); print(f"released {ver}" if r.returncode == 0 else "check failed")
    sys.exit(r.returncode)

if __name__ == "__main__":
    main()
