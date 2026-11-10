#!/usr/bin/env python3
"""Generates the agent view of the documentation vault (docs/) from the properties of its notes. Stdlib only, no network, no git.
Usage: python3 tools/docs_index.py [--write | --check | --selftest] [--root DIR]
  --write     regenerate docs/Index.md and the generated blocks (Home: where-we-are; ideas.md: questions and ideas)
  --check     fail (exit 1, one line per problem) when Index.md or a generated block is out of date
  --selftest  test the script on a small tree
The notes and their properties are the only source. Index.md is reserved for agents and never edited by hand; the blocks between <!-- generated:NAME --> and
<!-- /generated:NAME --> are never edited by hand either. The output is deterministic: a second run changes nothing."""
import json, os, re, sys, tempfile

BLOCK = r"<!-- generated:{n} -->\n(.*?)\n<!-- /generated:{n} -->"

def rd(p): return open(p, encoding="utf-8").read()

def props(t):
    m = re.match(r"---\n(.*?)\n---\n", t, re.S)
    if not m: return None
    out = {}
    for ln in m.group(1).splitlines():
        k = re.match(r"^([A-Za-z_]+):\s*(.*)$", ln)
        if k:
            v = k.group(2).strip()
            if v.startswith('"'):
                try: v = json.loads(v)
                except ValueError: pass
            out[k.group(1)] = v
    return out

def load(root):
    docs = os.path.join(root, "docs"); notes = []
    for d, ds, fs in os.walk(docs):
        ds[:] = sorted(x for x in ds if x != ".obsidian")
        for f in sorted(fs):
            if not f.endswith(".md"): continue
            p = os.path.join(d, f); rel = os.path.relpath(p, docs)
            if rel == "Index.md": continue
            pr = props(rd(p))
            if pr is not None: notes.append((rel, pr))
    return notes

def cell(s): return str(s).replace("|", "\\|").replace("\n", " ")

def row(rel, pr): return f"| `{rel}` | {pr.get('type','')} | {pr.get('status','')} | {pr.get('phase','')} | {pr.get('date','')} | {cell(pr.get('summary',''))} |"
HEAD = "| path | type | status | phase | date | summary |\n|---|---|---|---|---|---|"

def versions(root):
    app = json.loads(rd(os.path.join(root, "app-swift", "shared", "app-version.json")))["version"]
    m = re.search(r"^\s*version:\s*\"?([0-9][0-9.]*)\"?\s*$", rd(os.path.join(root, "showreel-director", "SKILL.md")).split("\n---\n")[0], re.M)
    c = rd(os.path.join(root, "CLAUDE.md"))
    last = re.search(r"the last built is ([A-Za-z0-9]+)", c); nxt = re.search(r"Next: (.*?)\. Later:", c, re.S)
    return app, (m.group(1) if m else "?"), (last.group(1) if last else "?"), (nxt.group(1).strip() if nxt else "?")

def by(notes, folder): return [(r, p) for r, p in notes if r.startswith(folder + "/")]
def newest(items): return sorted(items, key=lambda x: (x[1].get("date", ""), x[0]), reverse=False)[::-1]

def where_we_are(root, notes):
    app, skill, last, nxt = versions(root)
    link = next((f"[[phases/{last}/{k}]]" for k in ("report", "summary") if os.path.exists(os.path.join(root, "docs", "phases", last, k + ".md"))), "")
    return "\n".join([f"- App version: **{app}**. Skill version: **{skill}**.",
                      f"- Last built phase: **{last}**" + (f", report in {link}." if link else "."),
                      f"- Next, in the order of `CLAUDE.md`: {nxt}."])

def questions_block(notes):
    qs = [(r, p) for r, p in newest(by(notes, "questions")) if p.get("status") == "current"]
    lines = [f"- [[{r[:-3]}|{os.path.basename(r)[:-3]}]] ({p.get('phase','')}, {p.get('date','')}): {p.get('summary','')}" for r, p in qs]
    return "\n".join(lines) if lines else "No open question."

def ideas_block(notes):
    its = newest(by(notes, "ideas"))
    return "\n".join(f"- [[{r[:-3]}|{os.path.basename(r)[:-3]}]] ({p.get('area','')}, {p.get('status','')}): {p.get('summary','')}" for r, p in its)

def phase_rows(notes):
    """One row per phase ID, from the properties of the phase notes (a prompt, a report, a summary, or a flat early note that covers several IDs)."""
    rows = {}
    for rel, p in notes:
        if not rel.startswith(("phases/", "archive/")) or p.get("type") not in ("phase-prompt", "phase-report"): continue
        ids = [x.strip() for x in p["phases"].strip("[]").split(",") if x.strip()] if p.get("phases") else ([p["phase"]] if p.get("phase") else [])
        kind = "prompt" if p["type"] == "phase-prompt" else "summary" if (rel.endswith("/summary.md") or rel.startswith("phases/early/")) else "report"
        for i in ids: rows.setdefault(i, {})[kind] = (rel, p)
    return rows

def phases_block(root, notes):
    rows = phase_rows(notes); out = ["| phase | date | status | app | skill | prompt | report | summary |", "|---|---|---|---|---|---|---|---|"]
    def key(i):
        r = rows[i]; main = (r.get("report") or r.get("prompt") or r.get("summary"))[1]; return (main.get("date", ""), i)
    for i in sorted(rows, key=key):
        r = rows[i]; main = (r.get("report") or r.get("prompt") or r.get("summary"))[1]; rep = (r.get("report") or (None, {}))[1]
        lk = lambda k: f"[[{r[k][0][:-3]}\\|{k}]]" if k in r else ""
        out.append(f"| {i} | {main.get('date','')} | {main.get('status','')} | {rep.get('app_version','')} | {rep.get('skill_version','')} | {lk('prompt')} | {lk('report')} | {lk('summary')} |")
    return "\n".join(out)

def index(root, notes):
    app, skill, last, nxt = versions(root)
    phases = sorted({r.split("/")[1] for r, _ in by(notes, "phases") if r.split("/")[1] != "early" and "/" in r[len("phases/"):]})
    st = lambda f: sum(1 for _, p in by(notes, "ideas") if p.get("status") == f)
    openq = [os.path.basename(r)[:-3] for r, p in newest(by(notes, "questions")) if p.get("status") == "current"]
    out = ["---", "type: reference", "status: current", "phase: ", f"date: {max(p.get('date','') for _, p in notes)}",
           'summary: "The agent view of the vault: one line per note, generated from the properties of the notes. Never edited by hand."', "tags:", "  - index", "  - generated", "---", "",
           "# Index of the vault (for agents)", "",
           "> [!important] Reserved for agents, generated, never edited by hand",
           "> Generated by `tools/docs_index.py` from the properties of the notes. Regenerate with `python3 tools/docs_index.py --write`. Read this first, then open only the note you need.",
           "> Never read `.base` or `.canvas` files: they are for Obsidian. To triage without opening a note: `grep '^summary:' docs/<folder>/*.md`.", "",
           "## Status", "",
           f"- App {app}, skill {skill}. Last built phase: {last}. Next: {nxt}.",
           f"- {len(notes)} notes. Ideas: {len(by(notes, 'ideas'))} ({st('draft')} parked, {st('current')} wanted soon, {st('superseded')} built or promoted).",
           f"- Open questions ({len(openq)}): " + "; ".join(openq) + "." if openq else "- Open questions: none.", ""]
    def table(title, items, note=""):
        out.extend([f"## {title}", ""] + ([note, ""] if note else []) + [HEAD] + [row(r, p) for r, p in items] + [""])
    roots = [(r, p) for r, p in notes if "/" not in r]
    table("Entry notes and hubs", roots, "Hubs keep their old paths: `studio-spec.md`, `ux-notes.md`, `phases-done.md`, `ideas.md`.")
    table("Spec (sections of studio-spec.md)", by(notes, "spec"))
    table("UX notes (blocks of ux-notes.md)", by(notes, "ux"))
    table("Decisions", newest(by(notes, "decisions")))
    table("Questions", newest(by(notes, "questions")), "`status: current` is open, `superseded` is settled.")
    table("Ideas", newest(by(notes, "ideas")), "`status`: draft is parked, current is wanted soon, superseded is built or promoted.")
    table("Archive (reports that span several phases)", by(notes, "archive"))
    out.extend(["## Phases", "", "One line per phase folder `phases/<ID>/`: its files, the versions of its report and the summary of its report (or of its summary, or of its prompt).", "",
                "| phase | files | app | skill | date | summary |", "|---|---|---|---|---|---|"])
    for ph in phases:
        fs = {k: next((p for r, p in notes if r == f"phases/{ph}/{k}.md"), None) for k in ("prompt", "report", "summary")}
        main = fs["report"] or fs["summary"] or fs["prompt"]
        out.append(f"| `phases/{ph}/` | {', '.join(k for k, v in fs.items() if v)} | {(fs['report'] or {}).get('app_version', '')} | {(fs['report'] or {}).get('skill_version', '')} | {main.get('date','')} | {cell(main.get('summary',''))} |")
    out.extend(["", "## Early phases (flat notes in phases/early/)", "", "One line per note; a note may cover several phases (`phases`).", "", "| path | phases | date | summary |", "|---|---|---|---|"])
    for r, p in sorted(by(notes, "phases"), key=lambda x: x[0]):
        if r.startswith("phases/early/"): out.append(f"| `{r}` | {p.get('phases','')} | {p.get('date','')} | {cell(p.get('summary',''))} |")
    return "\n".join(out) + "\n"

BLOCKS = {"Home.md": {"where-we-are": where_we_are}, "ideas.md": {"questions": lambda r, n: questions_block(n), "ideas": lambda r, n: ideas_block(n)},
          "phases-done.md": {"phases": lambda r, n: phases_block(r, n)}}

def expected(root):
    """Every generated file as it should be: {relative path in docs: text}."""
    notes = load(root); out = {"Index.md": index(root, notes)}
    for rel, blocks in BLOCKS.items():
        p = os.path.join(root, "docs", rel)
        if not os.path.exists(p): continue
        t = rd(p)
        for n, fn in blocks.items():
            body = fn(root, notes) if fn is where_we_are else fn(root, notes)
            t = re.sub(BLOCK.format(n=re.escape(n)), lambda m: f"<!-- generated:{n} -->\n{body}\n<!-- /generated:{n} -->", t, count=1, flags=re.S)
        out[rel] = t
    return out

def problems(root):
    out = []
    for rel, want in expected(root).items():
        p = os.path.join(root, "docs", rel)
        if not os.path.exists(p): out.append(f"docs/{rel}: missing (run: python3 tools/docs_index.py --write)"); continue
        if rd(p) != want: out.append(f"docs/{rel}: out of date, or a generated part was edited by hand (run: python3 tools/docs_index.py --write)")
    for rel, blocks in BLOCKS.items():
        p = os.path.join(root, "docs", rel)
        if os.path.exists(p):
            for n in blocks:
                if not re.search(BLOCK.format(n=re.escape(n)), rd(p), re.S): out.append(f"docs/{rel}: the markers of the generated block '{n}' are missing")
    return out

def write(root):
    changed = []
    for rel, want in expected(root).items():
        p = os.path.join(root, "docs", rel)
        if not os.path.exists(p) or rd(p) != want: open(p, "w", encoding="utf-8").write(want); changed.append(rel)
    return changed

def selftest():
    with tempfile.TemporaryDirectory() as r:
        def w(p, t): os.makedirs(os.path.dirname(os.path.join(r, p)), exist_ok=True); open(os.path.join(r, p), "w", encoding="utf-8").write(t)
        def fm(typ, status, summ, extra=""): return f"---\ntype: {typ}\nstatus: {status}\nphase: \ndate: 2026-01-0{1 if typ!='idea' else 2}\nsummary: {json.dumps(summ)}\n{extra}tags:\n  - t\n---\n\nbody\n"
        w("app-swift/shared/app-version.json", '{"version": "1.2.3"}\n'); w("showreel-director/SKILL.md", "---\nname: x\nmetadata:\n  version: \"0.4.5\"\n---\ntext\n")
        w("CLAUDE.md", "the last built is AB1 (x). Next: CD2 (y), EF3 (z). Later: more.\n"); w("docs/phases/AB1/report.md", fm("phase-report", "current", "Report A.", "app_version: 1.2.3\n"))
        w("docs/Home.md", fm("reference", "current", "Home.") + "<!-- generated:where-we-are -->\nstale\n<!-- /generated:where-we-are -->\n")
        w("docs/ideas.md", fm("idea", "current", "Ideas.") + "<!-- generated:questions -->\nx\n<!-- /generated:questions -->\n<!-- generated:ideas -->\nx\n<!-- /generated:ideas -->\n")
        w("docs/questions/Open one.md", fm("question", "current", "Is it open?")); w("docs/questions/Settled one.md", fm("question", "superseded", "Settled."))
        w("docs/ideas/An idea.md", fm("idea", "draft", "An idea | with a bar.", "area: app\n"))
        w("docs/phases-done.md", fm("reference", "current", "Phases.") + "<!-- generated:phases -->\nx\n<!-- /generated:phases -->\n")
        w("docs/phases/early/Early thing.md", fm("phase-report", "current", "Early.", "phases: [E1, E2]\n").replace("phase: ", "phase: E1")); w("docs/phases/AB1/prompt.md", fm("phase-prompt", "current", "Prompt A.").replace("phase: ", "phase: AB1"))
        assert problems(r), "a stale tree must have problems"
        ch = write(r); assert "Index.md" in ch and "Home.md" in ch and "ideas.md" in ch, ch
        assert not problems(r), problems(r); assert write(r) == [], "a second run changes nothing"
        idx = rd(os.path.join(r, "docs", "Index.md")); home = rd(os.path.join(r, "docs", "Home.md")); ide = rd(os.path.join(r, "docs", "ideas.md"))
        assert "Open one" in ide.split("generated:ideas")[0] and "Settled one" not in ide, "only open questions are listed"
        assert "App version: **1.2.3**" in home and "Skill version: **0.4.5**" in home and "[[phases/AB1/report]]" in home and "CD2 (y), EF3 (z)" in home
        assert "An idea \\| with a bar." in idx and "`phases/AB1/`" in idx
        pd = rd(os.path.join(r, "docs", "phases-done.md")); assert "| E1 |" in pd and "| E2 |" in pd and "| AB1 |" in pd and "[[phases/early/Early thing\\|summary]]" in pd, pd
        assert "`phases/early/Early thing.md` | [E1, E2]" in idx
        p = os.path.join(r, "docs", "Home.md"); edited = rd(p).replace("**1.2.3**", "**9.9.9**"); open(p, "w", encoding="utf-8").write(edited)
        assert any("Home.md" in x for x in problems(r)), "a hand edit inside a generated block is caught"
        write(r); assert not problems(r), problems(r)
    print("docs_index selftest ok")

def main():
    if "--selftest" in sys.argv: return selftest()
    root = sys.argv[sys.argv.index("--root") + 1] if "--root" in sys.argv else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if "--write" in sys.argv:
        ch = write(root); print("docs_index: " + (", ".join("docs/" + c for c in ch) + " updated" if ch else "nothing to change")); return
    if "--check" in sys.argv:
        pr = problems(root)
        for x in pr: print("FAIL " + x)
        print(f"docs_index: {len(pr)} problem(s)" if pr else "docs_index: ok"); sys.exit(1 if pr else 0)
    sys.exit(__doc__)

if __name__ == "__main__":
    sys.dont_write_bytecode = True
    main()
