#!/usr/bin/env python3
"""Build a self-contained effects lab page: every effect of the catalogue animated, in the user's palette and font.

Usage: python3 build_effects_lab.py --out PROJECT/qa/lab-effects.html [--ui ui.json --lang fr] [--mood "Kinetic punch"] [--full]
  --mood: open directly on the moods already chosen (for example on the look board); --full: open on the whole list of effects
  --ui: JSON with translated page texts (keys: title sample bg fg accent accent2 search speed pause resume copy copied hint, and for the guided choice g_title g_hint g_show g_all g_change g_packs g_back); effect names stay in English.
         [--bg #151515 --fg #f2f2f2 --accent #ffd166 --accent2 #6c8cff] [--font path/to/font.ttf --family "Brand Sans"]
Neutral palette by default. Present the file to the user, who clicks the hearts on the effects they like and pastes
"Copy my picks" back in the chat; each card also has a GIF button that saves that effect as a looping GIF. Effects are drawn with plain canvas code: they show the idea, not your final render.
"""
import argparse, json, os, sys
sys.dont_write_bytecode = True  # no __pycache__ inside the skill folder
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _common as C

HERE = os.path.dirname(os.path.abspath(__file__))


def load_packs():
    """Moods come from the Packs table of references/effects-catalogue.md (one definition); names in parentheses are dropped."""
    import re
    cat = open(os.path.join(HERE, "..", "references", "effects-catalogue.md"), encoding="utf-8").read()
    m = re.search(r"## Packs.*?\n\n", cat, re.S)
    packs = []
    for ln in (m.group(0).splitlines()[3:] if m else []):
        if ln.startswith("|"):
            c = [x.strip() for x in ln.strip().strip("|").split("|")]
            effs = [e.strip() for e in re.sub(r"\([^)]*\)", "", c[2]).split(",") if e.strip()]
            packs.append({"name": c[0], "feel": c[1], "effects": effs})
    return packs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    C.add_brand_args(ap, "#151515", "#f2f2f2", "#ffd166", "#6c8cff", "LabFont")
    ap.add_argument("--mute", default="#8a8a8a")
    ap.add_argument("--mood", help="open on these moods already chosen (comma-separated names of the Packs table, e.g. \"Kinetic punch\"), as picked on the look board")
    ap.add_argument("--full", action="store_true", help="open on the full list of effects instead of the guided choice of moods")
    a = ap.parse_args()
    C.require_colors(a.bg, a.fg, a.accent, a.accent2, a.mute)
    html = open(os.path.join(HERE, "..", "engine", "effects-lab.html"), encoding="utf-8").read()
    edir = os.path.join(HERE, "..", "engine", "effects")
    effects = "\n".join(open(os.path.join(edir, f), encoding="utf-8").read() for f in sorted(os.listdir(edir)) if f.endswith(".js"))
    if a.ui:  # translate the page's own texts (effect names stay as in the catalogue so picks can be matched)
        u = json.load(open(a.ui, encoding="utf-8"))
        subs = [(">Effects lab<", ">%s<", "title"), ("<label>Sample text <input", "<label>%s <input", "sample"), ("<label>Background<input", "<label>%s<input", "bg"),
                ("<label>Text<input", "<label>%s<input", "fg"), ("<label>Accent<input", "<label>%s<input", "accent"), ("<label>Accent 2<input", "<label>%s<input", "accent2"),
                ("<label>Search <input", "<label>%s <input", "search"), ("<label>Speed <input", "<label>%s <input", "speed"), (">Pause</button>", ">%s</button>", "pause"),
                ("?'Resume':'Pause'", "?'" + u.get("resume", "Resume").replace("'", "") + "':'%s'", "pause"), ("textContent='Copied'", "textContent='%s'", "copied"),
                ("'Copy my picks'", "'%s'", "copy"), (">Copy my picks</button>", ">%s</button>", "copy"),
                ("Click \u2665 on the effects you like, then copy your picks and paste them in the chat.", "%s", "hint")]
        for old, new, key in subs:
            if key in u and old in html: html = html.replace(old, new % u[key].replace("'", "\\'") if "'" in new else new % u[key])
        html = html.replace('<html lang="en">', '<html lang="%s">' % a.lang.replace('"', ''), 1)
    html = html.replace("/*__EFFECTS__*/", effects)
    packs = load_packs()
    html = html.replace("__PACKS__", json.dumps(packs)).replace("__GUIDED__", "false" if a.full else "true")
    pre = [m.strip() for m in (a.mood or "").split(",") if m.strip()]
    bad = [m for m in pre if m not in {p["name"] for p in packs}]
    if bad: sys.exit("unknown mood(s): %s (choose among: %s)" % (", ".join(bad), ", ".join(p["name"] for p in packs)))
    html = html.replace("__PRESEL__", json.dumps(pre))
    gt = {k: u[k] for k in ("g_title", "g_hint", "g_show", "g_all", "g_change", "g_packs", "g_back") if a.ui and k in u} if a.ui else {}
    html = html.replace("/*__GT__*/", "Object.assign(GT,%s);" % json.dumps({k[2:].replace("title", "title"): v for k, v in gt.items()}) if gt else "")
    html = html.replace("/*__GIF__*/", open(os.path.join(HERE, "..", "engine", "gif.js"), encoding="utf-8").read())
    css, family = "", "system-ui,sans-serif"
    if a.font:
        data, mime, fmt = C.font_blob(a.font, flavor="woff")
        css = C.font_face(a.family, data, mime, fmt, weight="100 900")
        family = '"%s",system-ui,sans-serif' % a.family
    pal = {"bg": a.bg, "fg": a.fg, "accent": a.accent, "accent2": a.accent2, "mute": a.mute}
    html = html.replace("__FONTS_CSS__", css).replace("__PALETTE__", json.dumps(pal)).replace("__FONT__", json.dumps(family))
    C.write_text(a.out, html)
    print("wrote", a.out, "(%d KB)" % (len(html) // 1024))


if __name__ == "__main__":
    main()
