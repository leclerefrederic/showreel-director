#!/usr/bin/env python3
"""Build a one-file page to choose free fonts: a curated list (engine/fonts-free.json, open licences, embedding allowed), filterable
by mood and kind, previewed in the user's palette. The user picks one font for titles and one for text, then pastes "Copy my picks" in the chat.

Usage: python3 build_font_picker.py --out PROJECT/qa/fonts-picker.html [--bg #111 --fg #f4f4f0 --accent #e6ff00 --accent2 #888] [--ui ui.json --lang fr]
  --ui keys: titles text exact approx specimen all hint copied copy lt lb (lt = label of the titles pick, lb = label of the text pick)
Previews use the font when it is installed on the computer, otherwise a close system font (the card says which). Nothing is downloaded by this page:
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
    if a.ui:
        u = json.load(open(a.ui, encoding="utf-8"))
        keys = ("titles", "text", "exact", "approx", "specimen", "all", "hint", "copied", "copy", "lt", "lb")
        html = html.replace("/*__GT__*/", "Object.assign(GT,%s);" % C.js_json({k: u[k] for k in keys if k in u}))
        html = html.replace('<html lang="en">', '<html lang="%s">' % a.lang.replace('"', ""), 1)
    C.write_text(a.out, html)
    print("wrote", a.out, "(%d fonts, %d KB)" % (len(fonts), len(html) // 1024))


if __name__ == "__main__":
    main()
