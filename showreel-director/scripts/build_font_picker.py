#!/usr/bin/env python3
"""Build a one-file page to choose free fonts: a curated list (engine/fonts-free.json, open licences, embedding allowed), filterable
by mood and kind, previewed in the user's palette. The user picks one font for titles and one for text, then pastes "Copy my picks" in the chat.

Usage: python3 build_font_picker.py --out PROJECT/qa/fonts-picker.html [--bg #111 --fg #f4f4f0 --accent #e6ff00 --accent2 #888] [--ui ui.json --lang fr]
  --ui keys: titles text exact approx specimen all hint copied copy lt lb (lt = label of the titles pick, lb = label of the text pick)
Previews use the preview files bundled in engine/fonts-preview/ (embedded in the page, so they work offline and in the Cowork preview); a font without a bundled file loads online or falls back to a system font (the card says which). Nothing is downloaded by this page:
once a font is chosen, `scripts/fetch_font.py "<name>"` fetches the files and the licence. Check glyph coverage for every reel language (accents, symbols) before approving.
"""
import argparse, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _common as C

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    C.add_brand_args(ap, "#151515", "#f2f2f2", "#ffd166", "#6c8cff", "PickerFont")
    a = ap.parse_args()
    C.require_colors(a.bg, a.fg, a.accent, a.accent2)
    fonts = json.load(open(os.path.join(HERE, "..", "engine", "fonts-free.json"), encoding="utf-8"))
    html = open(os.path.join(HERE, "..", "engine", "font-picker.html"), encoding="utf-8").read()
    for k, v in (("__BG__", a.bg), ("__FG__", a.fg), ("__ACCENT__", a.accent), ("__ACCENT2__", a.accent2)):
        html = html.replace(k, v)
    html = html.replace("__FONTS__", C.js_json(fonts))
    faces, emb = [], []
    pdir = os.path.join(HERE, "..", "engine", "fonts-preview")
    for f in fonts:  # bundled preview files (woff2 latin subsets, see tools/fetch_font_previews.py): the real fonts show even with no network
        fp = os.path.join(pdir, f["dir"] + ".woff2")
        if os.path.exists(fp):
            data = open(fp, "rb").read()
            faces.append(C.font_face(f["name"], data, "font/woff2", "woff2", weight="100 900")); emb.append(f["name"])
    html = html.replace("__FACES__", "\n".join(faces)).replace("__EMB__", C.js_json(emb))
    if a.ui:
        u = json.load(open(a.ui, encoding="utf-8"))
        keys = ("titles", "text", "exact", "approx", "specimen", "all", "hint", "copied", "copy", "lt", "lb")
        html = html.replace("/*__GT__*/", "Object.assign(GT,%s);" % C.js_json({k: u[k] for k in keys if k in u}))
        html = html.replace('<html lang="en">', '<html lang="%s">' % a.lang.replace('"', ""), 1)
    C.write_text(a.out, html)
    print("wrote", a.out, "(%d fonts, %d with a bundled preview, %d KB)" % (len(fonts), len(emb), len(html) // 1024))
    if len(emb) < len(fonts): print("note: %d font(s) have no bundled preview (run tools/fetch_font_previews.py on a machine with network, then rebuild); they load online when the page is opened in a browser with network" % (len(fonts) - len(emb)))


if __name__ == "__main__":
    main()
