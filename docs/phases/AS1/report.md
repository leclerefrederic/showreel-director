---
type: phase-report
status: current
phase: AS1
date: 2026-11-10
summary: "Report of AS1: no Save button, what you type or add is saved, and which forms are not converted yet."
app_version: 0.18.0
prompt:
  - "[[phases/AS1/prompt]]"
tags:
  - report
---
# AS1: no Save button, what you type or add is saved (app 0.18.0, skill untouched)

## Step 0

a) Commit controls found: scene inspector Settings/Composition (`Save scene`, `Revert`, StoryboardViews.swift); palette editor (`Save palette`, `Revert`, LookViews.swift); content item (`Apply`, ContentViews.swift); transition (`Apply`, ReelViews.swift); also `Save` of a history rename (HistoryViews), the API key (SettingsView), `Save in the library` and `Done` (PackageViews), `Keep mine` (file editor, EditorViews), the confirmation cards (ChatView, SceneStateViews, FilmStateViews).
b) Transactional, kept: confirmation cards and Clap proposals (a decision), Build and Generate cards, a look change on locked scenes (card), package save and import (writes outside the project), the rights question, Delete scene's confirmation, creating a project, the API key (a credential), the file editor's disk-conflict choice.
c) A form builds one `SceneEdit` from the fields that differ (one operation, one undo step); `plan()` checks locked scenes and a Build in progress; a text or duration change on a validated scene sends it back to To review.
d) One undo step per operation (`UndoLog`, 100 steps) with a toast; many small commits would flood it, hence the coalescing below.
e) The old form kept the owner's unsaved draft and ignored the other change until Save (the draft then won silently).

## Built

- `EditSession` (ShowreelKit, pure, clock passed in): text commits on blur, Return or a 0.7 s pause; numeric on blur, Return or 0.3 s after a step (stepped changes only); instant fields at once; an invalid draft never commits and stays; `flush()` for another scene, tab, pane or window close, or a Build; `restore`; `load` (a clean field follows a change made elsewhere: "Updated"; a dirty one keeps the draft and its commit wins; the journal has both).
- `SceneFields`: the six fields, their kinds, the duration check, the operation.
- Undo: `ProjectStore.coalesceLast(key:)` folds a commit into the step before when it edited the same key within 2 s (journal lines kept); Undo restores the previous stored value in one press, Redo puts it back, neither records an edit.
- **Native undo and the app's**: after a commit the focused field's own undo stack is cleared, so before the commit Command-Z undoes the typing (the existing Edit menu prefers the field's manager when it can undo) and after it Command-Z reaches the app's Undo. Where no text view has focus the app's Undo is used.
- Reactions: "Saved" (check, fades after 1.5 s, static under Reduce motion), "Updated", the To review status line once per session with Undo, an inline reason with "Restore the saved value", fields disabled with the reason for a locked scene or a Build.
- Converted: scene form, palette editor (0.7 s pause, one commit per run of changes), content item and transition (generic `autoCommit` modifier, same pause, flush on leaving).
- Constants: text pause 0.7 s, step debounce 0.3 s, undo window 2 s, mark 1.5 s.

## Deviations and left

- Not converted (still with their own control): the project form, the other Look editors, the file editor, the history rename's Save, resource details and tags, Settings. The prompt asked for every non-transactional form; these were not reached. Listed in ROADMAP.
- The duration field has no stepper today, so the stepped-debounce rule exists and is tested but nothing feeds it.
- Content items and transitions use their existing operations and status line on each commit (the To review line is once-per-session for scene fields only).
- `capabilities.json` and `portability.md` say nothing about saving a scene: unchanged.

## Tests

`AS1Tests` (12): blur, Return, pause, step debounce, instant, invalid draft, flush, change elsewhere, review announced once, undo coalescing and Redo, a pause or another field starts a new step, journal, locked scene refuses, no Save/Revert in the converted forms. The "Save scene" button had no test.

## Verified, not verified

Verified: the complete `tools/verify.sh` (VERIFY OK), `tools/rebuild-app.sh`. **Not verified: anything on screen or typed**: focus changes, the pause timer, the native undo hand-over, the marks.

## To check by hand

Type in Feeling and pause (saved, "Saved", status line once with Undo if it was validated); type then click another scene (nothing lost); Return in Duration; an invalid duration (message, nothing saved, Restore); a locked scene (fields disabled with the reason); a Build running; Command-Z before the pause (typing undone) and after the save (previous text, one press), Shift-Command-Z; close the window with a pending edit; the palette editor, a content item, a transition; a change by Clap while you type in another field; no Save or Revert left in those four places.
