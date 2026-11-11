---
type: phase-report
status: current
phase: LK1
date: 2026-11-11
summary: "Report of LK1: opening a project gives each scene locked before UI2 a copy of its look, once, with a journal line and a quiet note; app 0.23.4."
app_version: 0.23.4
skill_version: 0.18.2
prompt:
  - "[[phases/LK1/prompt]]"
tags:
  - report
---

# LK1: locked scenes from before UI2 take a copy of their look

## Step 0

- a) UI2 stores the copy in the scene's own field `lockedLook` (a `Decisions` value: palette, fonts, background, moods, effects pack) in `showreel.json`, written by `planLock` through `LockedLook.copy(of:in:)` and dropped on unlock; `Storyboard.effective` reads it. "No copy" is `isLocked && lockedLook == nil`. Tests: `UI2Tests` (lock, unlock, undo), helper `stripLockedLook` makes the old state.
- b) A project opens in `ProjectModel.init`; nothing was written on opening before (older revisions wait for Update project, `ProjectFormat`). The journal takes app events through `store.noteEvent`; the undo log only takes typed operations.
- c) Before UI2: a locked scene with no `lockedLook`; a scene locked after UI2 carries one; an unlocked scene never has one.

## Built

1. `LockedLookMigration` (Kit, `LockedLook.swift`): `pending`, a pure `apply`, `summary`, and `run(store)`: for each locked scene with no copy it writes the copy equal to the look in use, saves once, adds one journal line (author app, op `lockedLook`, "Locked scenes took a copy of their look: n scene(s)"). Nothing else is touched; no scene to migrate means no write.
2. `ProjectModel.init` runs it first, before anything is read for drawing, and shows one quiet toast with the count.
3. A project of an older revision, or a file that cannot be read, is left alone (the next opening does it once updated).
4. Same field as the lock: no new key; older apps keep it.

## Decisions

- **Not an undo step.** It is a journal event, not a typed operation: undoing it would let the owner put locked scenes back into the unprotected state, and the lock is a promise.
- **Archived locked scenes are migrated too** (the copy equals their current look, a lock is a lock).
- **The note is a toast.** The journal keeps the permanent line; a Checks entry would stay forever for something that happens once.

## Deviations

None from the prompt. The migration does not go through `store.apply` (that would make it an undo step and a card).

## Tests

`LK1Tests` (8): the copy and the file differing only there, idempotence (no write, same date, one journal line), untouched unlocked and post-UI2 scenes, a global change after migration versus an unmigrated control, an empty-decisions project, an outdated or unreadable file, not an undo step, the summary and the order in `init`. No existing test changed. All on temporary projects.

## Verified, not verified

Verified: build, tests, `verify.sh`. Not verified (no screen; no project of the owner was opened or changed): the toast at opening.

## To check by hand

On a copy of a project with a locked scene made before UI2: open it (nothing changes on screen, a note says how many scenes); change the global palette (the locked scene keeps its look); close and reopen (no second note; the file's modification date does not change; one line in the journal).
