"""Shared helpers for the skill's page builders and build.py. Not a command: imported by build.py, build_decision_sheet.py,
build_scene_cards.py and build_effects_lab.py so that colours, fonts, translated page texts and file output behave the same everywhere."""
import base64, importlib.util, io, json, os, re, sys

sys.dont_write_bytecode = True
HEX = re.compile(r"^#[0-9a-fA-F]{3,8}$")


def add_brand_args(ap, bg, fg, accent, accent2, family):
    """The arguments every user-facing page takes: brand colours, one font, translated texts, page language."""
    ap.add_argument("--bg", default=bg); ap.add_argument("--fg", default=fg)
    ap.add_argument("--accent", default=accent); ap.add_argument("--accent2", default=accent2)
    ap.add_argument("--font"); ap.add_argument("--family", default=family)
    ap.add_argument("--ui", help="JSON file with the page texts translated into the conversation language (keys in the script header)")
    ap.add_argument("--lang", default="en", help="language code of the page (html lang attribute)")


def require_colors(*colors):
    for c in colors:
        if not HEX.match(str(c)): sys.exit("bad colour " + str(c))


def js_json(obj):
    """JSON safe to embed in a <script> block."""
    return json.dumps(obj, ensure_ascii=False).replace("</", "<\\/")


def load_ui(defaults, path):
    ui = dict(defaults)
    if path: ui.update(json.load(open(path, encoding="utf-8")))
    return ui


def font_blob(path, flavor=None, only_sfnt=False):
    """Read a font for embedding. Returns (data, mime, css format).
    flavor None: the file as is. 'woff' or 'woff2': converted with fontTools when available (woff2 also needs brotli); 'auto' picks
    woff2 when brotli is installed, else woff. only_sfnt: convert only .ttf/.otf files. Any failure falls back to the raw file."""
    low = path.lower(); data = open(path, "rb").read()
    mime, fmt = ("font/woff2", "woff2") if low.endswith(".woff2") else ("font/woff", "woff") if low.endswith(".woff") else ("font/ttf", "truetype")
    if flavor and (not only_sfnt or low.endswith((".ttf", ".otf"))):
        try:
            from fontTools.ttLib import TTFont
            fl = ("woff2" if importlib.util.find_spec("brotli") else "woff") if flavor == "auto" else flavor
            tt = TTFont(path); tt.flavor = fl; buf = io.BytesIO(); tt.save(buf)
            return buf.getvalue(), "font/" + fl, fl
        except Exception:
            pass  # fontTools missing or the font cannot be converted: embed the raw file
    return data, mime, fmt


def font_face(family, data, mime, fmt=None, weight=None, style=None):
    """One @font-face rule with the font inlined as a data URL."""
    return '@font-face{font-family:"%s";%s%ssrc:url(data:%s;base64,%s)%s}' % (
        family, ("font-weight:%s;" % weight) if weight is not None else "", ("font-style:%s;" % style) if style is not None else "",
        mime, base64.b64encode(data).decode(), (' format("%s")' % fmt) if fmt else "")


def fill(page, pairs):
    """Replace placeholders in order (the order matters when a value could contain another placeholder)."""
    for k, v in pairs: page = page.replace(k, v)
    return page


def write_text(out, text):
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    open(out, "w", encoding="utf-8").write(text)


# ---- Font licence checks (used by audit_assets.py and organize_assets.py) ----
FONT_FORBID = re.compile(r"proprietary|forbidden|not allowed|workstation|desktop[\s-]*(licen[cs]e[\s-]*)?only|no[\s-]+(web|app|embedding)|not licen[cs]ed for[^.\n]{0,40}(web|app|embed)|(web|app|embedding)[^.\n]{0,40}(not (allowed|permitted|included|licen[cs]ed)|prohibited|forbidden)|do not embed|cannot be embedded", re.I)


def font_embedding(path):
    """Reads the font file itself: {fstype, restricted, family, meta_licence}. restricted is True when the OS/2 embedding flag forbids
    embedding (bit 1 restricted, bit 2 preview and print only). Needs fontTools; without it every value is None (the note text is still checked)."""
    out = {"fstype": None, "restricted": None, "family": "", "meta_licence": ""}
    try:
        from fontTools.ttLib import TTFont
        f = TTFont(path, lazy=True)
        if "OS/2" in f:
            t = f["OS/2"].fsType; out["fstype"] = t; out["restricted"] = bool(t & 0x2 or t & 0x4)
        n = f["name"]; out["family"] = n.getDebugName(1) or ""; out["meta_licence"] = ((n.getDebugName(13) or "") + " " + (n.getDebugName(14) or "")).strip()
    except Exception:
        pass
    return out
