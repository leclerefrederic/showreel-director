#!/usr/bin/env python3
"""Self-test of scripts/assemble.py on the test film evals/film-spike/v3 (copied to a scratch folder): determinism, one zone per scene, placeholders, the older format.
Usage: python3 scripts/test_assemble.py   (exit 1 on a failure; prints one line per check)"""
import json, os, re, shutil, subprocess, sys, tempfile
sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import assemble as A

SRC = os.path.join(HERE, "..", "evals", "film-spike", "v3")
fails = []

def check(name, cond, why=""):
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else (": " + why if why else "")))
    if not cond: fails.append(name)

def zones(text):
    return {m.group(1): m.group(0) for m in re.finditer(r"  // >>> scene (\S+) .*?\n  // <<< scene \1\n", text, flags=re.S)}

def main():
    td = tempfile.mkdtemp()
    try:
        v = os.path.join(td, "v1"); shutil.copytree(SRC, v)
        r1 = A.assemble(v); b1 = open(os.path.join(v, "main.js"), "rb").read(); j1 = open(os.path.join(v, "assembly.json"), "rb").read()
        r2 = A.assemble(v); b2 = open(os.path.join(v, "main.js"), "rb").read(); j2 = open(os.path.join(v, "assembly.json"), "rb").read()
        check("same inputs give the same bytes, twice in a row (main.js and assembly.json)", b1 == b2 and j1 == j2 and r1 == r2)
        w = os.path.join(td, "w1"); shutil.copytree(SRC, w); A.assemble(w)
        check("a copy of the folder elsewhere gives the same main.js", open(os.path.join(w, "main.js"), "rb").read() == b1)
        check("the assembled file says it is generated and holds one zone per scene of film.json", b1.decode().startswith("/* " + A.MARK) and sorted(zones(b1.decode())) == ["S01", "S02", "S03"])
        check("nothing is listed as not generated when every scene has a file", r1["ungenerated"] == [] and all(s["status"] == "module" for s in r1["scenes"]))

        # changing one scene file changes only its zone
        p2 = os.path.join(v, "scenes", "S02.js"); t2 = open(p2).read(); open(p2, "w").write(t2.replace("'Two'", "'Deux'"))
        A.assemble(v); b3 = open(os.path.join(v, "main.js"), encoding="utf-8").read()
        z1, z3 = zones(b1.decode()), zones(b3)
        rest1, rest3 = b1.decode(), b3
        for k in z1: rest1 = rest1.replace(z1[k], "")
        for k in z3: rest3 = rest3.replace(z3[k], "")
        check("changing one scene file changes only the zone of that scene", z1["S01"] == z3["S01"] and z1["S03"] == z3["S03"] and z1["S02"] != z3["S02"] and "Deux" in z3["S02"] and rest1 == rest3)
        open(p2, "w").write(t2)
        A.assemble(v); check("putting the file back gives the first bytes again", open(os.path.join(v, "main.js"), "rb").read() == b1)

        # a scene without a module: placeholder, flagged, the film is still assembled
        os.remove(p2); r = A.assemble(v); t = open(os.path.join(v, "main.js"), encoding="utf-8").read(); z = zones(t)
        check("a scene without a file is replaced by a placeholder and listed as not generated", r["ungenerated"] == ["S02"] and 'MODULES["S02"] = placeholder("S02"' in z["S02"] and 'mod("S02"' not in z["S02"])
        check("the other zones are untouched by a missing scene", z["S01"] == z1["S01"] and z["S03"] == z1["S03"])
        open(p2, "w").write("   \n")
        r = A.assemble(v); check("an empty file counts as not generated", r["ungenerated"] == ["S02"])
        open(p2, "w").write("const x = ;\nreturn function (g) {};\n")
        r = A.assemble(v)
        if shutil.which("node"):
            row = next(s for s in r["scenes"] if s["id"] == "S02")
            check("a scene file that is not valid JavaScript gets a placeholder and a reason", r["ungenerated"] == ["S02"] and row["status"] == "invalid" and "not valid JavaScript" in row["message"], str(row))
        open(p2, "w").write("const k = 1;\n")
        r = A.assemble(v); row = next(s for s in r["scenes"] if s["id"] == "S02")
        check("a file with no return is flagged, not silently broken", r["ungenerated"] == ["S02"] and row["status"] == "invalid" and "no return" in row["message"])
        open(p2, "w").write(t2)
        open(os.path.join(v, "scenes", "S09.js"), "w").write("return function () {};\n")
        r = A.assemble(v); check("a scene file that film.json does not list is ignored and reported as unused", r["unused"] == ["S09"] and "S09" not in open(os.path.join(v, "main.js")).read())
        os.remove(os.path.join(v, "scenes", "S09.js"))
        open(p2, "wb").write(t2.replace("\n", "\r\n").encode())
        A.assemble(v); check("line endings of a file do not change main.js", open(os.path.join(v, "main.js"), "rb").read() == b1)
        open(p2, "w").write(t2)

        # without reel.js the neutral defaults are used and the file is still valid JavaScript
        nr = os.path.join(td, "noreel"); shutil.copytree(SRC, nr); os.remove(os.path.join(nr, "reel.js")); rr = A.assemble(nr)
        okjs = (not shutil.which("node")) or subprocess.run(["node", "--check", os.path.join(nr, "main.js")], capture_output=True).returncode == 0
        check("without reel.js the assembler uses neutral defaults and main.js is valid", rr["reel"] == "default" and okjs and "palette: { bg: '#111111'" in open(os.path.join(nr, "main.js")).read())

        # --check
        cli = lambda *a: subprocess.run([sys.executable, os.path.join(HERE, "assemble.py")] + list(a), capture_output=True, text=True)
        check("--check passes on an up-to-date main.js and fails on an edited one", cli(v, "--check").returncode == 0 and (open(os.path.join(v, "main.js"), "a").write("//x\n") or True) and cli(v, "--check").returncode == 1)
        A.assemble(v)

        # the older format: a hand-written main.js is never overwritten, and build.py does not assemble a folder without scenes/
        h = os.path.join(td, "old"); os.makedirs(h); shutil.copy(os.path.join(SRC, "film.json"), h); open(os.path.join(h, "main.js"), "w").write("// hand written\n")
        rc = cli(h)
        check("a hand-written main.js is refused, never overwritten", rc.returncode != 0 and open(os.path.join(h, "main.js")).read() == "// hand written\n" and "was not written by the assembler" in rc.stderr)
        check("a version with no scenes/ folder is the older format", not A.uses_scene_files(h) and A.uses_scene_files(v))
        sys.stdout.flush()
    finally:
        shutil.rmtree(td, ignore_errors=True)
    if fails: sys.exit(1)

if __name__ == "__main__":
    main()
