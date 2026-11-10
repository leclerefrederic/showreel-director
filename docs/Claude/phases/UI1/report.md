---
type: phase-report
status: current
phase: UI1
date: 2026-11-09
summary: "Report of UI1: the left panel as the Storyboard with the Resources below, and the decisions the owner can reverse."
app_version: 0.12.0
prompt:
  - "[[phases/UI1/prompt]]"
decisions:
  - "[[decisions/Checks are a badge in the top bar]]"
  - "[[decisions/The left panel splits two thirds Storyboard and one third Resources]]"
tags:
  - report
---
# UI1: the left panel becomes the Storyboard, with the Resources below (app 0.12.0, skill untouched)

Vocabulary used in the interface and the comments: Storyboard = the plan of the montage; Film = the assembled result. The strip and the left list are two views of the same storyboard.

## What was built, point by point

1. **No tabs for Resources and Scenes; a vertical split.** `LibraryPane` (StoryboardListViews.swift) stacks the Storyboard (about 2/3) and the Resources (about 1/3) with a draggable divider. The divider's share and the Resources' state (open, collapsed to the header, expanded to the full height) are in `PanelLayout` (`split`, `resources`, ShowreelKit), saved in `.studio/ui.json` per project; "Reset layout" clears them. The geometry is `LibrarySplit.heights`: floors of 140 pt for the Storyboard and 90 pt for the Resources, 34 pt headers, the divider is inert when the Resources are collapsed or expanded (its tooltip says why). The Transitions tab is gone (the file TransitionsViews.swift is deleted).
2. **A flat list.** `StoryboardList` (ShowreelKit) gives the entries: scenes of the film in order, one transition line between two consecutive scenes ("to Cross dissolve, 0.8 s", "to Cut", with the marks "approximate render at assembly" and "instruction pending" kept), none after the last scene or for a single scene. A click on a scene calls `select(.scene)`, a click on a line `selectTransition(from:)` (the call the diamond makes). Rows are dragged by their handle with the gap that opens (`reelSlot`): the scene moves with its outgoing transition because the transition belongs to the item of the montage (tested). "Not in the storyboard" lists switched-off and archived scenes with the reason (tooltip) and the way back ("Switch on", "Bring back"); a switched-off scene can be dragged into the list. Toolbar above the list: New, Draft, Lock all (the label is shorter, the actions are the same). Rename in place (double-click), Duplicate, Archive (context menu), and "Switch off" (context menu).
3. **Icons only.** `SceneIcons` (ShowreelKit, pure): review (to review, approved, to modify), locked, build (not generated, up to date, stale, edited by hand, failed its test), layout warnings, in that order, at most four, each with a tooltip (reason, and the way to fix it, and why the fix is not available now when it is not). The review icon is still a menu to change the state (as the badge was); the others only tell. The view collects the input from the film state, the failed-test record (BA2) and the warnings of the last Build.
4. **The tree moved to the Inspector.** `SceneTreeView` is now the "Overview" (a disclosure group, open by default) at the top of the scene inspector, above the tabs. It was moved whole, so nothing it offered was lost: click a group or a node to open the tab on that element, drops on the groups and nodes, drag to change the priority of an element, duplicate/remove/unlink from the context menu, the review and build marks and the override badge in its Look group. It is therefore not strictly read-only (the owner's text asked for a read-only overview): I kept the actions rather than drop them silently; they can be taken out later if the owner wants a purely read-only one. The chevron that unfolded the tree in the list is gone (nothing unfolds there any more).
5. **Checks.** `ChecksBadge` in the top bar ("Checks 3", red if one is red, orange otherwise, plain "Checks" with a seal when nothing needs attention, tooltip with the red/orange split). A click opens the list in the centre (`CenterMode.checks`, with "Back to the viewer"), the same grouping and the same click-through (`openCheck`); a click on a check leaves the list for the element. The count is `CheckPanel.attention`, what the tab showed (`CheckBadge`, tested).
6. **Drop targets.** A resource is accepted by a scene row (`.dropTarget(.scene)`), by a strip frame (already there) and by the Overview of the inspector (`.dropTarget(.scene(id))` on the group, and its nodes keep `.sceneNode`). The token `studio:resource:<id>` and `DragRun` are untouched. A locked scene refuses with its reason (`SceneLock.reason`), a Build refuses everything with "Building..." (tested). The spring-loaded tab idea is removed from `docs/Claude/ux-notes.md`.
7. **Selection in step.** One model (`project.selection`); the list lights a row when `selection.sceneID` is that scene, so a node selected in the Overview or a frame of the strip lights it too. A source scan test checks that the list, the strip and the inspector call the same functions and that there is no second selection state.
8. **Keyboard.** `ListKeys`: with the pointer over the Storyboard, up/down call `stepScene` (what the strip's arrows call, playhead included), Delete or forward-delete switches the selected scene off (existing operation, with Undo). No new shortcut.

## Decisions the owner can reverse

- **Checks as a badge in the top bar** (decision of the brief). The alternative is a thin status row at the bottom of the left panel; the list and the click-through would not change, only where the badge is. Noted in `docs/Claude/ideas.md`.
- **The split is 2/3 and 1/3** by default (`LibrarySplit.standard`), the divider range 25 to 85 percent.
- **The Overview is the whole tree**, including its actions (see point 4), and it duplicates the review badge that the inspector header already shows.
- **The "In the film" checkbox of the old list rows is gone.** The ways to switch a scene on or off are now: the context menu "Switch off", the Delete key, the "In the film" switch of the scene inspector, the strip, and "Switch on" under "Not in the storyboard".
- **The look-override badge** no longer shows on the row (it is not one of the four icons); it shows in the Overview under Look.
- **The list reorders with the montage's slots** (`reelSlot`), not the library's: so a scene dragged from "Not in the storyboard" is put in the film at the place of the drop.

## Tests

- New: `UI1Tests` (16): the flat list (order, line between pairs only, single scene, marks, "Not in the storyboard" with reasons and ways back), a move carries the outgoing transition, the icons (kinds and fixed order, at most four, review wording, five build states with five symbols and tooltips with the reason and the fix, every tooltip has a reason), the selection (source scan: the same calls in the list, the strip and the inspector, no second state), the keys and the absence of the tabs, drops (row, frame, overview accept; locked refuses with its reason; a Build refuses with its reason), the layout memory (saved and restored, standard layout, other sizes kept), the split geometry and floors, the badge count equals `CheckPanel.attention` with the "nothing needs attention" case.
- Changed: `LookSettingsTests.testTheLibraryKeepsAssetsOnly` (no `LibraryTab` any more) and `LifecycleTests.testTheLibraryWindowShowsStatusAsTextAndTheChecksLiveInTheBadgeAndTheCentre` (renamed; it asserted the four tabs, it now asserts no `LibraryTab` and the `checks` center mode).

## Verified, not verified

- Verified: `tools/verify.sh --fast` during the work, the complete `tools/verify.sh` (VERIFY OK), `tools/rebuild-app.sh` (SELFTEST OK, BUNDLE OK, running, pid 19532). The rules are tested (the list model, the icons, the split, the layout memory, the badge, the drop verdicts).
- **Not verified: anything drawn.** No screen was used: the look and the fit of the rows (the name, the duration and the icons in a 290 pt wide panel), the divider's drag, the Overview's density, the badge, the list in the centre and the keyboard are untested by eye. The drop on a row, a frame and the Overview is tested as a rule, not as a gesture.
- Vertical room on a laptop (from the arithmetic, not seen): a 13-inch screen leaves a window of about 800 pt; minus the title bar and the top bar (about 52 pt) and the strip at its standard 300 pt, the left panel is about 440 pt tall. At 2/3, the Storyboard gets about 290 pt (its header, the toolbar and about six scene rows with their transition lines) and the Resources about 150 pt (header plus about four rows). The floors (140 and 90 pt) hold if the strip is made taller; "Expand" gives the Resources about 400 pt.

## To check by hand

1. Drag the divider, quit and reopen the project: it is where you left it. Collapse the Resources, quit, reopen: collapsed. "Expand", then "Restore" (in the Storyboard header).
2. The Storyboard is flat: a thin line between scenes ("to Cross dissolve, 0.8 s", "to Cut"), none after the last. Click a transition line: the marker is selected on the strip and its inspector opens, as with the diamond.
3. Drag a scene by its handle: it moves with its outgoing transition, with the gap opening.
4. Look at the icons of each row and read every tooltip (review, locked, build state, warnings): reason and way to fix it. Is a row too crowded at 290 pt?
5. Select a scene: the Overview at the top of its inspector. Click a node: the matching tab opens on that element. Judge the density of the right panel.
6. The Checks badge in the top bar: its count against what the tab used to show; click it, then click a check: you land on the element.
7. Drag a resource onto a scene row, onto a strip frame and onto the Overview: each links it. Lock a scene and try again: refused, with the reason. Start a Build and try again: refused with "Building...".
8. Pointer over the list: up/down move between scenes, Delete switches the scene off (Edit > Undo brings it back). Switch one off by hand and drag it back from "Not in the storyboard" into the list.

Recorded as decisions: [[decisions/Checks are a badge in the top bar]], [[decisions/The left panel splits two thirds Storyboard and one third Resources]].
