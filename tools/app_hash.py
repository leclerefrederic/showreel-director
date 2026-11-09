#!/usr/bin/env python3
"""Prints a short, deterministic fingerprint of the app's sources: app-swift/Sources, app-swift/shared (except the version file itself) and make-app.sh.
tools/bump_app.py records it in tools/released-app.json; tools/check.py warns when the sources changed after the last release."""
import hashlib, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "app-swift")

def fingerprint():
    h = hashlib.sha256()
    files = []
    for sub in ("Sources", "shared"):
        for dp, dns, fns in os.walk(os.path.join(APP, sub)):
            dns[:] = sorted(d for d in dns if d != "__pycache__")
            for fn in sorted(fns):
                if fn == ".DS_Store" or fn.endswith(".pyc") or (sub == "shared" and fn == "app-version.json"): continue
                files.append(os.path.join(dp, fn))
    files.append(os.path.join(APP, "make-app.sh"))
    for p in files:
        h.update(os.path.relpath(p, APP).encode() + b"\0"); h.update(open(p, "rb").read() + b"\0")
    return h.hexdigest()[:12]

if __name__ == "__main__":
    print(fingerprint())
