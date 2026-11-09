#!/usr/bin/env python3
"""Maintainer script: refresh the file lists of showreel-director/engine/fonts-free.json.

Usage: python3 tools/refresh_font_manifest.py [--only "Anton,Poppins"] [--dry-run] [--pause 0.3]
For each font of the list it asks Google Fonts' own download list (fonts.google.com/download/list, one call per family, no key and no account) for the names of the files,
keeps the files the app can embed (the 400 and 700 files of the family, or its variable file) and measures each one's size with a ranged request to the open repository
(raw.githubusercontent.com/google/fonts/main/ofl/<dir>/<file>, no API). It writes, for every font, a "files" list: name, weight, size in bytes (and "variable": true, with no weight, for a variable
file), plus "licenseFile" (relative to the family's folder) and "specimen". A file that the repository does not hold under that name carries "list": its name in the Google Fonts download list. The GitHub API is never called and no token is read or written. Run it rarely, by hand: it makes
about one request per family plus two or three per font.
The app builds its cards from this list without any network call, and uses the network only once the user has accepted the card.
"""
import argparse, json, os, re, sys, time, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
LIST = os.path.join(HERE, "..", "showreel-director", "engine", "fonts-free.json")
WEIGHTS = {"Thin": 100, "ExtraLight": 200, "Light": 300, "Regular": 400, "Medium": 500, "SemiBold": 600, "Bold": 700, "ExtraBold": 800, "Black": 900}
VARIABLE = ("[wght]", "[wdth,wght]", "[opsz,wght]", "[slnt,wght]", "[wght,GRAD]", "[opsz,wdth,wght]", "[SOFT,WONK,opsz,wght]", "[ital,wght]", "[YOPQ,wght]")
USED = (400, 700)       # the weights the Look asks for: titles at 700, text at 400


def fetch(url, headers=None, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": "showreel-director-font-manifest", **(headers or {})})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r, r.read()


def weight_of(name):
    m = re.search(r"-([A-Za-z]+?)(Italic)?\.ttf$", name)
    return WEIGHTS.get(m.group(1)) if m and not m.group(2) else None


def compact(name):
    return re.sub(r"[^A-Za-z0-9]", "", name)


def head_size(url):
    """The size of a file from a ranged request (one byte), or None when it is not there."""
    try:
        r, _ = fetch(url, {"Range": "bytes=0-0"})
    except urllib.error.HTTPError as e:
        if e.code == 404: return None
        raise
    cr = r.headers.get("Content-Range", "")
    return int(cr.split("/")[-1]) if "/" in cr else int(r.headers.get("Content-Length", 0))


TREES = {"ofl": "SIL Open Font License 1.1", "apache": "Apache License 2.0", "ufl": "Ubuntu Font Licence 1.0"}


def repo_url(directory, name, tree="ofl"):
    return f"https://raw.githubusercontent.com/google/fonts/main/{tree}/{directory}/{urllib.request.quote(name)}"


def family_files(font, pause):
    url = "https://fonts.google.com/download/list?family=" + urllib.request.quote(font["name"])
    _, body = fetch(url)
    text = body.decode("utf-8")
    if text.startswith(")]}'"): text = text[4:]
    m = json.loads(text)["manifest"]
    refs = {f["filename"]: f["url"] for f in m.get("fileRefs", [])}
    licence = next((f["filename"] for f in m.get("files", []) if f["filename"].upper().startswith(("OFL", "LICENSE"))), "OFL.txt")
    base = compact(font["name"]).lower()
    cname = compact(font["name"])
    # 1. the repository's own files: static ones (Name-Regular.ttf), else the variable file (one file for every weight). Most families are under ofl/ (SIL Open Font
    #    License); a few are under apache/ or ufl/, and the licence is said as the folder says it.
    for tree in TREES:
        time.sleep(pause)
        if head_size(repo_url(font["dir"], cname + "-Regular.ttf", tree)) is not None or head_size(repo_url(font["dir"], cname + "-Bold.ttf", tree)) is not None:
            out = []
            for w, word in ((400, "Regular"), (700, "Bold")):
                time.sleep(pause)
                size = head_size(repo_url(font["dir"], f"{cname}-{word}.ttf", tree))
                if size: out.append({"name": f"{cname}-{word}.ttf", "weight": w, "size": size})
            if out: return out, licence, tree
        for suffix in (VARIABLE if tree == "ofl" else ("[wght]",)):
            name = cname + suffix + ".ttf"
            time.sleep(pause)
            size = head_size(repo_url(font["dir"], name, tree))
            if size: return [{"name": name, "size": size, "variable": True}], licence, tree
    # 2. not in the repository under a name we know: the download list of Google Fonts serves static files (only those whose own name is the family's: an optical-size or
    #    width variant such as Inter_18pt is a different family for the font file)
    out = []
    for w in USED:
        ref = next((n for n in refs if weight_of(n.split("/")[-1]) == w and re.split(r"-", n.split("/")[-1])[0].replace("_", "").lower() == base), None)
        if not ref: continue              # a family may not have this weight (a display face has one): it is simply not listed
        time.sleep(pause)
        size = head_size(refs[ref])
        if size: out.append({"name": ref.split("/")[-1], "weight": w, "size": size, "list": ref})
    return out, licence, "ofl"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only"); ap.add_argument("--dry-run", action="store_true"); ap.add_argument("--pause", type=float, default=0.3)
    a = ap.parse_args()
    fonts = json.load(open(LIST, encoding="utf-8"))
    only = {x.strip().lower() for x in a.only.split(",")} if a.only else None
    failed = []
    for f in fonts:
        if only and f["name"].lower() not in only: continue
        try:
            files, lic, tree = family_files(f, a.pause)
        except (urllib.error.URLError, OSError, ValueError, KeyError) as e:
            failed.append(f["name"]); print(f"{f['name']}: failed ({e})", file=sys.stderr); continue
        if not files: failed.append(f["name"]); print(f"{f['name']}: no embeddable file found", file=sys.stderr); continue
        f["files"] = files; f["licenseFile"] = lic; f["license"] = TREES[tree]; f["tree"] = tree; f["specimen"] = "https://fonts.google.com/specimen/" + f["name"].replace(" ", "+")
        print(f"{f['name']}: " + ", ".join(x["name"] for x in files))
        time.sleep(a.pause)
    if not a.dry_run:
        with open(LIST, "w", encoding="utf-8") as fh:
            json.dump(fonts, fh, indent=1, ensure_ascii=False); fh.write("\n")
    if failed: print("not refreshed: " + ", ".join(failed), file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
