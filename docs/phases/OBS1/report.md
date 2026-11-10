---
type: phase-report
status: current
phase: OBS1
date: 2026-11-10
summary: "Report of OBS1: the audit of every path read under docs/, three lists, the entry notes and a proposed tree."
prompt:
  - "[[phases/OBS1/prompt]]"
spec:
  - "[[spec/1 Idea]]"
  - "[[spec/10 Phases]]"
  - "[[spec/11 Decisions to validate]]"
ux:
  - "[[ux/Library, Scenes tab]]"
  - "[[ux/Motion, the interface answers]]"
  - "[[ux/Scene content]]"
  - "[[ux/Visual direction]]"
tags:
  - report
---
# OBS1: docs/ becomes an Obsidian vault (audit, then the skeleton)

Documentation only. No version bump: the skill (0.18.2) and the app (0.19.2) are untouched. No file of `docs/` was moved, renamed, split or rewritten; the existing notes keep their paths and headings.

## Step 0: who reads a path under docs/

Searched with `grep` over CLAUDE.md, `.claude/**`, README.md, ROADMAP.md, `tools/**`, `app-swift/**`, `showreel-director/**` and `docs/prompts/*.md`. Read by a program: nothing (no script, test or check opens a file of `docs/`: the only hits in `app-swift/**` are the comments below; `tools/**`, `.claude/skills/verify`, `.claude/skills/swift-app` and README.md name no path under `docs/`). Everything below is read by an agent or a human.

| Reader | What it names | Read by | What breaks if it moves |
|---|---|---|---|
| CLAUDE.md:39 | `docs/studio-spec.md`, "read it before building anything about projects, native pickers or the copilot", "section 11, recommended choices" | agent | the agent builds without the spec; "section 11" must exist |
| CLAUDE.md:40 | `docs/ux-notes.md` ("per block", "views stay free of business logic") | agent | same |
| CLAUDE.md:46 | `docs/studio-spec.md`, `docs/phases-done.md` (the archive of built phases) | agent | the phase list loses its details |
| CLAUDE.md:52 | `docs/studio-spec.md` "section 10" (order of phases), `docs/ideas.md` (one line per out-of-scope idea), `docs/ux-notes.md` (block by block polish) | agent | the phase order and the parking lot |
| CLAUDE.md (new section) | `docs/Home.md`, `docs/Conventions.md`, `docs/Workflow.md` | agent | added by this phase |
| `.claude/CLAUDE.md` | no path under docs/ | agent | nothing |
| `.claude/skills/verify`, `swift-app`, `graphify` | no path under docs/ (graphify indexes the repo, see below) | agent | nothing |
| README.md | no path under docs/ | human | nothing |
| ROADMAP.md:31 | `docs/studio-spec.md` ("specification, validated") | human, agent | the link to the spec |
| `tools/**` | no path under docs/ | program | nothing |
| `app-swift` comments | see the next table | human (comments) | a comment that quotes a section number goes false |
| `showreel-director/**` | none (a URL in `references/feasibility.md` contains "docs/" and is unrelated) | none | nothing |
| `docs/prompts/*.md` (18 files) | `docs/ux-notes.md` entries, `docs/studio-spec.md` sections, reports of earlier phases, `docs/ideas.md`, `docs/phases-done.md`, the report this prompt asks for | agent | an entry that is renamed or split leaves the prompt pointing nowhere |

### Comments in the app that quote the spec

| File:line | Quotes |
|---|---|
| `app-swift/Sources/ShowreelKit/ShowreelFile.swift:3` | sections 3.1 and 5.1b |
| `app-swift/Sources/ShowreelKit/ShowreelFile.swift:140` | "Scene content" (a heading of ux-notes or a block of the spec; the spec has no such heading, ux-notes has `## Scene content`) |
| `app-swift/Sources/ShowreelKit/DesignPackage.swift:4` | section 5.6 |
| `app-swift/Sources/ShowreelStudio/PackageViews.swift:6` | section 5.6 |
| `app-swift/Tests/ShowreelKitTests/EngineTests.swift:27` | section 6 |
| `app-swift/Tests/ShowreelKitTests/StudioFileTests.swift:8` | section 5.1b |

These are comments only. Their targets exist today (`### 5.1b Export from the skill`, `### 5.6 Design packages`, `## 6. Embedded engine`, `### 3.1 showreel.json`); `Scene content` is a block of `docs/ux-notes.md`, so the comment at `ShowreelFile.swift:140` names the wrong file. Not fixed here (the phase forbids editing `app-swift/**`).

### What each prompt reads in ux-notes.md

| Prompt | Entries it names |
|---|---|
| UI1 | section "Library, Scenes tab", entry "Proposed restructure (owner, 2026-11-09 ...)" |
| UI2 | "Library, Scenes tab": "Proposed restructure", "Scene row icons, decided by the owner", "Lock, owner's rule", "Review mechanism to rethink" |
| DS1 | no entry named (reads the file) |
| DS2 | "Visual direction", "Motion: the interface answers", "Scene row icons, decided by the owner", "Lock, owner's rule", "Film placement toggle", "Sizes and reset" |
| RL1 | "Visual direction", "Motion", "Clap in the rail (owner, after DS1)" |
| FIX3 | "Film placement toggle (owner)", "Sizes and reset (owner)", the "Motion" section |
| CL1 | "Conversation language (owner, after DS1)" |
| AS1 | "Forms (owner, after DS1)", "State section: no Instruction field", "Duration stepper", the UI principle |
| DS3 | "Visual direction", "Motion: the interface answers", "Forms (owner, after DS1)", "Alignment in the inspector", "Real tabs", "Other details seen on the same screenshot", "Same slide-in for the Project panel" |
| DS3b | "Forms (owner, after DS1)", "Alignment in the inspector", "Duration stepper" |
| RB1 | "Rail", "Sizes and reset", "Same slide-in for the Project panel", "Motion: the interface answers", the UI principle (the entry "Rail" does not exist as a heading: the rail is described in "Clap in the rail" and "Visual direction") |
| BG2, BATCH-A, BATCH-B, FIX1, FIX2, OBS1, OBS2 | no entry names, or none from ux-notes |

If ux-notes is split, every one of these names must survive as a heading (or a heading link) of the hub.

## The three lists

### 1. Fixed points

- `docs/studio-spec.md` with its numbered sections: 3.1, 5.1b, 5.6 and 6 (quoted by code comments), section 10 (the order of phases) and section 11 ("Decisions to validate", cited by CLAUDE.md).
- `docs/ux-notes.md` and its block names: Guiding principle; Action/reaction: remaining; Application (launch, library, settings); Library, Scenes tab; Inspector, scene; Scene content; Project and wizard; Resources; Look and technique; Storyboard and scene editor; Storyboard and music; Build and preview; Deliver; Visual direction (owner liked the mockup, 2026-11-10), with its entries named by the prompts above.
- `docs/phases-done.md`.
- `docs/ideas.md` and its section "Questions to settle with the owner (remind him before any prompt)": the owner's Cowork assistant reads it before every prompt. Keep the heading text close to as is.
- `docs/prompts/` (the prompts are files an agent reads) and `docs/<phase>-report.md` (named by the prompts that ask for them).
- `docs/Home.md`, `docs/Workflow.md`, `docs/Conventions.md` (new, named by CLAUDE.md).

### 2. Files by kind

Counted on 2026-11-10 before the three new notes and this report: 31 files at the top of `docs/` and 18 in `docs/prompts/` (49 `.md`; `docs/.obsidian/` excluded).

| Kind | Files |
|---|---|
| Spec | `studio-spec.md` |
| UX notes | `ux-notes.md` |
| Backlog | `ideas.md` |
| Archive of built phases | `phases-done.md` |
| Phase prompts (18) | `prompts/`: AS1, BATCH-A, BATCH-B, BG2, CL1, DS1, DS2, DS3, DS3b, FIX1, FIX2, FIX3, OBS1, OBS2, RB1, RL1, UI1, UI2 |
| Phase reports (one phase) | `as1`, `ba1`, `ba2`, `bf1`, `bf2`, `bg1`, `bg1c`, `bg1d`, `bg2`, `cl1`, `ds1`, `ds2`, `ds3`, `ds3b`, `fix1`, `fix2`, `q5`, `rb1`, `rl1`, `ui1`, `ui2`, `v2`, `3d1` (23, all `-report.md`) |
| Batch or overnight reports | `batch-report` (Q4, R, F, Q6), `batch2-report` (F2, T2), `batchA-report` (FIX1, CL1, RL1), `overnight-report` (Q3, Q2, V) |

One-off history, carrying no decision that something else does not record: `batch-report`, `batch2-report`, `batchA-report` (each phase has its own record in `phases-done.md` or its own report), `bf1`, `bf2`, `bg1`, `bg1c`, `bg1d` (their behaviour is in the code and in `bg2-report`), `fix1`, `fix2`, `3d1`, `ds1`, `ba2`, `v2`.

Reports that still carry something nothing else records (read before judging):

- `docs/phases/UI1/report.md`, section "Decisions the owner can reverse": the Checks badge, the 2/3 and 1/3 split, the Overview as the whole tree, the removal of the "In the film" checkbox, the list reordering by `reelSlot`. Partly mirrored as questions in `ideas.md`.
- `docs/phases/UI2/report.md`, section "Decisions taken": `note` as the instruction field, the `retiredIDs` key of `showreel.json`, a locked scene's own transition stays editable, "Lock all", undo of an unlock. Some are questions in `ideas.md`, the rest only here.
- `docs/phases/CL1/report.md`, "Decisions and deviations": the `conversationLanguageSource` key, "Not set" for older projects.
- `docs/phases/BA1/report.md`: the Build audit and its ranked proposal (partly implemented by BA2, BG1 to BG2); the "not implemented" items live only here.
- `docs/phases/DS3/report.md`, "Not done": finished by DS3b (see `docs/phases/DS3b/report.md`; I did not check each item against the code).
- `docs/phases/AS1/report.md`, "Deviations and left": the forms not converted to autosave (also in ROADMAP.md).
- `docs/phases/RB1/report.md`: four questions for the owner (taste), recorded nowhere else yet.
- `docs/archive/overnight-report.md` and `docs/phases/Q5/report.md`: the behaviour of Q3, Q2 and Q5 is in the code and in the spec; the reports carry design reasons for marks and states.

### 3. Duplicates and drift (listed, not fixed)

1. **The phase list is stated in four places that disagree.**
   - CLAUDE.md:46 lists 47 built phases. `docs/phases-done.md` (last entry `## RL1`, line 203) has none of AS1, BA1, BA2, BG2, DS1, DS2, DS3, FIX2, UI1, UI2, and has C1, D1, D2, D3, F2, T2 that CLAUDE.md lacks. BG1, BG1c, BG1d, BF1, BF2, 3D1, DS3b and RB1 have reports but no entry in `phases-done.md`.
   - `docs/studio-spec.md` section 10 (lines 283 to 317) stops at PK4, C and D; it does not know any phase from UI1, DS1 or RL1 onward, and marks "(built)" on only A and W1.
   - ROADMAP.md:4 and :6 each describe built phases in prose.
2. **ROADMAP.md:6 is stale against CLAUDE.md:46.** It says DS3 "takes the 148 remaining colour picks", that "the text-field style, the growing multi-line fields and a review of every button's role are not done yet", and that the rail is "Film, Look, Build, Project"; DS3 and DS3b are built, and the rail has two groups (ROADMAP.md:4 says so a few lines before).
3. **`docs/ux-notes.md:220` and `:221` contradict each other.** Line 220 says the placement is "restored by Reset layout"; line 221 says the reset icon "keeps the chosen placement" and replaced "Reset layout".
4. **`docs/ux-notes.md:199`** describes a four-entry rail "Film, Look, Build, Project" (the DS1 mockup); `:91` records the RL1 rail. Both are history, only the first is not marked as such.
5. **`docs/ux-notes.md:95`** says the Project button question is "to settle in DS3"; DS3 built it.
6. **`docs/phases/DS3b/prompt.md:3`** names "the 'Pas fait' items" of `docs/phases/DS3/report.md`; the report's heading is "Not done".
7. **`docs/archive/BATCH-B/prompt.md:26` and `FIX3.md:25`** ask for `docs/phases/BATCH-B/report.md` and `docs/phases/FIX3/report.md`; neither exists.
8. **`docs/archive/overnight-report.md`** has French headings ("Phase Q3: Ask Clap et historique dans Clap", "Fin de nuit") in a vault whose language is English.
9. **`app-swift/Sources/ShowreelKit/ShowreelFile.swift:140`** quotes "docs/studio-spec.md, 'Scene content'"; that block is in `docs/ux-notes.md`.
10. **CLAUDE.md:40** describes `docs/ux-notes.md` as "input for the per-block rework after phase T"; it is now also the record of what each design phase built.
11. **Version numbers** are quoted in many reports and in `CLAUDE.md`, ROADMAP.md and RELEASE-NOTES-APP.md; the sources are `app-swift/shared/app-version.json` and `SKILL.md`.

## What was built

New files only: `docs/Home.md` (entry note, where we are, links to every existing document by its present name), `docs/Workflow.md` (two sides, the phase, the owner's part, where things go), `docs/Conventions.md` (properties, naming, links, one fact in one place, what never goes in a note, superseded notes, paths that stay valid), this report.
Edited: `.gitignore` (adds `docs/.obsidian/`), `CLAUDE.md` (the section "Documentation vault (docs/)", before "Scope discipline"; and a repair of my own RB1 edit of the "Open work" line, which had attached the forms-autosave note to RB1 instead of DS3: the sentence now reads as it did, plus RB1).

**Ignore rules.** `docs/.obsidian/` holds `app.json`, `appearance.json`, `core-plugins.json` and `workspace.json` (the owner's layout, last opened files). It is not in the git index (checked by reading `.git/index`, not with git), so nothing is committed yet; if GitHub Desktop already lists it, the owner must not commit it, and if a later commit includes it, the owner removes it there. Graphify needs no extra ignore: its detection skips `.obsidian` folders by itself (`_SKIP_DIRS`, issue 2493), and it reads `.gitignore`; `.base` and `.canvas` are not extensions it reads, so the future dashboards and the map are not indexed. `graphify-out/manifest.json` has no entry for `docs/.obsidian/`. No Graphify rebuild was needed.

## Proposed tree for OBS2

```
docs/
  Home.md  Workflow.md  Conventions.md          (stay)
  studio-spec.md   hub, keeps sections 1 to 12 and 3.1, 5.1b, 5.6, links to docs/spec/
  ux-notes.md      hub, keeps its 14 block names, links to docs/ux/
  phases-done.md   hub: the table of phases, links to docs/phases/<ID>/
  ideas.md         one note; "Questions to settle with the owner" stays first
  spec/            1 Idea.md ... 5.6 Design packages.md ... 12 Risks.md   (the title keeps its number)
  ux/              one note per block; the long entries ("Visual direction", "Forms", "Clap in the rail") get their own note
  phases/<ID>/prompt.md, report.md              the 18 prompts and 23 reports, moved (BATCH-A and BATCH-B as phases of their own)
  archive/         batch, batch2, overnight reports (they span phases)
  decisions/       the decisions of ui1/ui2/cl1 reports, spec section 11, ideas.md (stated only)
  Phases.base  Decisions.base  Open questions.base
  Architecture map.canvas
```

Hubs stay at: `docs/studio-spec.md`, `docs/ux-notes.md`, `docs/phases-done.md`, `docs/ideas.md`. The old paths `docs/prompts/<ID>.md` and `docs/<id>-report.md` move (their readers are the prompts and CLAUDE.md, rewritten in OBS2).
Notes from splitting: `studio-spec.md` by section; `ux-notes.md` by block; reports stay whole.
Bases: Phases (id, date, status, app and skill version, links), Decisions, Open questions (mirrors the section of ideas.md, which stays the reference an agent reads).

## Questions for the owner

1. Move to `docs/phases/<ID>/` for **every** old prompt and report, or only from the next phase on (the old ones stay under `docs/prompts/` and `docs/<id>-report.md`)? Moving all rewrites the paths named inside 18 prompts.
2. May OBS2 fix the drift of list 3 (a single phase list, ROADMAP.md:6, the contradiction at `ux-notes.md:220` and `:221`), or only report it? The prompts say OBS1 does not fix it.
3. The French headings of `docs/archive/overnight-report.md`: translate in OBS2, or leave the file as history?
4. Is `docs/archive/` right for the batch and overnight reports, or should they stay at the top level?
5. `ShowreelFile.swift:140` names the wrong file for "Scene content"; correcting it is a comment edit in `app-swift/**`, forbidden in OBS1 and OBS2. Do it with the next app phase?

## Verified, not verified

Verified: see the last message for `python3 tools/check.py` and `tools/verify.sh --fast` (documentation only: nothing but `.gitignore`, `CLAUDE.md` and new notes changed). All other claims come from `grep` and reading files.
Not verified: that Obsidian renders the three notes (properties, wikilinks, callouts) and that every link resolves, since there is no screen: wikilinks are written against file names that exist, and the check is listed below. I did not run a link checker (`tools/check_docs.py` is OBS2).

## To check by hand

1. Open `docs/` in Obsidian (it is the vault: `docs/.obsidian/` is already there).
2. Read Home, Workflow and Conventions.
3. Click every link of Home: a link that opens an empty new note is a wrong name; tell me which.
4. In GitHub Desktop check that `docs/.obsidian/` is not listed as a change to commit.
