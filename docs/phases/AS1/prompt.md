---
type: phase-prompt
status: current
phase: AS1
date: 2026-11-09
summary: "Asks for autosave: no Save button, what you type or add is saved."
report:
  - "[[phases/AS1/report]]"
ux:
  - "[[ux/Motion, the interface answers]]"
tags:
  - prompt
---
# Phase AS1: no Save button, what you type or add is saved

Read CLAUDE.md, then docs/ux-notes.md (the entries "Forms (owner, after DS1)", "State section: no Instruction field", "Duration stepper" and the UI principle), docs/phases/DS2/report.md, docs/phases/UI2/report.md, and the code: the scene inspector's Settings tab with its "Save scene" and "Revert" buttons (InspectorViews.swift), every other form that has a Save, Apply, Revert or Done-to-commit button (ProjectSettingsForm, GlobalLookSettings and its editors, the Composition and Effects tabs, the resource details and tags, the package sheets, Settings), `ProjectStore.plan()` (the single control point), the typed operations, the undo mechanism and its toast, the journal, `CloseGuard`, the Build freeze, `Availability`, `disabledWithReason`. Follow every rule of CLAUDE.md (never run git, English interface, skill untouched, no out-of-scope work: an idea goes in docs/ideas.md in one line). Views stay free of business logic: the rules live in ShowreelKit with tests.

## The owner's rule

"We should not have to save. What you type or add is saved, period." No Save button and no Revert button in the app's editing forms. Undo is the way back.

## Step 0 (read-only, 10 lines at the top of docs/phases/AS1/report.md)

a) Every form or panel that commits through a Save, Apply, Revert, Done or Return-to-keep control today, with what it commits (list them all, by file).
b) Which of them are genuinely transactional and should stay as they are (creating a project, a confirmation card, a Clap proposal accepted or refused, saving or importing a package, a rights confirmation, a Build card): say why for each.
c) How an edit becomes an operation today (the form builds one operation from several fields? one per field?), what `plan()` validates, and what the "send the scene back to To review" rule does.
d) How undo works (one step per operation? the toast), and how it would deal with many small commits.
e) What happens today when Clap or another path changes a scene while the owner has an unsaved edit open.

## What to build

1. **An edit session rule in ShowreelKit (pure, with an injected clock, with tests).** Commit when: a text field loses focus, or Return is pressed, or the owner pauses typing for a short time (a named constant, 700 ms by default); a numeric field loses focus, or Return is pressed, or after a step with the stepper or the arrow keys (debounced by a named constant, 300 ms, so holding a chevron does not make a commit per tick); a switch, a chip or a picker choice commits at once. Never commit an invalid value: the field keeps the owner's draft, shows its inline error and nothing is saved until it is valid or the owner restores the stored value. Selecting another scene, switching a tab, closing the pane or the window, or starting a Build commits a pending edit first (use `CloseGuard` for the window and the quit case).
2. **Every form listed in step 0 that is not transactional becomes autosaving:** remove the Save and Revert buttons and their helper sentences, starting with the scene inspector's Settings tab ("Save scene", "Revert", the sentence "Changing the text or the duration sends this scene back to To review..."). Each field commits through the existing typed operation and `plan()`, so every rule still holds: a locked scene refuses with its reason (the field is disabled with that reason), a Build in progress refuses with its reason, the journal gets its lines.
3. **One undo step per edit session.** Consecutive commits to the same field within a short window (a named constant, 2 s) collapse into one undo step, so Undo takes back "what I typed in this field", not a letter. **Command-Z is the way back, and it must work the same everywhere (the owner: Revert is useless because Command-Z works).** Command-Z and Shift-Command-Z work from a focused field and from anywhere in the window, through the Edit menu and the toast's Undo. Before the commit (inside the pause) the text field's own native undo takes back the typing; after the commit the app's Undo restores the previous stored value, and the field shows it. Do not let the two stacks fight: undoing must never produce a new commit that records itself as a fresh edit, must never need two presses for one edit, and Redo must work after an Undo. State in the report how you tied the field's native undo to the app's, and what you did where that is not possible. Switching to another field or scene closes the session.
4. **A visible reaction to every save, and to every refusal (action/reaction).** After a commit, a small "Saved" mark (a check) appears next to the field's label and fades after about 1.5 s, with the motion tokens of DS2 (a static mark under "Reduce motion"). When a commit changes the scene's state (text or duration sent it back to To review), the Status icon animates as DS2 defines and the status line says it once with Undo ("S02 is back to To review"); do not repeat that message for each commit of the same session. When a commit is refused or fails, the field shows the reason and the way out next to it, keeps the draft, and nothing is lost silently.
5. **Changes made elsewhere while a field is being edited.** If Clap or another path changes the stored value of a field that is not being edited, the field updates and shows a quiet "Updated" mark. If the field is dirty (the owner is typing), the owner's text is kept, and when it commits it wins over the other change; the journal records both. State the rule you applied in the report.
6. **Keep what must stay explicit:** the transactional flows listed in step 0 b (creating a project, Build and Generate confirmation cards, Clap proposals, package save and import, the rights question, Delete scene's confirmation). Do not turn any of them into autosave. List them in the report.
7. **Nothing else changes.** No new feature, no restyle (DS3 does the forms), no change to the Build, the skill or Clap's tools. If the app's text in `capabilities.json` or `references/portability.md` says the owner saves or reverts a scene's fields, correct the app's row to match; if the portability table must change, that is a skill change (release notes of the skill first, `python3 tools/bump.py patch`, never edit a version by hand).

## Tests (no screen, injected clock)

The session rule: commit on blur, on Return, after the pause, and not before; a numeric step debounce; a switch commits at once; an invalid value never commits and the draft stays; a pending edit commits before a scene switch, a tab switch, a window close and a Build start; the undo coalescing (several commits to one field inside 2 s are one undo step, a pause or another field starts a new one, Undo restores the previous stored value); Command-Z and Shift-Command-Z from a focused field before and after the commit (one press per edit, no fresh commit recorded by the undo itself, Redo restores the edit); a locked scene's field refuses with its reason and keeps no draft; a Build in progress refuses with its reason; the To review rule fires once per session and says so once; a change made elsewhere updates a clean field and never overwrites a dirty one; the journal has one entry per commit. Update the tests that assumed Save and Revert and say which.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE tools/bump_app.py (a minor version); never edit a version by hand. Update docs/ux-notes.md ("Built in AS1 (date)" and what remains), ROADMAP.md and CLAUDE.md "Open work".

## Verification

During the work: tools/verify.sh --fast. At the end: the complete tools/verify.sh, then tools/rebuild-app.sh.

## Final report (docs/phases/AS1/report.md)

Step 0 results, what was converted and what stayed explicit and why, the constants chosen (pauses and windows), the version, what is verified and what is not (no screen, no real typing: nothing felt or drawn is verified, say so plainly), and "To check by hand": type in the Feeling field and pause (it saves, "Saved" appears, the Status icon goes back to To review once and the status line says so once with Undo), type then click another scene (nothing lost), Return, the Duration stepper held down (one commit, one Undo step), an invalid duration (inline error, nothing saved), a locked scene (fields disabled with the reason), a Build running (refused with its reason), Command-Z after typing, both before the pause ends and after the save (restores the previous text in one press) and Shift-Command-Z (puts it back), closing the window with a pending edit, the same in the Project form and the Look editors, a change by Clap while you type in another field, and that no Save or Revert button remains anywhere. Stop after the phase.
