#!/usr/bin/env python3
"""Fetch a chosen free font (files and licence) from the Google Fonts open repository into a folder.

Usage: python3 fetch_font.py "Poppins" [--dest DIR] [--weights 400,700] [--dry-run]
Looks the font up in engine/fonts-free.json, lists ofl/<dir> in github.com/google/fonts and downloads the .ttf files (plus OFL.txt).
Default destination: ./downloaded-fonts/<dir>/ : then hand the folder to `organize_assets.py --from` like any supplied file (the organiser links the licence).
Never installs anything. If the network is blocked, it says so and prints the specimen page for a manual download.
"""
import argparse, json, os, sys, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))


def get(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": "showreel-director-font-fetch"})
    with urllib.request.urlopen(req, timeout=20) as r:
        data = r.read()
    return data if binary else json.loads(data)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name"); ap.add_argument("--dest"); ap.add_argument("--weights", help="keep only static files for these weights, e.g. 400,700 (variable fonts are kept whole)")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    fonts = json.load(open(os.path.join(HERE, "..", "engine", "fonts-free.json"), encoding="utf-8"))
    f = next((x for x in fonts if x["name"].lower() == a.name.lower()), None)
    if not f:
        print("not in the curated list: " + ", ".join(x["name"] for x in fonts)); return 1
    spec = "https://fonts.google.com/specimen/" + f["name"].replace(" ", "+")
    api = "https://api.github.com/repos/google/fonts/contents/ofl/" + f["dir"]
    try:
        listing = get(api)
    except (urllib.error.URLError, OSError, ValueError) as e:
        print(f"cannot reach the font repository ({e}). Download {f['name']} by hand from {spec} and give the folder to the organiser."); return 2
    wanted = {w.strip() for w in a.weights.split(",")} if a.weights else None
    names = {"400": "Regular", "700": "Bold", "300": "Light", "500": "Medium", "600": "SemiBold", "800": "ExtraBold", "900": "Black"}
    files = []
    for it in listing:
        n = it["name"]
        if n.lower().endswith(".ttf") or n in ("OFL.txt", "LICENSE.txt"):
            if wanted and n.lower().endswith(".ttf") and "[" not in n and not any(names.get(w, w) in n for w in wanted): continue
            files.append(it)
    if not any(x["name"].lower().endswith(".ttf") for x in files):
        print(f"no .ttf file found for {f['name']}; download it from {spec}"); return 2
    dest = os.path.join(a.dest or "downloaded-fonts", f["dir"])
    for it in files:
        print(("would fetch " if a.dry_run else "fetching ") + it["name"] + " (%d KB)" % (it.get("size", 0) // 1024))
    if a.dry_run: return 0
    os.makedirs(dest, exist_ok=True)
    for it in files:
        open(os.path.join(dest, it["name"]), "wb").write(get(it["download_url"], binary=True))
    print(f"done: {len(files)} file(s) in {dest}. Licence: {f.get('license', 'OFL')} (kept next to the font). Next: organize_assets.py <project> --from {dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
