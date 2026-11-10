---
type: phase-prompt
status: current
phase: W4
date: 2026-11-10
summary: "Asks for the timing of each content item inside a scene and for thumbnails and the viewer drawn from the content, audit first."
tags:
  - prompt
---

# Phase W4: timing inside the scene, and a viewer and thumbnails drawn from the content (audit first)

Read CLAUDE.md, then `docs/Claude/Index.md` and open only what it points to for: `docs/Claude/studio-spec.md` (sections 5.5 "Editing workspace", 3.1 "showreel.json", 10 "Phases", the row of W4), `docs/Claude/ux-notes.md` (the notes "Scene content", "Storyboard and music", "Inspector, scene", "Build and preview", "Guiding principle", "Motion, the interface answers"), the reports of W1c, T2, W3b, W5, AS1, DS3, DS3b, RB1 and BA1 (what the content model, the grid, the film layer, direct manipulation, autosave, the form system and the film writer already do), and the code: `Content.swift` (the item model; `in` and `out` are reserved there "to come with W4"), the scene inspector's Composition rows, the storyboard strip and its thumbnails, the preview pane and the film layer, `Film.write`, the skill's export of a project (`showreel-director/references/`), `Availability`, `disabledWithReason`. Follow every rule of CLAUDE.md (never run git; English interface; answer the owner in French and short; the skill is changed only if the audit shows it is needed, and then through `tools/bump.py` with `app-swift/shared/capabilities.json` matched in the same change; no work outside the phase: an idea goes as a note created with `python3 tools/docs_new.py idea "<title>"`). Views stay free of business logic: the rules live in ShowreelKit with tests.

**Note on the spec.** The row of W4 in `docs/Claude/spec/10 Phases.md` mentions "scene-wide effects in the Effects tab". That tab was removed in DS3 (each item's own animation control lives in its Composition row; `SceneTab(.effects)` opens Composition). Scene-wide effects are out of this phase unless step 0 shows a scene-wide control already exists; say what you find.

## The owner's goals

1. **Timing inside the scene.** Each content item gets an `in` and an `out` (when it appears and leaves, in seconds from the scene's start), fixed or auto like every other attribute of the item (auto = the AI decides; an item with no timing keeps working as today). A scene can then be assembled and timed by hand.
2. **A viewer and thumbnails drawn from the content.** The scene's thumbnail and the viewer show what the content says: the items' text, resolved colours (roles from the project's palette, custom hex), images from resources, and, at a given time, only the items active at that time. They never invent what the AI has not produced: an `auto` colour or animation is drawn neutral and flagged as "AI decides".
3. **The storyboard** shows one thumbnail per scene (no repeated identical tiles, UX note "Storyboard and music") and several real frames at different times only when they differ; the viewer, when nothing is selected and there is no build, follows the playhead and shows the scene under it (UX note).
4. **`storyboard.md` and the skill export** (spec section 10): the visual column generated from the content, and the skill's export of a project carrying the new timing, if the audit shows the skill needs a change.

## Step 0 (read-only, the top of docs/Claude/phases/W4/report.md)

1. **Where things are today**: the item model and which attributes are fixed or auto; what the scene thumbnails and the viewer draw now and from what data; how the preview and the film layer render a scene; the storyboard's repeated-thumbnail and blank-viewer defects (are they still there?); how `storyboard.md` and the skill's export are written; the grid and snapping from T2; how Composition rows edit an item; what a locked scene refuses; autosave and undo (AS1).
2. **A proposal, not a build**: how timing is shown and edited (for example a small in/out strip under the Composition rows, steppers with the form system's `StepperField`, snapping to the music grid when a track is analysed), the rules (in before out, inside the scene, what happens to items when the scene's duration shrinks or grows, overlap is allowed, auto timing), how a thumbnail is drawn from items without running the AI build, how the active items at time t are computed (a pure function in ShowreelKit with tests), and what each of these changes in the project file (`showreel.json` schema: a new optional field only, with a migration test for old files).
3. **The choices that are the owner's** (the form of the timing control; snap to the beat grid or not; units in seconds or beats; whether the viewer plays the timing live): do not decide them. For each one create a question note with `python3 tools/docs_new.py question "<title>"` (fill `blocks: [W4]` and a one-line `recommendation`), apply the default you recommend behind it, and list only the question IDs and titles in the report, one line each, never a long text.

## What to build

1. The timing rules and the active-items function in ShowreelKit (pure, with tests), the optional `in` and `out` fields with a schema-safe read of old projects, and the typed operations to set them (journaled, one undo step per field per 2 s as in AS1, refused on a locked scene with a reason through `Availability`, never a silent disabled control).
2. The control in the scene inspector (from the proposal), with the form system and the tokens, a visible reaction to every action, and the standard states.
3. Thumbnails and the viewer drawn from the content by the rules above; one thumbnail per scene by default; the viewer follows the playhead when nothing is selected and no build exists. Reduce Motion respected.
4. The `storyboard.md` visual column and the skill export, only as far as step 0 justifies; if the skill changes: `python3 tools/bump.py`, `capabilities.json` and the app's tools matched, `tools/check.py` passing, and a skill release note.
5. **Nothing else**: no new look, no change to the rail, the top bar, the Build or the transitions, no scene-wide effects unless step 0 says they already exist. Do not touch `docs/Claude/spec/` text: add what changed to the UX note ("Built in W4 (date)" and what remains) and fix the W4 row only by a line saying what was built and what the Effects tab became (the row's text otherwise stays).

## Tests (no screen)

Timing rules (in before out, clamped to the scene, duration shrink and grow, auto), the active items at several times, old projects without `in` and `out` open unchanged, a locked scene refuses and says why, undo and autosave grouping, the thumbnail's data (colours resolved from roles, auto drawn neutral and flagged), the single thumbnail rule, and the viewer following the playhead. Update the tests that assumed the old behaviour and say which.

## Release

Release notes in `RELEASE-NOTES-APP.md` BEFORE `tools/bump_app.py` (a minor version: a new capability; say why) and, only if the skill changed, in `RELEASE-NOTES-SKILL.md` BEFORE `tools/bump.py`; never edit a version by hand. The report names both versions (the skill's even if unchanged).

## Vault

Create the report in `docs/Claude/phases/W4/report.md` with its properties; link the question notes you created; settle any idea this phase built (`status: superseded`, `outcome: built`, with a link to the report) and any question it answered; update `CLAUDE.md` "Open work" (the last built is W4; the next is PK2 and N); run `python3 tools/docs_index.py --write` and `python3 tools/check_docs.py`.

## Verification

During the work: `tools/verify.sh --fast`. At the end: `python3 tools/check.py`, the complete `tools/verify.sh`, then `tools/rebuild-app.sh`. Say which you ran.

## Final report (docs/Claude/phases/W4/report.md)

Step 0 (today, the proposal, the questions as IDs and titles); what was built and what was changed in each file area; the project-file change and its migration; whether the skill changed; the versions; the tests; what is verified and what is not (no screen: nothing drawn, dragged or animated is verified, say so plainly); and "To check by hand": add two or three items to a scene and set their in and out in the inspector (values refused outside the scene, the reason shown); change the scene's duration and watch the items follow the rule; check the thumbnail and the viewer show the right items at several playhead positions, with colours from the palette and "AI decides" items neutral; check a long scene shows one thumbnail; check the viewer with nothing selected follows the playhead; lock a scene and check edits are refused with a reason; undo; open an old project and check it is unchanged; if a track is analysed, check the snapping. Stop after the phase.
