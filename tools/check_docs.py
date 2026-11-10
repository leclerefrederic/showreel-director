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
   no phase folder holds only a summary; no note is isolated outside archive/ and early/ (links in properties count); the headings that code and agents quote still exist."""
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
    docs = os.path.join(root, "docs"); problems = []
    files = notes(docs); rel = {os.path.relpath(f, docs): f for f in files}
    others = [os.path.join(d, f) for d, ds, fs in os.walk(docs) for f in fs if f.endswith((".base", ".canvas")) and ".obsidian" not in d]
    allrel = dict(rel); allrel.update({os.path.relpath(f, docs): f for f in others})
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
    for src in (os.path.join(root, "CLAUDE.md"), os.path.join(docs, "Workflow.md")):
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
            if props.get("type") == "idea" and os.path.relpath(f, docs).startswith("ideas" + os.sep):
                if props.get("area") not in AREAS: problems.append(f"{name}: idea area '{props.get('area')}' is not one of {', '.join(sorted(AREAS))}")
                if props.get("source") not in SOURCES: problems.append(f"{name}: idea source '{props.get('source')}' is not owner or assistant")
                if not props.get("origin"): problems.append(f"{name}: idea has no origin")
        for pat in SECRETS:
            if re.search(pat, t): problems.append(f"{name}: looks like a key or a token ({pat.split('[')[0]}...)")

    # 4. the sections of the spec that the app's comments quote
    spec = os.path.join(docs, "studio-spec.md")
    if os.path.exists(spec):
        have = {m.group(1) for m in re.finditer(r"^#{2,3} (\d+(?:\.\d+[a-z]?)?)\.? ", rd(spec), re.M)}
        for d, ds, fs in os.walk(os.path.join(root, "app-swift")):
            ds[:] = [x for x in ds if x not in (".build", "build")]
            for fn in fs:
                if not fn.endswith(".swift"): continue
                for ln_no, ln in enumerate(rd(os.path.join(d, fn)).splitlines(), 1):
                    m = re.search(r"docs/studio-spec\.md,? (?:sections?|section) ((?:\d+(?:\.\d+[a-z]?)?(?:,? and |, | and )?)+)", ln)
                    if m:
                        for n in re.findall(r"\d+(?:\.\d+[a-z]?)?", m.group(1)):
                            if n not in have: problems.append(f"{os.path.relpath(os.path.join(d, fn), root)}:{ln_no}: quotes section {n} of docs/studio-spec.md, which has no such heading")
    else: problems.append("docs/studio-spec.md is missing")

    # 8. names, aliases, phase folders, isolated notes, quoted headings
    for r in sorted(rel):
        if re.search(r"[()]|\d{4}-\d\d-\d\d|\b[Rr]evision\b|\b[Vv]ersions?\b", os.path.splitext(os.path.basename(r))[0]): problems.append(f"docs/{r}: the file name has a parenthesis, a date, a revision or a version (name it by what it says, put the rest in properties)")
    norm = lambda s: re.sub(r"[.:,()'\"/-]", "", s).strip()
    for hub in ("studio-spec.md", "ux-notes.md"):
        hp = os.path.join(docs, hub)
        if not os.path.exists(hp): continue
        lines = rd(hp).split("\n")
        for i, ln in enumerate(lines):
            m = re.match(r"\[\[([^\]|]+)\|", ln)
            if not m or m.group(1) + ".md" not in rel: continue
            j = i - 1
            while j >= 0 and not lines[j].startswith("#"): j -= 1
            head = re.sub(r"^#+ ", "", lines[j]) if j >= 0 else ""
            if head and norm(head) != norm(os.path.basename(m.group(1))) and head not in aliases(rd(rel[m.group(1) + ".md"])):
                problems.append(f"docs/{m.group(1)}.md: its title differs from the heading '{head}' of {hub}, which must be one of its aliases")
    pdir = os.path.join(docs, "phases")
    if os.path.isdir(pdir):
        for d in sorted(os.listdir(pdir)):
            if d != "early" and os.path.isdir(os.path.join(pdir, d)) and not any(os.path.exists(os.path.join(pdir, d, f)) for f in ("prompt.md", "report.md")):
                problems.append(f"docs/phases/{d}/: a phase folder needs a prompt or a report (a summary alone is a flat note in docs/phases/early/)")
    out_links, in_links = {}, {}
    for r, f in rel.items():
        for m in re.finditer(r"\[\[([^\]|#]+)", strip_code(rd(f))):
            tgt = resolve(m.group(1).rstrip("\\"))
            if tgt and tgt != f: out_links.setdefault(r, set()).add(tgt); in_links.setdefault(os.path.relpath(tgt, docs), set()).add(r)
    for r in sorted(rel):
        if not r.startswith(("archive" + os.sep, "phases" + os.sep + "early" + os.sep)) and r not in out_links and r not in in_links: problems.append(f"docs/{r}: isolated note (no link in or out, properties included)")
    ux = os.path.join(docs, "ux-notes.md")
    if os.path.exists(ux) and "## Scene content" not in rd(ux): problems.append('docs/ux-notes.md: the heading "Scene content" (quoted by a code comment) is missing')

    # 5. the questions the owner's assistant reads before every prompt
    ideas = os.path.join(docs, "ideas.md")
    if not os.path.exists(ideas) or "## Questions to settle with the owner" not in rd(ideas): problems.append('docs/ideas.md: the section "Questions to settle with the owner" is missing')
    else:
        first = re.findall(r"^## (.*)$", rd(ideas), re.M)[:1]
        if not first or not first[0].startswith("Questions to settle with the owner"): problems.append('docs/ideas.md: the section "Questions to settle with the owner" must come first')

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
        w("CLAUDE.md", "`docs/Workflow.md` and `docs/nope.md` and `docs/<x>.md`\n"); w("docs/Workflow.md", fm + "`tools/missing.py`\n")
        w("docs/studio-spec.md", fm + "## 5. Screens\n\n### 5.6 Design packages\n"); w("docs/ideas.md", fm + "## Questions to settle with the owner (remind)\n")
        w("docs/a.md", fm + "[[b]] [[b#Gone]] [[missing]] `[[in code]]` [x](nowhere.md) sk-" + "A" * 40 + "\n"); w("docs/b.md", "no properties\n")
        w("docs/c.md", fm.replace("type: reference", "type: weird")); w("docs/long.md", fm.replace('"A note."', json.dumps("x" * 161)))
        w("docs/nosummary.md", fm.replace('summary: "A note."\n', "")); w("docs/ideas/bad.md", fm.replace("type: reference", "type: idea") + "text\n")
        w("app-swift/Sources/X.swift", "/// docs/studio-spec.md, sections 5.6 and 9.9\n")
        w("docs/studio-spec.md", fm + "## 5. Screens\n\n### 5.6 Design packages\n\n## 5.4 Hierarchy: libraries (revision 3)\n\n[[spec/5.4 Hierarchy of libraries|5.4 Hierarchy of libraries]]\n\n## 6. Embedded engine (x)\n\n[[spec/6 Engine|6 Engine]]\n")
        w("docs/spec/5.4 Hierarchy of libraries.md", fm + "text\n"); w("docs/spec/6 Engine.md", fm.replace("tags:", 'aliases:\n  - "6. Embedded engine (x)"\n  - "Old title"\ntags:') + "text\n")
        w("docs/spec/7 Thing (revision 2).md", fm + "text\n"); w("docs/phases/OnlySummary/summary.md", fm + "text\n"); w("docs/phases/Fine/report.md", fm + "text\n")
        w("docs/iso.md", fm + "alone\n"); w("docs/archive/iso2.md", fm + "alone\n"); w("docs/phases/early/iso3.md", fm + "alone\n"); w("docs/ux-notes.md", fm + "## Other block\n")
        w("docs/old.md", fm + "[[Old title]] [[spec/6 Engine]]\n")
        p = "\n".join(check(r))
        for needle in ("5.4 Hierarchy of libraries.md: its title differs from the heading '5.4 Hierarchy: libraries (revision 3)'", "7 Thing (revision 2).md: the file name has a parenthesis", "docs/phases/OnlySummary/: a phase folder needs a prompt",
                       "docs/iso.md: isolated note", 'the heading "Scene content"'):
            assert needle in p, f"expected a problem containing {needle!r}, got:\n{p}"
        for needle in ("6 Engine.md: its title", "[[Old title]]", "docs/archive/iso2.md: isolated", "docs/phases/early/iso3.md: isolated", "docs/phases/Fine/: a phase folder"):
            assert needle not in p, f"unexpected problem containing {needle!r}:\n{p}"
        p = "\n".join(check(r))
        for needle in ("names docs/nope.md", "names tools/missing.py", "[[b#Gone]]", "[[missing]]", "(nowhere.md)", "looks like a key", "b.md: no properties", "type 'weird'", "section 9.9",
                       "long.md: the summary has 161", "nosummary.md: missing properties summary", "idea area 'None'", "idea source 'None'", "idea has no origin", "docs_index could not run"):
            assert needle in p, f"expected a problem containing {needle!r}, got:\n{p}"
        for needle in ("docs/<x>.md", "in code", "section 5.6", "must come first"):
            assert needle not in p, f"unexpected problem containing {needle!r}:\n{p}"
        w("docs/ideas.md", fm + "## Ideas\n\n## Questions to settle with the owner (remind)\n")
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
