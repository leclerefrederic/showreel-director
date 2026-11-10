---
type: phase-prompt
status: current
phase: UI2
date: 2026-11-09
summary: "Asks for clear scene rows, three switches (Visible, Locked, Ready), Delete scene and a real lock."
report:
  - "[[phases/UI2/report]]"
ux:
  - "[[ux/Library, Scenes tab]]"
decisions:
  - "[[decisions/A locked scene's own transition stays editable]]"
  - "[[decisions/Deleted scene IDs are kept in retiredIDs]]"
  - "[[decisions/The instruction field is the scene note and does not switch Ready]]"
tags:
  - prompt
---
# Phase UI2: clear scene rows, three switches (Visible, Locked, Ready), Delete scene, a real lock

Read CLAUDE.md, then docs/Claude/ux-notes.md (section "Library, Scenes tab": the entries "Proposed restructure", "Scene row icons, decided by the owner", "Lock, owner's rule" and "Review mechanism to rethink"), docs/Claude/phases/UI1/report.md, and the code: the flat Storyboard list built in UI1 and its row views, the scene badges and the strip's frame badges, the review state model and its operations (OK, MODIFY, DITCH, lock, enable, archive), `ProjectStore.plan()` (the single control point), Availability.swift, the inspector's scene view and its review block, the Go gate and the checks that read it ("Scene review", "The Go"), the "apply anyway" card for global look changes, the Build's reuse rules (BG1d, BA2), the Clap tools about scenes in `app-swift/shared/tools.json` and `Tools.swift`, `capabilities.json` and `references/portability.md`. Follow every rule of CLAUDE.md (never run git, English interface, no out-of-scope work: an idea goes in docs/Claude/ideas.md in one line). Views stay free of business logic: rules live in ShowreelKit with tests, a view calls typed operations. UI principle: every action has a visible reaction, nothing is disabled silently (disabledWithReason, Availability), and a refusal says why and how to get out of it.

## The owner's decisions (do not reopen them)

- Each scene row has three fixed columns, always present: **Status** (one read-only icon), **Visible** (eye) and **Locked** (lock).
- The inspector of a scene has three switches, **Visible**, **Locked**, **Ready**, and a **Delete scene** button at the bottom. The old review buttons OK, MODIFY and DITCH disappear.
- "Approved" is called **Ready** everywhere in the interface. Keep the stored state names as they are if renaming them would need a migration of existing projects (only the displayed text changes).
- A locked scene is frozen in time and space, visible or hidden.

## Step 0 (read-only, report it in 10 lines at the top of docs/Claude/phases/UI2/report.md)

a) The current review model: stored states, who sets them, which tools and operations exist (OK, MODIFY, DITCH, archive, enable, lock), where the Go gate and the "Scene review" check read them. Which of them Clap can call.
b) What a lock refuses today and what it still allows (the place in the montage moves today). Where `plan()` decides, and how the start time of a scene is computed (durations, transitions, ripple).
c) How a scene inherits the look and how the "apply anyway" card works; where a copy of the effective look could be stored per scene.
d) What exists for "archived" and "ditched" scenes and for the section "Not in the storyboard", and what must be mapped to hidden scenes.
e) Existing projects: locked scenes that are not validated, archived or ditched scenes, scenes with a MODIFY note. State how each is read after this phase, with no migration where possible.

## What to build

### 1. One function decides the Status icon (ShowreelKit, pure, with tests)

Six states, worst first; the first that applies wins; the tooltip lists every state that applies to the scene with its reason and, when action is needed, the way to fix it.
1. **Needs attention**: red exclamation. The scene's code test failed.
2. **Not written**: grey dashed circle. No scene file yet; it shows as an empty frame.
3. **Out of date**: blue circular arrows. The scene changed since its file was written.
4. **Layout warning**: yellow triangle. Text overlaps or runs off the screen (from the per-scene test).
5. **To review**: orange hammer. Not Ready yet, or Ready was switched off to ask for a modification; the scene's instruction field is shown in the tooltip.
6. **Ready**: green check. Ready and the file is up to date.
The strip's frames and the left list both call this function; remove the separate badge logic of the frames (review round and build square) so there is one language. On a locked scene the tooltip says what is unavailable and why ("Out of date, locked: unlock it to rewrite it"). Edited by hand stays a line in the tooltip, not a state.

### 2. Clear scene rows and transition lines (Storyboard list)

- Scene row: handle, ID in a fixed-width column, then the name as the title and the first words of the scene under it (one line, truncated), then a right-aligned duration column (rounded to 0.1 s), then the three fixed columns Status, eye, lock. The eye and the lock are click targets with tooltips and accessibility labels; the Status is read-only.
- Transition line: indented under the scene it leaves, a thin vertical connector joining the two scenes, a glyph by type (scissors for Cut), the text "Flip card · 0.55 s" with no word "to" ("Cut" for a cut), the existing marks ("approximate render at assembly", "instruction pending") kept, a tooltip "S01 to S02", the selected line highlighted as today. A click still selects the marker on the strip and opens its inspector.
- A "?" button above the list opens a legend (popover): the six Status icons, the eye and the lock, each with its meaning.

### 3. The three switches and Delete in the inspector

- **Visible**: switches the scene in or out of the film (the eye). Refused on a locked scene, with its reason.
- **Ready**: on means the owner is satisfied with the scene; off means To review. Remove the review block (OK, MODIFY, DITCH) and every place that offered them (list, strip menus, context menus). A modification request is the scene's existing instruction field. Clap never switches Ready for the user: it can only propose it on a card the user accepts. Refused on a locked scene with its reason.
- **Locked**: only a Ready scene can be locked; otherwise the switch is unavailable with "Make the scene Ready first". Unlocking is always possible, with Undo. Locking is one typed operation, journalled.
- **Delete scene** (button at the bottom): really deletes the scene, with a confirmation that names what is lost, Undo and a journal line. Refused on a locked scene ("Locked: unlock it first"), and during a Build with its reason. Archived scenes and "ditch" disappear as concepts: map existing archived or ditched scenes to hidden scenes in "Not in the storyboard", keeping any reason as a note. The section "Not in the storyboard" now holds only hidden scenes.
- Every unavailable control uses `disabledWithReason` with the reason and the way back.

### 4. A real lock (single control point: ProjectStore.plan())

A locked scene refuses, with a reason that names the scene and the way out:
- any change to its content, look, duration, visibility, name of its elements, or deletion;
- any move of its place, and any change elsewhere that would move its start time (inserting or deleting a scene before it, hiding or showing one before it, lengthening or shortening one before it, ripple). The refusal says "S07 is locked at 0:24: unlock it, or change a scene after it";
- a rewrite by any Build ("Build a new version", "Rewrite everything", "Generate", "Fix this scene"): it is excluded and listed as locked on the card. Assembly only reads its file.
Locking **takes a copy of the scene's effective look** (palette, fonts, background, effects mood). From then on a global look change no longer reaches it and the "apply anyway" card no longer lists locked scenes. Unlocking drops the copy and the scene follows the global look again; say so on the unlock confirmation when the copy differs from the current global look.
Do not build a "free gap" feature (editing between two locked scenes while keeping the gap constant): one line in docs/Claude/ideas.md.

### 5. The Go gate and the checks

The check "Scene review" reads: every **visible** scene is Ready (a locked scene is Ready by construction, a hidden scene is ignored). Its detail names the scenes that are not. The Go itself stays a button only the user can press. Existing projects: a locked scene that is not Ready is read as Ready, and a scene validated before this phase is Ready, with no migration.

### 6. Clap and the shared files

Update `tools.json` and `Tools.swift` for what changed (set_ready as a proposal card, delete_scene as a proposal card, review tools removed or mapped) and keep "swift app implements every shared tool" green. Update `addendum.md`, `capabilities.json` and, if the app's row in `references/portability.md` has to change to stay in agreement, that file too (then it is a skill change: release notes of the skill first, `python3 tools/bump.py patch`, never edit a version by hand). Do not change the skill's own method (the scene-by-scene review step of SKILL.md and its references keeps its words); only the app rows of the portability table follow the app.

## Out of scope (one line each in docs/Claude/ideas.md if useful)

Editing between locked scenes with a constant gap; the faithful one-scene preview in the centre; any change to the Build; the right-panel density.

## Tests (ShowreelKit unit tests, simulated agent)

The Status function (every state, the priority order, several states at once with the tooltip listing all, Ready only when the file is up to date); the same icon on the list and on the strip; row layout model (columns, rounded duration); transition line text ("Flip card · 0.55 s", "Cut"); each switch's availability and refusal reasons (locked, during a Build, Ready required to lock); Ready off gives To review; Delete (confirmation text, Undo restores the scene and its place, journal line, refused when locked); mapping of archived and ditched scenes to hidden scenes; the lock refusing each listed change including a change elsewhere that would shift its start, with the reason naming the scene and the time; the lock excluding the scene from every kind of rewrite; the look copy taken at locking and the "apply anyway" card not listing locked scenes; unlocking dropping the copy; the Go gate (visible scenes Ready, locked counts, hidden ignored); existing-project reading (locked non-Ready read as Ready, no migration); Clap's tools (set_ready and delete_scene only as proposals, review tools gone). Update the tests that referenced OK, MODIFY, DITCH, the archive and the old badges, and say which changed.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE tools/bump_app.py (and RELEASE-NOTES-SKILL.md before tools/bump.py if the skill changed); never edit a version by hand. Update docs/Claude/ux-notes.md ("Built in UI2 (date)" and what remains), ROADMAP.md and CLAUDE.md "Open work".

## Verification

During the work: tools/verify.sh --fast. At the end: the complete tools/verify.sh, then tools/rebuild-app.sh.

## Final report (docs/Claude/phases/UI2/report.md)

Step 0 results, what was built point by point, the decisions taken, the version(s), what is verified and what is not (no screen: nothing drawn is verified), and "To check by hand": the three columns and their tooltips; each of the six Status states (force a failed test, a missing file, an out-of-date scene, a layout warning); the legend; the transition lines; Ready off then on; locking an unready scene (refused with its reason) and a Ready scene; trying to move, insert before, lengthen an earlier scene, hide, edit and delete a locked scene (each refused with a reason that names the scene); a Build with a locked scene (excluded); a global look change with a locked scene (not touched, no card for it); unlocking; Delete scene with Undo; the Go gate; Clap proposing Ready and deleting only through a card. Stop after the phase.
