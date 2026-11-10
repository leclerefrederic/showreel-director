#!/usr/bin/env python3
"""Creates an idea, a question or a decision in the vault with every required property and the next free ID. Stdlib only, no network, no git.
Usage: python3 tools/docs_new.py <idea|question|decision> "<title>" [--summary "one sentence"] [--area app|skill|docs|tooling] [--source owner|assistant] [--root DIR] | --selftest
This is the only way agents create these three kinds: it allocates the ID (IDEA-001, QUESTION-001, DECISION-001, three digits, never reused, never renumbered) in docs/Claude/ids.json,
refuses a title that already exists, writes the note, then runs docs_index.py --write so that the index and the generated blocks follow. Rewrite the summary afterwards if you did not pass one."""
import datetime, json, os, re, sys, tempfile

KINDS = {"idea": ("ideas", "IDEA"), "question": ("questions", "QUESTION"), "decision": ("decisions", "DECISION")}
BAD = re.compile(r'[\\/:*?"<>|#^\[\]]')

def create(root, kind, title, summary=None, area="app", source="assistant", today=None):
    folder, prefix = KINDS[kind]
    if not title.strip() or BAD.search(title) or len(title) > 120: raise SystemExit(f"docs_new: the title must be a short sentence with none of  / \\ : * ? \" < > | # ^ [ ]  (got {title!r})")
    cl = os.path.join(root, "docs", "Claude"); regp = os.path.join(cl, "ids.json"); path = os.path.join(cl, folder, title + ".md")
    reg = json.load(open(regp, encoding="utf-8")) if os.path.exists(regp) else {}
    existing = {f[:-3].lower() for f in os.listdir(os.path.join(cl, folder))} if os.path.isdir(os.path.join(cl, folder)) else set()
    if title.lower() in existing: raise SystemExit(f"docs_new: a {kind} titled {title!r} already exists: open it instead of creating another")
    n = int(reg.get(kind, 0)) + 1; ident = f"{prefix}-{n:03d}"; d = today or datetime.date.today().isoformat()
    summary = (summary or title.rstrip("?.") + ("?" if kind == "question" else ".")).strip()
    if len(summary) > 160: raise SystemExit(f"docs_new: the summary has {len(summary)} characters (at most 160)")
    fm = ["---", f"type: {kind}", f"status: {'draft' if kind == 'idea' else 'current'}", "phase: ", f"date: {d}", f"summary: {json.dumps(summary, ensure_ascii=False)}", f"id: {ident}", "aliases:", f'  - "{ident}"', f"since: {d}"]
    if kind == "idea": fm += [f"area: {area}", f"source: {source}", 'origin: "docs_new.py"']
    if kind == "question": fm += ["blocks: []", 'recommendation: "none yet"']
    if kind == "decision": fm += ["affects: []"]
    fm += ["tags:", f"  - {kind}", "---", "", f"# {title}", "", summary, ""]
    os.makedirs(os.path.dirname(path), exist_ok=True); open(path, "w", encoding="utf-8").write("\n".join(fm))
    reg[kind] = n; json.dump(reg, open(regp, "w", encoding="utf-8"), indent=1); open(regp, "a").write("\n")
    return ident, path

def selftest():
    with tempfile.TemporaryDirectory() as r:
        os.makedirs(os.path.join(r, "docs", "Claude", "ideas")); json.dump({"idea": 4}, open(os.path.join(r, "docs", "Claude", "ids.json"), "w"))
        i, p = create(r, "idea", "A test idea", today="2026-01-02"); assert i == "IDEA-005" and os.path.exists(p), i
        t = open(p, encoding="utf-8").read(); assert "id: IDEA-005" in t and '  - "IDEA-005"' in t and "status: draft" in t and "since: 2026-01-02" in t and "area: app" in t
        i2, _ = create(r, "idea", "Another", area="docs", source="owner", today="2026-01-02"); assert i2 == "IDEA-006"
        q, qp = create(r, "question", "Is it open", today="2026-01-02"); assert q == "QUESTION-001" and "blocks: []" in open(qp, encoding="utf-8").read()
        d, dp = create(r, "decision", "We chose this", summary="We chose this.", today="2026-01-02"); assert d == "DECISION-001" and "affects: []" in open(dp, encoding="utf-8").read()
        try: create(r, "idea", "a test IDEA"); raise AssertionError("a duplicate title must be refused")
        except SystemExit as e: assert "already exists" in str(e)
        try: create(r, "idea", "bad/title"); raise AssertionError("a bad title must be refused")
        except SystemExit as e: assert "title" in str(e)
        assert json.load(open(os.path.join(r, "docs", "Claude", "ids.json"))) == {"idea": 6, "question": 1, "decision": 1}
    print("docs_new selftest ok")

def main():
    a = sys.argv[1:]
    if "--selftest" in a: return selftest()
    root = a[a.index("--root") + 1] if "--root" in a else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    opt = lambda k, default=None: a[a.index(k) + 1] if k in a else default
    pos = [x for i, x in enumerate(a) if not x.startswith("--") and (i == 0 or not a[i - 1].startswith("--"))]
    if len(pos) != 2 or pos[0] not in KINDS: sys.exit(__doc__)
    ident, path = create(root, pos[0], pos[1], opt("--summary"), opt("--area", "app"), opt("--source", "assistant"))
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import docs_index
    docs_index.write(root)
    print(f"docs_new: {ident} created at {os.path.relpath(path, root)}; the index and the generated blocks are regenerated")

if __name__ == "__main__":
    sys.dont_write_bytecode = True
    main()
