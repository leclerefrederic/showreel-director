#!/usr/bin/env python3
"""Build a one-file page to choose backgrounds: every background of engine/backgrounds.js (solid, gradient, pattern, texture, animated) drawn live in the
user's palette with the reel's message over it. The user picks one for the titles, one for the content scenes and one for the closing, then pastes "Copy my picks".

Usage: python3 build_background_picker.py --out PROJECT/qa/backgrounds.html [--message "Know where your money goes"]
         [--bg #151515 --fg #f2f2f2 --accent #ffd166 --accent2 #6c8cff --font path/to/font.ttf --family "Name"] [--ui ui.json --lang fr]
  --ui keys: title bg fg accent accent2 calm beat style moods hint all anim titles content closing copy copied open (and fam: {Solid, Gradient, Pattern, Texture, Animated}).
The backgrounds are the same code a reel uses (window.SRB, inlined by build.py when main.js calls SRB.draw), so what the user picks is what the build can draw.
Animated backgrounds freeze with the "calm preview" box, as they do with reduced motion in a reel. "Preview with a beat" simulates a 124 bpm kick and lets the user hear/see how each background would react in a given style (punch, playful, tech, clean, cinematic, deadpan): in a reel the signals come from the real track and stop when there is no music, the music is muted or reduced motion is on.
"""
import argparse, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _common as C

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--out", required=True); ap.add_argument("--message", default="Simple. Fast. Yours.")
    C.add_brand_args(ap, "#151515", "#f2f2f2", "#ffd166", "#6c8cff", "PickerFont")
    a = ap.parse_args()
    C.require_colors(a.bg, a.fg, a.accent, a.accent2)
    html = open(os.path.join(HERE, "..", "engine", "background-picker.html"), encoding="utf-8").read()
    html = html.replace("__BACKGROUNDS__", open(os.path.join(HERE, "..", "engine", "backgrounds.js"), encoding="utf-8").read())
    css, family = "", "system-ui,sans-serif"
    if a.font:
        data, mime, fmt = C.font_blob(a.font, flavor="woff"); css = C.font_face(a.family, data, mime, fmt, weight="100 900"); family = '"%s",system-ui,sans-serif' % a.family
    html = html.replace("__FONTS_CSS__", css).replace("__PALETTE__", C.js_json({"bg": a.bg, "fg": a.fg, "accent": a.accent, "accent2": a.accent2}))
    html = html.replace("__MESSAGE__", C.js_json(a.message)).replace("__FONT__", C.js_json(family))
    if a.ui:
        u = json.load(open(a.ui, encoding="utf-8"))
        keys = ("title", "bg", "fg", "accent", "accent2", "calm", "beat", "style", "moods", "hint", "all", "anim", "titles", "content", "closing", "copy", "copied", "open", "fam")
        html = html.replace("/*__GT__*/", "Object.assign(GT,%s);" % C.js_json({k: u[k] for k in keys if k in u}))
        html = html.replace('<html lang="en">', '<html lang="%s">' % a.lang.replace('"', ""), 1)
    C.write_text(a.out, html)
    print("wrote", a.out, "(%d KB)" % (len(html) // 1024))


if __name__ == "__main__":
    main()
