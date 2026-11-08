#!/usr/bin/env python3
"""Prints a short, deterministic fingerprint of the skill folder (paths and contents).
The app bundle stores it as Resources/skill.hash; tools/rebuild-app.sh compares the two."""
import hashlib, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILL = os.path.join(ROOT, "showreel-director")


def fingerprint(skill=SKILL):
    h = hashlib.sha256()
    for dp, dns, fns in os.walk(skill):
        dns[:] = sorted(d for d in dns if d != "__pycache__")
        for fn in sorted(fns):
            if fn == ".DS_Store" or fn.endswith(".pyc"):
                continue
            p = os.path.join(dp, fn)
            h.update(os.path.relpath(p, skill).encode() + b"\0")
            h.update(open(p, "rb").read() + b"\0")
    return h.hexdigest()[:12]


if __name__ == "__main__":
    print(fingerprint(sys.argv[1] if len(sys.argv) > 1 else SKILL))
