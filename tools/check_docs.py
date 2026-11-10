#!/usr/bin/env python3
"""Checks that the documentation vault (docs/) keeps its mechanics. Stdlib only, no network, no git.
Usage: python3 tools/check_docs.py [--root DIR] [--selftest]   (one line per problem, exit 1 when there is one; run by tools/check.py)

1. every path named in CLAUDE.md and in docs/Workflow.md exists;
2. every wikilink and every relative link in docs/ resolves (and its #heading exists);
3. every note has the properties of docs/Conventions.md, a summary of at most 160 characters, and every idea note has its idea properties;
4. the numbered sections that the comments of app-swift quote exist in docs/studio-spec.md (names such as "Scene content" are not checked: a known limit);
5. the section "Questions to settle with the owner" exists in docs/ideas.md and comes first;
6. no note contains what looks like a key or a token;
7. docs/Index.md and the generated blocks are up to date (tools/docs_index.py --check), so none was edited by hand;
8. file names carry no parenthesis, date, revision or version; a note whose name differs from its heading in a hub has that heading in its aliases (so an old title still resolves);
   no phase folder holds only a summary; no note is isolated outside archive/ and early/ (links in properties count); the headings that code and agents quote still exist;
9. the root of docs/ holds only Home.md, Dashboards/ and Claude/; every idea, question and decision has a well-formed, unique ID (also in its aliases) and the owner-facing properties,
   docs/Claude/ids.json allocates no ID whose note is gone; no comment of app-swift names the old path docs/studio-spec.md."""
import json, os, re, sys, tempfile

TYPES = {"spec", "ux", "phase-prompt", "phase-report", "decision", "idea", "question", "reference"}
STATUSES = {"draft", "current", "superseded"}
REQUIRED = ("type", "status", "phase", "date", "summary", "tags")
AREAS = {"app", "skill", "docs", "tooling"}
SOURCES = {"owner", "assistant"}
SUMMARY_MAX = 160
SECRETS = [r"sk-ant-[A-Za-z0-9_-]{20,}", r"sk-[A-Za-z0-9]{32,}", r"AKIA[0-9A-Z]{16}", r"ghp_[A-Za-z0-9]{36}", r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
           r"xox[baprs]-[A-Za-z0-9-]{10,}", r"Bearer [A-Za-z0-9._-]{30,}", r"AIza[0-9A-Za-z_-]{35}"]
ROOTS = ("docs/", "tools/", "app-swift/", "showreel-director/", ".claude/", "CLAUDE.md", "ROADMAP.md", "README.md", "CHANGELOG-APP.md", "RELEASE-NOTES-APP.md", "RELEASE-NOTES-SKILL.md")

def rd(p): return open(p, encoding="utf-8").read()

def notes(docs):
    out = []
    for d, ds, fs in os.walk(docs):
        ds[:] = [x for x in ds if x != ".obsidian"]
        out += [os.path.join(d, f) for f in fs if f.endswith(".md")]
    return sorted(out)

def strip_code(t):
    t = re.sub(r"```.*?```", "", t, flags=re.S)
    return re.sub(r"`[^`\n]*`", "", t)

def properties(t):
    m = re.match(r"---\n(.*?)\n---\n", t, re.S)
    if not m: return None
    props = {}
    for ln in m.group(1).splitlines():
        k = re.match(r"^([A-Za-z_]+):\s*(.*)$", ln)
        if k:
            v = k.group(2).strip()
            if v.startswith('"'):
                try: v = json.loads(v)
                except ValueError: pass
            props[k.group(1)] = v
    return props

def aliases(t):
    m = re.match(r"---\n(.*?)\n---\n", t, re.S)
    if not m: return []
    out = []; on = False
    for ln in m.group(1).splitlines():
        if re.match(r"^aliases:", ln):
            on = True; inline = ln.split(":", 1)[1].strip()
            if inline.startswith("["): out += [x.strip().strip('"') for x in inline.strip("[]").split(",") if x.strip()]
            continue
        if on and ln.startswith("  - "):
            v = ln[4:].strip()
            try: v = json.loads(v) if v.startswith('"') else v
            except ValueError: pass
            out.append(v)
        else: on = False
    return out

def headings(t): return {re.sub(r"\s+", " ", m.group(1)).strip() for m in re.finditer(r"^#{1,6} (.*?)\s*$", t, re.M)}

def check(root):
    docs = os.path.join(root, "docs"); claude = os.path.join(docs, "Claude"); problems = []
    relof = lambda f: os.path.relpath(f, claude) if f.startswith(claude + os.sep) else os.path.relpath(f, docs)          # Claude's notes are named from docs/Claude; Home.md from docs
    show = lambda r: "docs/Home.md" if r == "Home.md" else "docs/Claude/" + r
    files = notes(docs); rel = {relof(f): f for f in files}
    others = [os.path.join(d, f) for d, ds, fs in os.walk(docs) for f in fs if f.endswith((".base", ".canvas")) and ".obsidian" not in d]
    allrel = dict(rel); allrel.update({relof(f): f for f in others})
    byname = {}
    alias_of = {}
    for r, f in rel.items():
        for a in aliases(rd(f)): alias_of.setdefault(a, []).append(r)
    for r in allrel:
        byname.setdefault(os.path.basename(r), []).append(r); byname.setdefault(os.path.splitext(os.path.basename(r))[0], []).append(r)
    def resolve(target):
        t = target.strip()
        for cand in (t, t + ".md"):
            if cand in allrel: return allrel[cand]
        if t in alias_of and len(alias_of[t]) == 1: return allrel[alias_of[t][0]]
        if t.split("/")[-1] in alias_of and len(alias_of[t.split("/")[-1]]) == 1: return allrel[alias_of[t.split("/")[-1]][0]]
        hits = byname.get(t.split("/")[-1], [])
        hits = [h for h in hits if h.endswith(t) or h.endswith(t + ".md")] if "/" in t else hits
        return allrel[hits[0]] if len(set(hits)) == 1 else None

    # 1. the paths named by CLAUDE.md and Workflow.md
    for src in (os.path.join(root, "CLAUDE.md"), os.path.join(claude, "Workflow.md")):
        if not os.path.exists(src): problems.append(f"{os.path.relpath(src, root)}: the file is missing"); continue
        for m in re.finditer(r"`([^`\n]+)`", rd(src)):
            p = m.group(1).strip().rstrip(".,;:")
            if not p.startswith(ROOTS) or re.search(r"[<>*{}\s]|\.\.\.", p): continue
            if not os.path.exists(os.path.join(root, p)): problems.append(f"{os.path.relpath(src, root)}: names {p}, which does not exist")

    # 2 and 3 and 6. links, properties and secrets
    for f in files:
        name = os.path.relpath(f, root); t = rd(f); body = strip_code(t)
        for m in re.finditer(r"!?\[\[([^\]|#]*)(?:#([^\]|]*))?(?:\|[^\]]*)?\]\]", body):
            target, head = m.group(1).rstrip("\\"), m.group(2)          # a link in a table is written [[note\|text]]
            if not target:                                    # [[#Heading]] in the same note
                if head and not head.startswith("^") and head not in headings(t): problems.append(f"{name}: [[#{head}]] has no such heading")
                continue
            r = resolve(target)
            if r is None: problems.append(f"{name}: [[{target}]] does not resolve"); continue
            if head and not head.startswith("^") and r.endswith(".md") and head not in headings(rd(r)): problems.append(f"{name}: [[{target}#{head}]] has no such heading")
        for m in re.finditer(r"(?<!!)\[[^\]]*\]\(([^)\s]+)\)", body):
            u = m.group(1)
            if re.match(r"^(https?:|mailto:|#)", u): continue
            if not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(f), u.split("#")[0]))): problems.append(f"{name}: the link ({u}) does not resolve")
        props = properties(t)
        if props is None: problems.append(f"{name}: no properties")
        else:
            miss = [k for k in REQUIRED if k not in props]
            if miss: problems.append(f"{name}: missing properties {', '.join(miss)}")
            if props.get("type") not in TYPES: problems.append(f"{name}: type '{props.get('type')}' is not one of the kinds of Conventions")
            if props.get("status") not in STATUSES: problems.append(f"{name}: status '{props.get('status')}' is not draft, current or superseded")
            if not re.fullmatch(r"\d{4}-\d\d-\d\d", props.get("date", "")): problems.append(f"{name}: date '{props.get('date')}' is not YYYY-MM-DD")
            s = props.get("summary", "")
            if "summary" in props and not (0 < len(s) <= SUMMARY_MAX): problems.append(f"{name}: the summary has {len(s)} characters (1 to {SUMMARY_MAX})")
            if props.get("type") == "idea" and os.path.relpath(f, claude).startswith("ideas" + os.sep):
                if props.get("area") not in AREAS: problems.append(f"{name}: idea area '{props.get('area')}' is not one of {', '.join(sorted(AREAS))}")
                if props.get("source") not in SOURCES: problems.append(f"{name}: idea source '{props.get('source')}' is not owner or assistant")
                if not props.get("origin"): problems.append(f"{name}: idea has no origin")
        for pat in SECRETS:
            if re.search(pat, t): problems.append(f"{name}: looks like a key or a token ({pat.split('[')[0]}...)")

    # 4. the sections of the spec that the app's comments quote
    spec = os.path.join(claude, "studio-spec.md")
    if os.path.exists(spec):
        have = {m.group(1) for m in re.finditer(r"^#{2,3} (\d+(?:\.\d+[a-z]?)?)\.? ", rd(spec), re.M)}
        spec_text = rd(spec) + "".join(rd(f) for r, f in rel.items() if r.startswith("spec" + os.sep))
        for d, ds, fs in os.walk(os.path.join(root, "app-swift")):
            ds[:] = [x for x in ds if x not in (".build", "build")]
            for fn in fs:
                if not fn.endswith(".swift"): continue
                for ln_no, ln in enumerate(rd(os.path.join(d, fn)).splitlines(), 1):
                    nm = re.search(r'docs/Claude/studio-spec\.md,? "([^"]+)"', ln)
                    if nm and nm.group(1) not in spec_text: problems.append(f"{os.path.relpath(os.path.join(d, fn), root)}:{ln_no}: quotes the name '{nm.group(1)}' of the spec, which is nowhere in it")
                    if re.search(r"docs/studio-spec\.md", ln): problems.append(f"{os.path.relpath(os.path.join(d, fn), root)}:{ln_no}: names the old path docs/studio-spec.md (it is docs/Claude/studio-spec.md)")
                    m = re.search(r"docs/Claude/studio-spec\.md,? (?:sections?|section) ((?:\d+(?:\.\d+[a-z]?)?(?:,? and |, | and )?)+)", ln)
                    if m:
                        for n in re.findall(r"\d+(?:\.\d+[a-z]?)?", m.group(1)):
                            if n not in have: problems.append(f"{os.path.relpath(os.path.join(d, fn), root)}:{ln_no}: quotes section {n} of docs/Claude/studio-spec.md, which has no such heading")
    else: problems.append("docs/Claude/studio-spec.md is missing")

    # 8. names, aliases, phase folders, isolated notes, quoted headings
    for r in sorted(rel):
        if re.search(r"[()]|\d{4}-\d\d-\d\d|\b[Rr]evision\b|\b[Vv]ersions?\b", os.path.splitext(os.path.basename(r))[0]): problems.append(f"{show(r)}: the file name has a parenthesis, a date, a revision or a version (name it by what it says, put the rest in properties)")
    norm = lambda s: re.sub(r"[.:,()'\"/-]", "", s).strip()
    for hub in ("studio-spec.md", "ux-notes.md"):
        hp = os.path.join(claude, hub)
        if not os.path.exists(hp): continue
        lines = rd(hp).split("\n")
        for i, ln in enumerate(lines):
            m = re.match(r"\[\[([^\]|]+)\|", ln)
            if not m or m.group(1) + ".md" not in rel: continue
            j = i - 1
            while j >= 0 and not lines[j].startswith("#"): j -= 1
            head = re.sub(r"^#+ ", "", lines[j]) if j >= 0 else ""
            if head and norm(head) != norm(os.path.basename(m.group(1))) and head not in aliases(rd(rel[m.group(1) + ".md"])):
                problems.append(f"docs/Claude/{m.group(1)}.md: its title differs from the heading '{head}' of {hub}, which must be one of its aliases")
    pdir = os.path.join(claude, "phases")
    if os.path.isdir(pdir):
        for d in sorted(os.listdir(pdir)):
            if d != "early" and os.path.isdir(os.path.join(pdir, d)) and not any(os.path.exists(os.path.join(pdir, d, f)) for f in ("prompt.md", "report.md")):
                problems.append(f"docs/Claude/phases/{d}/: a phase folder needs a prompt or a report (a summary alone is a flat note in docs/Claude/phases/early/)")
    out_links, in_links = {}, {}
    for r, f in rel.items():
        for m in re.finditer(r"\[\[([^\]|#]+)", strip_code(rd(f))):
            tgt = resolve(m.group(1).rstrip("\\"))
            if tgt and tgt != f: out_links.setdefault(r, set()).add(tgt); in_links.setdefault(relof(tgt), set()).add(r)
    for r in sorted(rel):
        if not r.startswith(("archive" + os.sep, "phases" + os.sep + "early" + os.sep)) and r not in out_links and r not in in_links: problems.append(f"{show(r)}: isolated note (no link in or out, properties included)")
    ux = os.path.join(claude, "ux-notes.md")
    if os.path.exists(ux) and "## Scene content" not in rd(ux): problems.append('docs/Claude/ux-notes.md: the heading "Scene content" (quoted by a code comment) is missing')

    # 9. layout, IDs, the owner-facing properties
    for e in sorted(set(os.listdir(docs)) - {"Home.md", "Dashboards", "Claude", ".obsidian", ".DS_Store"}): problems.append(f"docs/{e}: the root of docs/ holds only Home.md, Dashboards/ and Claude/")
    KIND = {"ideas": ("idea", "IDEA", ("area", "source", "since")), "questions": ("question", "QUESTION", ("since", "blocks", "recommendation")), "decisions": ("decision", "DECISION", ("since", "affects"))}
    seen = {}
    for r, f in sorted(rel.items()):
        folder = r.split(os.sep)[0]
        if folder not in KIND or os.sep not in r: continue
        kind, pre, req = KIND[folder]; pr = properties(rd(f)) or {}; i = pr.get("id", "")
        if not re.fullmatch(pre + r"-\d{3}", i): problems.append(f"{show(r)}: id '{i}' is missing or is not {pre}-NNN"); continue
        seen.setdefault(i, []).append(r)
        if i not in aliases(rd(f)): problems.append(f"{show(r)}: the id {i} must be one of its aliases (Cmd+O finds it)")
        miss = [k for k in req if k not in pr]
        if miss: problems.append(f"{show(r)}: missing the owner-facing properties {', '.join(miss)}")
        if kind == "question" and pr.get("status") == "superseded" and not ("decision" in pr and "answer" in pr): problems.append(f"{show(r)}: a settled question needs a decision and an answer")
        if kind == "idea" and pr.get("status") == "superseded" and "outcome" not in pr: problems.append(f"{show(r)}: a settled idea needs an outcome (built, promoted, merged or dropped)")
    for i, rs in seen.items():
        if len(rs) > 1: problems.append(f"the id {i} is used by {len(rs)} notes: {', '.join(rs)}")
    regp = os.path.join(claude, "ids.json")
    if not os.path.exists(regp): problems.append("docs/Claude/ids.json is missing")
    else:
        try: reg = json.loads(rd(regp))
        except ValueError: reg = {}; problems.append("docs/Claude/ids.json is not valid JSON")
        for kind, pre, _ in KIND.values():
            last = int(reg.get(kind, 0)); nums = sorted(int(i.split("-")[1]) for i in seen if i.startswith(pre + "-"))
            if nums and nums[-1] > last: problems.append(f"docs/Claude/ids.json: {pre}-{nums[-1]:03d} exists but the registry stops at {last}")
            for n in range(1, last + 1):
                if f"{pre}-{n:03d}" not in seen: problems.append(f"docs/Claude/ids.json: {pre}-{n:03d} was allocated but its note is gone (IDs are never reused: restore it, or settle the note as dropped)")

    # 5. the questions the owner's assistant reads before every prompt
    ideas = os.path.join(claude, "ideas.md")
    if not os.path.exists(ideas) or "## Questions to settle with the owner" not in rd(ideas): problems.append('docs/Claude/ideas.md: the section "Questions to settle with the owner" is missing')
    else:
        first = re.findall(r"^## (.*)$", rd(ideas), re.M)[:1]
        if not first or not first[0].startswith("Questions to settle with the owner"): problems.append('docs/Claude/ideas.md: the section "Questions to settle with the owner" must come first')

    # 7. the agent view and the generated blocks are what the script would write
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import docs_index
        problems += docs_index.problems(root)
    except (ImportError, OSError, KeyError, ValueError) as e: problems.append(f"docs_index could not run: {e}")
    return problems

def selftest():
    with tempfile.TemporaryDirectory() as r:
        def w(p, t): os.makedirs(os.path.dirname(os.path.join(r, p)), exist_ok=True); open(os.path.join(r, p), "w", encoding="utf-8").write(t)
        fm = '---\ntype: reference\nstatus: current\nphase: \ndate: 2026-01-01\nsummary: "A note."\ntags:\n  - t\n---\n'
        w("CLAUDE.md", "`docs/Claude/Workflow.md` and `docs/nope.md` and `docs/<x>.md`\n"); w("docs/Claude/Workflow.md", fm + "`tools/missing.py`\n")
        w("docs/Claude/studio-spec.md", fm + "## 5. Screens\n\n### 5.6 Design packages\n"); w("docs/Claude/ideas.md", fm + "## Questions to settle with the owner (remind)\n")
        w("docs/Claude/a.md", fm + "[[b]] [[b#Gone]] [[missing]] `[[in code]]` [x](nowhere.md) sk-" + "A" * 40 + "\n"); w("docs/Claude/b.md", "no properties\n")
        w("docs/Claude/c.md", fm.replace("type: reference", "type: weird")); w("docs/Claude/long.md", fm.replace('"A note."', json.dumps("x" * 161)))
        w("docs/Claude/nosummary.md", fm.replace('summary: "A note."\n', "")); w("docs/Claude/ideas/bad.md", fm.replace("type: reference", "type: idea") + "text\n")
        w("app-swift/Sources/X.swift", "/// docs/Claude/studio-spec.md, sections 5.6 and 9.9\n")
        w("docs/Claude/studio-spec.md", fm + "## 5. Screens\n\n### 5.6 Design packages\n\n## 5.4 Hierarchy: libraries (revision 3)\n\n[[spec/5.4 Hierarchy of libraries|5.4 Hierarchy of libraries]]\n\n## 6. Embedded engine (x)\n\n[[spec/6 Engine|6 Engine]]\n")
        w("docs/Claude/spec/5.4 Hierarchy of libraries.md", fm + "text\n"); w("docs/Claude/spec/6 Engine.md", fm.replace("tags:", 'aliases:\n  - "6. Embedded engine (x)"\n  - "Old title"\ntags:') + "text\n")
        w("docs/Claude/spec/7 Thing (revision 2).md", fm + "text\n"); w("docs/Claude/phases/OnlySummary/summary.md", fm + "text\n"); w("docs/Claude/phases/Fine/report.md", fm + "text\n")
        w("docs/Claude/iso.md", fm + "alone\n"); w("docs/Claude/archive/iso2.md", fm + "alone\n"); w("docs/Claude/phases/early/iso3.md", fm + "alone\n"); w("docs/Claude/ux-notes.md", fm + "## Other block\n")
        w("docs/Claude/old.md", fm + "[[Old title]] [[spec/6 Engine]]\n"); w("docs/stray.md", fm + "x\n")
        w("app-swift/Sources/Y.swift", '/// docs/studio-spec.md, section 5.6\n/// docs/Claude/studio-spec.md, "Nowhere name"\n')
        w("docs/Claude/ideas/A.md", fm.replace("tags:", 'id: IDEA-001\naliases:\n  - "IDEA-001"\narea: app\nsource: owner\nsince: 2026-01-01\norigin: x\ntags:').replace("type: reference", "type: idea") + "x\n")
        w("docs/Claude/ideas/B.md", fm.replace("tags:", 'id: IDEA-001\naliases:\n  - "IDEA-001"\narea: app\nsource: owner\nsince: 2026-01-01\norigin: x\ntags:').replace("type: reference", "type: idea") + "x\n")
        w("docs/Claude/questions/Q.md", fm.replace("type: reference", "type: question").replace("tags:", 'id: QUESTION-001\ntags:') + "x\n")
        w("docs/Claude/ids.json", '{"idea": 3, "question": 1, "decision": 0}')
        p = "\n".join(check(r))
        for needle in ("5.4 Hierarchy of libraries.md: its title differs from the heading '5.4 Hierarchy: libraries (revision 3)'", "7 Thing (revision 2).md: the file name has a parenthesis", "docs/Claude/phases/OnlySummary/: a phase folder needs a prompt",
                       "docs/Claude/iso.md: isolated note", 'the heading "Scene content"'):
            assert needle in p, f"expected a problem containing {needle!r}, got:\n{p}"
        for needle in ("6 Engine.md: its title", "[[Old title]]", "docs/Claude/archive/iso2.md: isolated", "docs/Claude/phases/early/iso3.md: isolated", "docs/Claude/phases/Fine/: a phase folder"):
            assert needle not in p, f"unexpected problem containing {needle!r}:\n{p}"
        p = "\n".join(check(r))
        for needle in ("names docs/nope.md", "names tools/missing.py", "[[b#Gone]]", "[[missing]]", "(nowhere.md)", "looks like a key", "b.md: no properties", "type 'weird'", "section 9.9",
                       "long.md: the summary has 161", "nosummary.md: missing properties summary", "idea area 'None'", "idea source 'None'", "idea has no origin", "docs_index could not run",
                       "docs/stray.md: the root of docs/", "names the old path docs/studio-spec.md", "quotes the name 'Nowhere name'", "the id IDEA-001 is used by 2 notes", "IDEA-002 was allocated but its note is gone", "questions/Q.md: the id QUESTION-001 must be one of its aliases",
                       "questions/Q.md: missing the owner-facing properties since, blocks, recommendation"):
            assert needle in p, f"expected a problem containing {needle!r}, got:\n{p}"
        for needle in ("docs/<x>.md", "in code", "section 5.6", "must come first"):
            assert needle not in p, f"unexpected problem containing {needle!r}:\n{p}"
        w("docs/Claude/ideas.md", fm + "## Ideas\n\n## Questions to settle with the owner (remind)\n")
        assert "must come first" in "\n".join(check(r)), "the questions section must come first"
    print("check_docs selftest ok")

def main():
    if "--selftest" in sys.argv: return selftest()
    root = sys.argv[sys.argv.index("--root") + 1] if "--root" in sys.argv else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    problems = check(root)
    for p in problems: print("FAIL " + p)
    print(f"check_docs: {len(problems)} problem(s)" if problems else "check_docs: ok")
    sys.exit(1 if problems else 0)

if __name__ == "__main__":
    sys.dont_write_bytecode = True
    main()
