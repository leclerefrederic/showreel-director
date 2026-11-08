#!/usr/bin/env python3
"""Download the preview files of the curated free fonts into showreel-director/engine/fonts-preview/ (run once, on a machine with network access).

Usage: python3 tools/fetch_font_previews.py [--only "Poppins,Inter"] [--force]
For each font of engine/fonts-free.json it asks Google Fonts for the Latin subset (woff2, about 15-40 KB, covers English, French, German and most European languages)
and saves it as <dir>.woff2. build_font_picker.py then embeds the files that exist, so the picker shows the real fonts offline and inside previews that load nothing from the web.
All fonts of the list are under the SIL Open Font License (embedding and redistribution allowed with the licence text, see fonts-preview/README.txt).
"""
import argparse, json, os, re, sys, urllib.parse, urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "showreel-director")
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"  # a modern browser gets woff2


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=25) as r:
        return r.read()


def latin_url(css):
    """URL of the latin block of a Google Fonts stylesheet (the block that follows the comment /* latin */)."""
    for m in re.finditer(r"/\*\s*([\w-]+)\s*\*/\s*@font-face\s*\{(.*?)\}", css, re.S):
        if m.group(1) == "latin":
            u = re.search(r"url\((https:[^)]+\.woff2)\)", m.group(2))
            if u: return u.group(1)
    return None


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--only"); ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    fonts = json.load(open(os.path.join(ROOT, "engine", "fonts-free.json"), encoding="utf-8"))
    if a.only:
        want = {x.strip().lower() for x in a.only.split(",")}; fonts = [f for f in fonts if f["name"].lower() in want]
    out = os.path.join(ROOT, "engine", "fonts-preview"); os.makedirs(out, exist_ok=True); bad = 0
    for f in fonts:
        dst = os.path.join(out, f["dir"] + ".woff2")
        if os.path.exists(dst) and not a.force: print("have   " + f["name"]); continue
        try:
            css = get("https://fonts.googleapis.com/css2?family=" + urllib.parse.quote(f["name"]).replace("%20", "+") + "&display=swap").decode("utf-8")
            u = latin_url(css)
            if not u: print("FAIL   %s: no latin block in the stylesheet" % f["name"]); bad += 1; continue
            data = get(u)
            if data[:4] != b"wOF2": print("FAIL   %s: not a woff2 file" % f["name"]); bad += 1; continue
            open(dst, "wb").write(data); print("saved  %s (%d KB)" % (f["name"], len(data) // 1024))
        except Exception as e:
            print("FAIL   %s: %s" % (f["name"], e)); bad += 1
    open(os.path.join(out, "README.txt"), "w").write("Preview files (Latin subsets) of fonts licensed under the SIL Open Font License 1.1, from the Google Fonts repository (github.com/google/fonts).\nEach font keeps its own copyright and licence (ofl/<folder>/OFL.txt in that repository). Used only for the font picker preview.\n")
    print("done" if not bad else "%d font(s) failed: rerun, or open the specimen links" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
