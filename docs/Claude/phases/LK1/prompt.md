---
type: phase-prompt
status: current
phase: LK1
date: 2026-11-11
summary: "A project opened by the app gives each locked scene made before UI2 a copy of its look, so the lock holds when the global look changes (DECISION-028)."
tags:
  - prompt
---

# Phase LK1: locked scenes from before UI2 take a copy of their look

Read CLAUDE.md first and follow every rule (never run git, English interface, skill untouched, answer the owner in French and short, no screen so say what was not seen, no out-of-scope work: an idea goes in a note created with `python3 tools/docs_new.py idea`). Use `graphify query` before reading files. Views stay free of business logic.

The owner's answer to QUESTION-010 (2026-11-11), DECISION-028: when a project opens, every locked scene made before UI2 that has no copy of its look takes one automatically. At that moment the copy equals the current look, so nothing changes on screen, and the lock then holds if the global look changes later.

## Step 0 (read-only, 5 lines at the top of the report)

a) How UI2 stores the copy of a scene's look when it is locked (the override or snapshot in `showreel.json`, its key, its schema and its tests) and what "has no copy" means in the data.
b) Where a project is opened and migrated today (the places that already upgrade an older file, the `retiredIDs` precedent of DECISION-007) and whether a migration there goes through the typed operations, the journal and the undo log.
c) What a project made before UI2 looks like: a locked scene without the copy, a scene locked but already carrying one, an unlocked scene.

## What to build

1. **A pure migration in ShowreelKit**: for each scene whose state is Locked and which has no copy of its look, write the copy equal to the look it follows now. It touches nothing else (an unlocked scene, a locked scene that already has its copy, any other field). It is idempotent: a second open changes nothing and writes nothing.
2. **When it runs**: once, when a project opens, before the first draw, so nothing is redrawn differently. If nothing is to migrate, the file is not written (no spurious change of the modification date).
3. **Visible and reversible.** The migration is a typed operation with a journal line ("Locked scenes took a copy of their look: n scenes"), and the owner sees one quiet note in the project's activity or Checks (not a modal), saying how many scenes. Say whether it enters the undo log and why; if it would let the owner undo the migration itself into the old, unprotected state, prefer not to make it undoable and say so.
4. **Older apps** must still read the file (as with DECISION-007: older apps ignore and keep what they do not know). Use the same field the lock already writes; add no new key unless step 0 shows there is none.
5. **Nothing else:** no change to how a lock is taken, to DECISION-005 (a locked scene's own transition stays editable) or to the look editors.

## Tests (no screen)

A project with a pre-UI2 locked scene gets its copy and the file differs only there; a second open writes nothing; a scene locked after UI2 is untouched; unlocked scenes are untouched; after a global look change the migrated scene keeps its old look and an unmigrated control would have followed the change; the journal line is written once. Say which tests changed.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE `python3 tools/bump_app.py patch "..."`; never edit a version by hand. Update docs/Claude/ux-notes.md ("Built in LK1 (date)"), CLAUDE.md "Open work", then `python3 tools/docs_index.py --write`.

## Verification

During the work: `tools/verify.sh --fast`. At the end: the complete `tools/verify.sh`, then `tools/rebuild-app.sh` (in the batch: once at the end).

## Final report (docs/Claude/phases/LK1/report.md)

Step 0 results, what was built, the version, what is verified and what is not (no screen; work on a copy of a project, never the owner's), and "To check by hand": open a project with a locked scene made before UI2 (nothing changes on screen), change the global palette (the locked scene keeps its look), reopen (no second note, no new write). Stop after the phase.
