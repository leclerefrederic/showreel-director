#!/usr/bin/env python3
"""Check the tools the showreel scripts need, and say what degrades if one is missing.

Usage: python3 check_env.py [--json]
Prints one line per tool: OK / MISSING (required) / MISSING (optional), with the fallback and an install hint.
Exit code 1 only if a required tool is missing. Never installs anything: ask the user before installing.
"""
import json, os, shutil, subprocess, sys

def run(cmd, timeout=15):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr).strip()
    except Exception as e:
        return 1, str(e)

def have_py(mod):
    try:
        __import__(mod); return True
    except Exception:
        return False

def node_has(mod):
    node = shutil.which("node")
    if not node: return False
    env = dict(os.environ)
    rc, out = run(["npm", "root", "-g"]) if shutil.which("npm") else (1, "")
    paths = [p for p in [env.get("NODE_PATH", ""), out if rc == 0 else ""] if p]
    env["NODE_PATH"] = os.pathsep.join(paths)
    try:
        r = subprocess.run([node, "-e", f"require('{mod}')"], capture_output=True, env=env, timeout=15)
        return r.returncode == 0
    except Exception:
        return False

def main():
    res = []
    def add(name, ok, required, used_for, fallback, hint, detail=""):
        res.append({"tool": name, "ok": bool(ok), "required": required, "used_for": used_for, "fallback": fallback, "install": hint, "detail": detail})
    add("python3 >= 3.8", sys.version_info >= (3, 8), True, "all scripts", "none", "install Python 3", f"found {sys.version.split()[0]}")
    add("numpy", have_py("numpy"), True, "analyze_audio.py (tempo, beats, drops)",
        "ask the user for BPM and drop positions and build the beat grid by hand, then check by ear", "pip install numpy --break-system-packages")
    ff = shutil.which("ffmpeg"); fp = shutil.which("ffprobe")
    add("ffmpeg", ff, True, "analyze_audio.py (decode the track)", "ask the user for BPM and track length", "install ffmpeg (brew install ffmpeg)")
    add("ffprobe", fp, False, "audit_assets.py (image/audio/video sizes and durations)", "audit by eye and from file names", "comes with ffmpeg")
    node = shutil.which("node"); ver = ""
    if node:
        rc, ver = run([node, "-v"])
    major = int(ver.lstrip("v").split(".")[0]) if node and ver.startswith("v") else 0
    add("node >= 16", node and major >= 16, False, "harness.js, smoke_player.js (automatic tests)",
        "skip automatic tests; rely on contact sheets and the user's eyes, and say that in the verification report", "install Node.js (brew install node)", ver)
    add("fontTools (python)", have_py("fontTools"), False, "build.py: font compression", "fonts are embedded as raw files (heavier HTML)", "pip install fonttools --break-system-packages")
    add("brotli (python)", have_py("brotli"), False, "build.py: woff2 fonts", "fonts embed as woff (a bit heavier)", "pip install brotli --break-system-packages")
    add("jsdom (node)", node_has("jsdom"), False, "smoke_player.js (player UI test)", "skip the player test; test the player by hand", "npm install jsdom (in a scratch folder), then set NODE_PATH")
    add("@napi-rs/canvas (node)", node_has("@napi-rs/canvas"), False, "export_mp4.js (MP4 export without a browser, needs node and ffmpeg)",
        "no MP4 export: deliver the HTML player and screen-capture instructions", "npm install @napi-rs/canvas (in a scratch folder), then set NODE_PATH")
    browsers = [b for b in ("chromium", "chromium-browser", "google-chrome", "chrome") if shutil.which(b)]
    pw = have_py("playwright")
    add("headless browser", browsers or pw, False, "taking screenshots of contact sheets",
        "use the artifact screenshot tool if the session has one, or ask the user to open qa/contact-sheet.html", "install Chromium or `pip install playwright`", ", ".join(browsers) + (" playwright" if pw else ""))
    if "--json" in sys.argv:
        print(json.dumps(res, indent=2)); sys.exit(1 if any(r["required"] and not r["ok"] for r in res) else 0)
    for r in res:
        tag = "OK       " if r["ok"] else ("MISSING* " if r["required"] else "missing  ")
        print(f"[{tag}] {r['tool']:22s} {r['detail']}")
        if not r["ok"]: print(f"            used for: {r['used_for']}\n            fallback: {r['fallback']}\n            install : {r['install']}")
    req_missing = [r["tool"] for r in res if r["required"] and not r["ok"]]
    opt_missing = [r["tool"] for r in res if not r["required"] and not r["ok"]]
    print("\nSummary:", "all required tools present" if not req_missing else "REQUIRED missing: " + ", ".join(req_missing),
          "| optional missing: " + (", ".join(opt_missing) if opt_missing else "none"))
    sys.exit(1 if req_missing else 0)

if __name__ == "__main__":
    main()
