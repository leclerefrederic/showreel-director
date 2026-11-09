#!/usr/bin/env python3
"""Ship a new version of the app.

Usage: python3 tools/bump_app.py patch|minor|major "what changed, one line" [--date YYYY-MM-DD]
First write the section "## X.Y.Z - date" of the new version in RELEASE-NOTES-APP.md (What's new, Changed, What you need to do); this script refuses to publish without it.
Sets the version in app-swift/shared/app-version.json (the single source: make-app.sh writes it into the bundle), adds an entry at the top of CHANGELOG-APP.md, records the
fingerprint of the app's sources in tools/released-app.json and runs tools/check.py. No git. Never edit the version by hand."""
import datetime, json, os, re, subprocess, sys
sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE); sys.path.insert(0, HERE)
import app_hash

def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("patch", "minor", "major"): sys.exit(__doc__)
    kind, note = sys.argv[1], sys.argv[2]; date = sys.argv[sys.argv.index("--date") + 1] if "--date" in sys.argv else datetime.date.today().isoformat()
    vp = os.path.join(ROOT, "app-swift", "shared", "app-version.json"); cur = json.load(open(vp))["version"]
    a, b, c = map(int, cur.split("."))
    a, b, c = (a + 1, 0, 0) if kind == "major" else (a, b + 1, 0) if kind == "minor" else (a, b, c + 1)
    ver = f"{a}.{b}.{c}"
    notes = open(os.path.join(ROOT, "RELEASE-NOTES-APP.md"), encoding="utf-8").read() if os.path.exists(os.path.join(ROOT, "RELEASE-NOTES-APP.md")) else ""
    if not re.search(r"^## " + re.escape(ver) + r"\b", notes, re.M): sys.exit(f"RELEASE-NOTES-APP.md has no section '## {ver} - {date}': write it first (What's new, Changed, What you need to do), then run this again.")
    json.dump({"version": ver}, open(vp, "w")); open(vp, "a").write("\n")
    cp = os.path.join(ROOT, "CHANGELOG-APP.md"); cl = open(cp, encoding="utf-8").read(); i = cl.index("\n## ") + 1
    open(cp, "w", encoding="utf-8").write(cl[:i] + f"## {ver} - {date}\n\n{note}\n\n" + cl[i:])
    json.dump({"version": ver, "fingerprint": app_hash.fingerprint()}, open(os.path.join(HERE, "released-app.json"), "w"), indent=1); open(os.path.join(HERE, "released-app.json"), "a").write("\n")
    r = subprocess.run([sys.executable, os.path.join(HERE, "check.py"), "--app"]); print(f"released app {ver}" if r.returncode == 0 else "check failed")
    sys.exit(r.returncode)

if __name__ == "__main__":
    main()
