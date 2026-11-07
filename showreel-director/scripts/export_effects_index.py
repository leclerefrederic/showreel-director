#!/usr/bin/env python3
"""Generate references/effects-index.md from the fx(...) registry in engine/effects/*.js."""
import re, glob, os, sys, collections
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
consts = {}; rows = collections.OrderedDict()
pat = re.compile(r"(?:^|[;\s])(?:fx|tr|trk|dots|ring)\(\s*([A-Za-z_]\w*|'[^']*'|\"[^\"]*\")\s*,\s*'((?:[^'\\]|\\.)*)'\s*,\s*'((?:[^'\\]|\\.)*)'\s*,\s*'(\w+)'\s*,\s*([\d.]+)")
for f in sorted(glob.glob(os.path.join(root, "engine", "effects", "*.js"))):
    s = open(f, encoding="utf-8").read()
    for m in re.finditer(r"(?:const|let|var)\s+(\w+)\s*=\s*('[^']*')\s*[,;]", s):
        consts[m.group(1)] = m.group(2).strip("'")
    for m in re.finditer(r",\s*(\w+)\s*=\s*'([^']*)'", s):
        consts.setdefault(m.group(1), m.group(2))
    for m in pat.finditer(s):
        cat = m.group(1); cat = consts.get(cat, cat.strip("'\""))
        rows.setdefault(cat, []).append((m.group(2), m.group(3), m.group(4), m.group(5)))
tpat = re.compile(r"(?:^|[;\s])tr\(\s*'((?:[^'\\]|\\.)*)'\s*,\s*'((?:[^'\\]|\\.)*)'\s*,\s*'(\w+)'\s*,\s*([\d.]+)")
for f in sorted(glob.glob(os.path.join(root, "engine", "effects", "*.js"))):
    for m in tpat.finditer(open(f, encoding="utf-8").read()):
        rows.setdefault("Scene transitions", []).append((m.group(1), m.group(2), m.group(3), m.group(4)))
n = sum(len(v) for v in rows.values())
out = ["# Effects index (generated)", "", f"{n} effects. Regenerate with `python3 scripts/export_effects_index.py`. Preview them live with the effects lab.", ""]
for cat, items in rows.items():
    out += [f"## {cat} ({len(items)})", "", "| Effect | What the viewer sees | Energy | Duration (s) |", "|---|---|---|---|"]
    out += [f"| {a} | {b} | {c} | {d} |" for a, b, c, d in items] + [""]
p = os.path.join(root, "references", "effects-index.md")
open(p, "w", encoding="utf-8").write("\n".join(out))
print(f"{n} effects indexed -> {p}")
