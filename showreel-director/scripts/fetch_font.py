#!/usr/bin/env python3
"""Fetch a chosen free font (files and licence) from Google Fonts' open repository into a folder.

Usage: python3 fetch_font.py "Poppins" [--dest DIR] [--weights 400,700] [--dry-run]
Looks the font up in engine/fonts-free.json, which lists the files to take (names, weights, sizes, licence file), and downloads them from the open google/fonts repository
(raw.githubusercontent.com, by path: no API, no key, no account). A file the repository holds under another name comes from Google Fonts' own download list instead.
Default destination: ./downloaded-fonts/<dir>/ : then hand the folder to `organize_assets.py --from` like any supplied file (the organiser links the licence).
Never installs anything. If the network is blocked, it says so and prints the specimen page for a manual download.
"""
import argparse, json, os, sys, urllib.request, urllib.error, urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))


def get(url, binary=True):
    req = urllib.request.Request(url, headers={"User-Agent": "showreel-director-font-fetch"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read()
    return data if binary else json.loads(data.decode("utf-8").removeprefix(")]}'"))


def from_list(font, name):
    """The file by its name in Google Fonts' download list (served from fonts.gstatic.com)."""
    m = get("https://fonts.google.com/download/list?family=" + urllib.parse.quote(font["name"]), binary=False)["manifest"]
    ref = next((f for f in m["fileRefs"] if f["filename"] == name or f["filename"].endswith("/" + name)), None)
    if not ref: raise ValueError(name + " is not in the download list")
    return get(ref["url"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name"); ap.add_argument("--dest"); ap.add_argument("--weights", help="keep only static files for these weights, e.g. 400,700 (a variable font is kept whole)")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    fonts = json.load(open(os.path.join(HERE, "..", "engine", "fonts-free.json"), encoding="utf-8"))
    f = next((x for x in fonts if x["name"].lower() == a.name.lower()), None)
    if not f:
        print("not in the curated list: " + ", ".join(x["name"] for x in fonts)); return 1
    spec = f.get("specimen") or "https://fonts.google.com/specimen/" + f["name"].replace(" ", "+")
    wanted = {int(w) for w in a.weights.split(",")} if a.weights else None
    files = [x for x in f.get("files", []) if x.get("variable") or not wanted or x.get("weight") in wanted]
    if not files:
        print(f"no file is listed for {f['name']}; download it from {spec}"); return 2
    base = f"https://raw.githubusercontent.com/google/fonts/main/{f.get('tree', 'ofl')}/{f['dir']}/"
    dest = os.path.join(a.dest or "downloaded-fonts", f["dir"])
    licence = f.get("licenseFile", "OFL.txt")
    for x in files:
        print(("would fetch " if a.dry_run else "fetching ") + x["name"] + " (%d KB)" % (x.get("size", 0) // 1024))
    if a.dry_run: return 0
    os.makedirs(dest, exist_ok=True)
    try:
        for x in files + [{"name": licence}]:
            try:
                data = get(base + urllib.parse.quote(x["name"])) if not x.get("list") else from_list(f, x["list"])
            except (urllib.error.URLError, OSError, ValueError):
                if x["name"] == licence: raise
                data = from_list(f, x.get("list") or x["name"])
            if not data: raise ValueError(x["name"] + " is empty")
            open(os.path.join(dest, x["name"]), "wb").write(data)
    except (urllib.error.URLError, OSError, ValueError) as e:
        print(f"cannot download the font ({e}). Download {f['name']} by hand from {spec} and give the folder to the organiser."); return 2
    print(f"done: {len(files)} file(s) in {dest}. Licence: {f.get('license', 'SIL Open Font License 1.1')} (kept next to the font). Next: organize_assets.py <project> --from {dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
