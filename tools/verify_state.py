#!/usr/bin/env python3
"""What changed since the last complete verification, by content (never by git or by date), for tools/verify.sh --fast.

  verify_state.py check   prints "skill=changed|same" and "slow=changed|same" (no stamp yet: changed)
  verify_state.py save    records the fingerprints of now: tools/verify.sh does it after a complete pass

The stamp lives in ~/Library/Developer/ShowreelStudio/verify-stamp.json, outside the repository.
skill: the fingerprint of the skill folder. slow: that, plus the files behind the slow test classes (BuildTests, FilmTests, InteractionTests,
ChecksTests): Build.swift, Film.swift, Checks.swift, Drops.swift and those test files themselves."""
import hashlib, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import skill_hash

ROOT = os.path.dirname(HERE)
STAMP = os.path.expanduser("~/Library/Developer/ShowreelStudio/verify-stamp.json")
SLOW_FILES = ["Sources/ShowreelKit/Build.swift", "Sources/ShowreelKit/Film.swift", "Sources/ShowreelKit/Checks.swift", "Sources/ShowreelKit/Drops.swift",
              "Tests/ShowreelKitTests/BuildTests.swift", "Tests/ShowreelKitTests/FilmTests.swift", "Tests/ShowreelKitTests/InteractionTests.swift", "Tests/ShowreelKitTests/ChecksTests.swift"]


def digests():
    skill = skill_hash.fingerprint()
    h = hashlib.sha256(skill.encode())
    for f in SLOW_FILES:
        p = os.path.join(ROOT, "app-swift", f)
        h.update(f.encode() + b"\0" + (open(p, "rb").read() if os.path.exists(p) else b"") + b"\0")
    return {"skill": skill, "slow": h.hexdigest()[:12]}


def stamp():
    try:
        return json.load(open(STAMP))
    except Exception:
        return {}


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    now = digests()
    if cmd == "save":
        os.makedirs(os.path.dirname(STAMP), exist_ok=True)
        json.dump(now, open(STAMP, "w"))
        print("verification stamp saved")
    else:
        old = stamp()
        for k in ("skill", "slow"):
            print("%s=%s" % (k, "same" if old.get(k) == now[k] else "changed"))
