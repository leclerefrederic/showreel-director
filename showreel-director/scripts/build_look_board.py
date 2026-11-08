#!/usr/bin/env python3
"""Build a one-file look board: 2 to 4 design packages (palette, background, font pair, effects mood) shown as real film frames with the reel's own message,
so the user feels the look before the details. The user picks one, or mixes palette / background / fonts / effects mood from different packages, and pastes the result.

Usage: python3 build_look_board.py SPEC.json --out PROJECT/qa/look-board.html [--ui ui.json --lang fr]
Spec (JSON):
{ "title": "Look board", "intro": "Pick the look that feels right.", "message": "Know where your money goes", "sub": "optional supporting line",
  "packages": [ { "id": "A", "name": "Clean signal", "why": "one line: why this fits the brief",
                  "palette": {"bg": "#0B1020", "fg": "#F5F7FF", "accent": "#F5C518", "accent2": "#2B3A67"},
                  "background": "an id of engine/backgrounds.js: solid, duotone, vignette, linear, radial, conic, mesh, grid, dots, diagonal, checker, waves, hex, bars, grain, halftone, aurora, particles, stars, scanlines, drift, spotlight, waves-flow",
                  "fonts": {"titles": "Poppins", "text": "Inter"},          names from engine/fonts-free.json, or {"name": "Brand Sans", "file": "path.ttf"} for a supplied font
                  "effects_pack": "Clean product" } ] }               one of the packs of references/effects-catalogue.md
Guardrails: 3 packages recommended (2 to 4 accepted), distinct from each other; each one derived from the brief or the brand, never from habit.
Nothing is pre-selected; "Copy" refuses until a look is chosen (or "none of these" with a note). The result is a draft the skill confirms in the conversation.
--ui keys: pick mix palette background fonts effects none note copy copied open needNote needPick sub (translated page texts), --lang sets the page language.
"""
import argparse, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _common as C

HERE = os.path.dirname(os.path.abspath(__file__))
ALIAS = {"gradient": "linear"}  # older name kept


def bg_ids():
    """Background ids come from engine/backgrounds.js (single source): add('id', 'Family', ...)."""
    js = open(os.path.join(HERE, "..", "engine", "backgrounds.js"), encoding="utf-8").read()
    return re.findall(r"add\('([a-z0-9-]+)',", js)


def packs():
    cat = open(os.path.join(HERE, "..", "references", "effects-catalogue.md"), encoding="utf-8").read()
    m = re.search(r"## Packs.*?\n\n", cat, re.S)
    return [ln.strip().strip("|").split("|")[0].strip() for ln in (m.group(0).splitlines()[3:] if m else []) if ln.startswith("|")]


def check(spec, fonts, spec_dir):
    errs = []
    if not isinstance(spec, dict) or not spec.get("message"): return ["spec needs a \"message\" (the line shown in every frame)"]
    ps = spec.get("packages")
    if not isinstance(ps, list) or not 2 <= len(ps) <= 4: return ["spec needs 2 to 4 packages (3 recommended)"]
    names, ids, valid = {f["name"] for f in fonts}, set(), set(packs())
    for n, p in enumerate(ps, 1):
        i = p.get("id")
        if not i or i in ids: errs.append(f"package {n}: missing or duplicate id")
        ids.add(i)
        pal = p.get("palette") or {}
        for k in ("bg", "fg", "accent"):
            if not C.HEX.match(str(pal.get(k, ""))): errs.append(f"{i}: palette.{k} must be a hex colour")
        if pal.get("accent2") and not C.HEX.match(str(pal["accent2"])): errs.append(f"{i}: palette.accent2 must be a hex colour")
        if ALIAS.get(p.get("background"), p.get("background")) not in bg_ids(): errs.append(f"{i}: background must be one of {', '.join(bg_ids())}")
        if p.get("effects_pack") not in valid: errs.append(f"{i}: effects_pack must be one of {', '.join(sorted(valid))}")
        for role in ("titles", "text"):
            f = (p.get("fonts") or {}).get(role)
            if isinstance(f, str):
                if f not in names: errs.append(f"{i}: font {f!r} is not in engine/fonts-free.json (use a listed font or a supplied file)")
            elif isinstance(f, dict):
                if not f.get("name") or not f.get("file") or not os.path.exists(os.path.join(spec_dir, f["file"])): errs.append(f"{i}: supplied font {role} needs name and an existing file")
            else: errs.append(f"{i}: fonts.{role} missing")
    sigs = [json.dumps([p["palette"], p["background"], p["fonts"]], sort_keys=True) for p in ps if not errs]
    if not errs and len(set(sigs)) < len(sigs): errs.append("two packages are identical: propose distinct looks")
    return errs


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("spec"); ap.add_argument("--out", required=True)
    ap.add_argument("--ui"); ap.add_argument("--lang", default="en")
    a = ap.parse_args()
    spec = json.load(open(a.spec, encoding="utf-8")); sd = os.path.dirname(os.path.abspath(a.spec))
    fonts = json.load(open(os.path.join(HERE, "..", "engine", "fonts-free.json"), encoding="utf-8"))
    errs = check(spec, fonts, sd)
    if errs: print("\n".join("  FAIL " + e for e in errs)); return 1
    listed = {f["name"]: f for f in fonts}; faces, done, missing = [], set(), []
    for p in spec["packages"]:
        for role in ("titles", "text"):
            f = p["fonts"][role]
            if isinstance(f, str): f = p["fonts"][role] = {"name": f}
            if f["name"] in done: continue
            done.add(f["name"])
            if "file" in f:
                data, mime, fmt = C.font_blob(os.path.join(sd, f["file"]), flavor="woff"); faces.append(C.font_face(f["name"], data, mime, fmt, weight="100 900"))
            else:
                fp = os.path.join(HERE, "..", "engine", "fonts-preview", listed[f["name"]]["dir"] + ".woff2")
                if os.path.exists(fp): faces.append(C.font_face(f["name"], open(fp, "rb").read(), "font/woff2", "woff2", weight="100 900"))
                else: missing.append(f["name"])
    html = open(os.path.join(HERE, "..", "engine", "look-board.html"), encoding="utf-8").read()
    html = html.replace("__FACES__", "\n".join(faces)).replace("__SPEC__", C.js_json(spec)).replace("__BACKGROUNDS__", open(os.path.join(HERE, "..", "engine", "backgrounds.js"), encoding="utf-8").read())
    if a.ui:
        u = json.load(open(a.ui, encoding="utf-8"))
        keys = ("pick", "mix", "palette", "background", "fonts", "effects", "none", "note", "copy", "copied", "open", "needNote", "needPick", "sub", "why", "yours", "titles", "text")
        html = html.replace("/*__GT__*/", "Object.assign(GT,%s);" % C.js_json({k: u[k] for k in keys if k in u}))
        html = html.replace('<html lang="en">', '<html lang="%s">' % a.lang.replace('"', ""), 1)
    C.write_text(a.out, html)
    print("wrote", a.out, "(%d packages, %d KB)" % (len(spec["packages"]), len(html) // 1024))
    if missing: print("note: no bundled preview for " + ", ".join(missing) + " (shown in a system font until tools/fetch_font_previews.py has been run)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
