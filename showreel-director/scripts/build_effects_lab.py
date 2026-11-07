#!/usr/bin/env python3
"""Build a self-contained effects lab page: every effect of the catalogue animated, in the user's palette and font.

Usage: python3 build_effects_lab.py --out PROJECT/qa/lab-effects.html
         [--bg #151515 --fg #f2f2f2 --accent #ffd166 --accent2 #6c8cff] [--font path/to/font.ttf --family "Brand Sans"]
Neutral palette by default. Present the file to the user, who clicks the hearts on the effects they like and pastes
"Copy my picks" back in the chat; each card also has a GIF button that saves that effect as a looping GIF. Effects are drawn with plain canvas code: they show the idea, not your final render.
"""
import argparse, base64, io, json, os

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--bg", default="#151515"); ap.add_argument("--fg", default="#f2f2f2")
    ap.add_argument("--accent", default="#ffd166"); ap.add_argument("--accent2", default="#6c8cff")
    ap.add_argument("--mute", default="#8a8a8a")
    ap.add_argument("--font"); ap.add_argument("--family", default="LabFont")
    a = ap.parse_args()
    html = open(os.path.join(HERE, "..", "engine", "effects-lab.html"), encoding="utf-8").read()
    edir = os.path.join(HERE, "..", "engine", "effects")
    effects = "\n".join(open(os.path.join(edir, f), encoding="utf-8").read() for f in sorted(os.listdir(edir)) if f.endswith(".js"))
    html = html.replace("/*__EFFECTS__*/", effects)
    html = html.replace("/*__GIF__*/", open(os.path.join(HERE, "..", "engine", "gif.js"), encoding="utf-8").read())
    css, family = "", "system-ui,sans-serif"
    if a.font:
        data, mime, fmt = open(a.font, "rb").read(), "font/ttf", "truetype"
        try:
            from fontTools.ttLib import TTFont
            tt = TTFont(a.font); tt.flavor = "woff"; b = io.BytesIO(); tt.save(b)
            data, mime, fmt = b.getvalue(), "font/woff", "woff"
        except Exception:
            pass  # fontTools missing: embed the raw font
        css = '@font-face{font-family:"%s";font-weight:100 900;src:url(data:%s;base64,%s) format("%s")}' % (
            a.family, mime, base64.b64encode(data).decode(), fmt)
        family = '"%s",system-ui,sans-serif' % a.family
    pal = {"bg": a.bg, "fg": a.fg, "accent": a.accent, "accent2": a.accent2, "mute": a.mute}
    html = html.replace("__FONTS_CSS__", css).replace("__PALETTE__", json.dumps(pal)).replace("__FONT__", json.dumps(family))
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    open(a.out, "w", encoding="utf-8").write(html)
    print("wrote", a.out, "(%d KB)" % (len(html) // 1024))


if __name__ == "__main__":
    main()
