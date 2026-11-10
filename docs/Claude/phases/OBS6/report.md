---
type: phase-report
status: current
phase: OBS6
date: 2026-11-10
summary: "Report of OBS6: why the Ideas dashboard showed no idea, the four bases simplified and fixed, a static check, and the expected row count of every view."
prompt:
  - "[[phases/OBS6/prompt]]"
tags:
  - report
---

# OBS6: the owner's dashboards made to work, and checked without a screen

Documentation and the docs tooling only: no application code or comment changed (so no complete verification and no rebuild were required), no version bump.

## Step 0

### Inventory of the constructs, and what documents them

Sources: the `obsidian-bases` skill, and the official pages `obsidian.md/help/bases/{syntax,views,functions}` (the old `help.obsidian.md/bases/...` addresses redirect there), read as data by a fetch agent.

| Construct | Where | Documented? |
|---|---|---|
| `filters:` with `and:` lists of strings | all four bases | skill: "filters ... `and:`" |
| a note property written bare (`status == "draft"`, `type == "idea"`) | all | official: "`note.author` or simply `author` as a shorthand ... If no prefix is specified, the property is assumed to be a `note` property" |
| `file.inFolder("Claude/ideas")` | Ideas, before | skill and official: `inFolder(folder)` with a folder name ("Required Reading", "notes"); a nested path is **not stated** |
| `file.folder == "Claude/phases/early"` | Phases | skill: `file.folder` is "Parent folder path"; the value for a nested folder is not shown |
| formula `stage` = `if(status == ..., if(phase, "Planned in " + phase, ...))` | Ideas, before | `if()` documented; truthiness of an empty property: "Bases functions follow JavaScript behavior", not stated for null or empty; `+` joining texts appears only in the example `price.toFixed(2) + " dollars"` |
| `formula.x` in `order` and in a view filter | Ideas, before | official: `"formula.ppu > 5"` and `formula.ppu` in `order` |
| `sort:` with `property` and `direction` | all | **not documented**: the syntax page has no `sort:` key and the views page describes sorting only through the interface. Obsidian's own rewrite of `Ideas.base` and `Questions.base` kept every `sort:` block, so the key exists in practice; its effect is unknown |
| `groupBy:` with `property` and `direction` | Ideas (Parked) | official: `groupBy:` / `property:` / `direction:` |
| `order:` list, `properties:` with `displayName:` | all | skill and official |
| `![[X.base#View name]]` | `Home.md` | skill: "Embedding Bases" |
| a property named in `properties:` or `order:` that no note has | (checked) | not stated by the docs; the check below catches it |
| `phase:` with no value (null) | 38 idea notes | not stated |

### Candidate causes of the empty Ideas dashboard

- **Believed cause: the view the owner lands on was empty by construction.** The first view of `Ideas.base` was "Wanted soon" (filter: stage "Wanted soon"), and no idea is wanted soon (34 `draft`, 12 `superseded`, none `current`); `Home.md` embedded "Wanted soon" and "Planned or in progress", also empty by construction (the 8 ideas with a `phase` are all `superseded`). The owner's screenshot agrees: the base renders, the Stage column reads "Wanted soon" (so the formula runs), and the rows were simply not there. Nothing in the syntax was broken.
- **The folder filter.** Removing `file.inFolder("Claude/ideas")` made the hub note `Claude/ideas.md` appear as an idea, because it carried `type: idea`: that is a real leak, not the cause of the emptiness. A nested path in `inFolder` is not documented. **Durable fix:** the hub now carries `type: reference`, and a check forbids an idea, question or decision type outside its folder, so the folder filter is not needed and is gone.
- **The stage formula.** It works (screenshot) but two of its parts are not documented (`if()` on an empty property, `+` on texts), so it was replaced by plain filters (below). Ruled out as the cause.
- **`phase:` null.** A null is not an empty text: `phase == ""` is false for it, and `phase != ""` is true, so "Parked" would have been empty and "Planned" full of parked ideas if the formula had been replaced without care. The 38 notes now carry `phase: ""`; a check requires it.
- **`sort` and `groupBy` shapes.** Obsidian rewrote the files with both kept, so the shapes parse; not the cause.
- **A property no note has.** `outcome_link` is the real name (9 notes use it); every other property of the four bases exists in at least one note of its type. Ruled out.
- **Bare names.** Documented as valid. Ruled out.
- **Obsidian version.** The views page gives 1.9 for the table and cards layouts; the owner's screenshot proves the version is enough.

### The other three bases and the embeds

`Questions.base`, `Decisions.base` and `Phases.base` use only the constructs above. The new check found **one real defect**: the "Early phases" view of `Phases.base` filtered on `file.folder == "phases/early"` (a leftover of the move to `Claude/`), so it would have shown no row; it is `Claude/phases/early` now (30 rows). The embeds of `Home.md` named existing views, but two of the four showed an empty table; they were replaced.

## What was changed

| File | Before | After |
|---|---|---|
| `Ideas.base` | filter `type == "idea"` and `file.inFolder("Claude/ideas")`; formula `stage`; first view "Wanted soon"; "Wanted soon" had also lost its filter | one filter `type == "idea"`; no formula; the views, in this order: **All open ideas** (`status != "superseded"`, the default), Wanted soon (`status == "current"` and `phase == ""`), Planned or in progress (`status != "superseded"` and `phase != ""`), Parked (`status == "draft"` and `phase == ""`, grouped by area), Done or dropped (`status == "superseded"`); the Stage column is the Status column |
| `Phases.base` | "Early phases" on `phases/early` | `Claude/phases/early` |
| `Questions.base`, `Decisions.base` | (as written) | unchanged: they pass the check |
| `Home.md` | embeds Ideas "Wanted soon" and "Planned or in progress" | embeds Ideas "All open ideas" (To answer and Decisions unchanged) |
| `Claude/ideas.md` | `type: idea` | `type: reference` |
| 38 idea notes | `phase:` (null) | `phase: ""`; `tools/docs_new.py` writes it for a new idea |
| `Conventions.md` | | one paragraph "Dashboards" (the allowed constructs, the type rule, `phase: ""`, the check) |

## The static check

`tools/check_docs.py` (and its selftest) now fails, one line per problem, when: a `.base` YAML or a note's properties do not parse (a small YAML reader for the subset used, since the standard library has none); a view has no name or two share one; a property, formula or folder named in `order`, `sort`, `groupBy`, `properties` or a filter does not exist (a property must exist in at least one note of the type the base filters on; `file.*` built-ins are accepted, `formula.x` must be defined, a `file.inFolder` or `file.folder` path must be a folder); an embed of `Home.md` names a base or a view that does not exist; an idea, question or decision type sits outside its folder, or a phase type outside `phases/` and `archive/`; the `phase` of an idea is null. Every earlier check is kept.

`python3 tools/check_docs.py --dashboards` evaluates, in Python and from the notes' properties, the filters of every view (only `and` lists of `name == "text"` and `name != "text"`, and `file.folder`; it refuses and says so for anything else) and prints the rows each view should show:

| Base / view | Rows expected |
|---|---|
| Decisions / Current | 18 |
| Decisions / Superseded | 1 |
| Ideas / All open ideas | 34 |
| Ideas / Wanted soon | 0 |
| Ideas / Planned or in progress | 0 |
| Ideas / Parked | 34 |
| Ideas / Done or dropped | 12 |
| Phases / Reports and summaries, newest first | 67 |
| Phases / Prompts, newest first | 22 |
| Phases / Early phases | 30 |
| Questions / To answer | 11 |
| Questions / Answered | 1 |

Reading the table: "Wanted soon" and "Planned or in progress" are empty because no idea is wanted soon and no idea is planned; that is the data, not a fault. The default view of each base is never empty.

## Verified, not verified

Verified (run): `python3 tools/docs_index.py --write` twice (the second: nothing to change), `--selftest` and `--check`; `python3 tools/check_docs.py` and its selftest; `python3 tools/check_docs.py --dashboards`; `python3 tools/docs_new.py --selftest`; `python3 tools/check.py`; `tools/verify.sh --fast` (see the last message); the four `.base` files parse with Ruby's YAML and with the new reader. No application code or comment changed.

Not verified (no screen): the rendering of any view in Obsidian; that Obsidian applies `sort:` (undocumented, kept by its own rewrite) and `groupBy`; that `file.folder` holds the full vault path of a nested folder (assumed from "Parent folder path"); that a text property equal to `""` compares as expected in Obsidian; how the four embeds of `Home` render. The row counts above are computed by my own evaluator, which is only as right as my reading of those comparisons: that is why the owner's comparison is the real test.

## To check by hand

1. Open each dashboard and compare the row count of each view with the table above: `Questions` (To answer, Answered), `Ideas` (the five views), `Decisions` (Current, Superseded), `Phases` (three views). A mismatch names the view that is wrong.
2. Open `Home` and check the embeds show the same rows as the views they embed: To answer (11), Ideas / All open ideas (34), Decisions / Current (18).
3. If a view is empty or wrong, send the assistant the view name and what Obsidian shows (the number of rows and the columns that appear).
