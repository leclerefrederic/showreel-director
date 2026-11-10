---
type: phase-prompt
status: current
phase: DS2
date: 2026-11-09
summary: "Asks for the Film strip and the Storyboard list on the tokens, and for the motion language."
report:
  - "[[phases/DS2/report]]"
ux:
  - "[[ux/Library, Scenes tab]]"
  - "[[ux/Motion, the interface answers]]"
  - "[[ux/Visual direction]]"
tags:
  - prompt
---
# Phase DS2: the Film strip and the Storyboard list on the tokens, and the motion language

Read CLAUDE.md, then docs/Claude/ux-notes.md (the entries "Visual direction", "Motion: the interface answers", "Scene row icons, decided by the owner", "Lock, owner's rule", "Film placement toggle" and "Sizes and reset"), docs/Claude/phases/DS1/report.md, docs/Claude/phases/UI2/report.md, docs/Claude/archive/BATCH-A/report.md, and the code: TimelineViews.swift (the Film strip), the Storyboard list rows and transition lines, Theme.swift and the `DesignTokens`, the `IconRole` table, the status line with Undo, Marks.swift, the Build progress state (`SceneRun.State`), `DragDropViews.swift`, and the springs already used by the sliding panes (Look, Project, Clap). Follow every rule of CLAUDE.md (never run git, English interface, skill untouched, no out-of-scope work: an idea goes in docs/Claude/ideas.md in one line). The owner waived the open questions of docs/Claude/ideas.md for the redesign: the defaults that exist today stand. Views stay free of business logic.

## Goal

Two things, one phase. (1) The Film strip and the Storyboard list stop picking their own colours: they read the tokens, and the strip stops being cluttered. (2) The interface answers: a small motion language, defined once as tokens, applied where the owner acts on the strip and the list, so that what happens is visible. The owner loves how the app looks today: **do not change the look of the strip and the list beyond what is listed here**. Where an existing colour has no token, add a token with that existing value instead of changing the colour.

## Step 0 (read-only, 10 lines at the top of docs/Claude/phases/DS2/report.md)

a) The colour literals left in the strip and the list files (counts per file, from the DS1 guard's allow-list) and which existing token each maps to or needs.
b) Why the strip is cluttered on the owner's screenshot: the big red text of the thumbnails crossing frames, the transition diamonds and the scene labels drawn over it. How a thumbnail is placed in a frame narrower than 16:9 (does it overflow into the next frame? is it clipped?), and where the diamonds, labels, status icons and durations are drawn relative to it.
c) What animations already exist (the panel springs, anything else) and where each is defined.
d) How the list rows and the strip frames are identified (stable IDs), so that arrival, departure, selection and state changes can be animated per row.
e) Why the viewer shows a black frame with red and yellow bars at 0:00 of a built film (report only, no fix in this phase): what it draws before Play and whether that is expected.

## What to build

### 1. The motion tokens (ShowreelKit, pure, with tests) and reusable modifiers (ShowreelStudio)

- Durations: fast about 120 ms, base about 200 ms, slow about 300 ms. Curves: a decelerating curve for what arrives, an accelerating one for what leaves, a small overshoot reserved for arrivals and confirmations. Register the existing panel spring (the slight bounce the owner likes on Look, Project and Clap) as a named token and make the three panes use the token instead of their own value, with the same feel.
- A speed scale (1 by default, 0 means off) that a future skin can set, and a single function that applies "Reduce motion" from the system: movement becomes a short fade or nothing, the information stays.
- Reusable SwiftUI modifiers in a Motion file next to Theme.swift, named by meaning, for example: slide the selection, change a state (a short morph or pulse of an icon), toggle (slide a switch, cross-fade an icon with a tiny scale), arrive, depart, settle, nudge (a small shake of a control that refused, with the reason shown where the eye is). Views never use a raw duration or curve; a source guard test fails when a view outside the Motion file uses one (the allow-list starts with what exists today and may only go down).
- Rules: input is never blocked while something animates; no motion longer than about 300 ms for a direct action; motion is never the only carrier of meaning (the icon, the text and the tooltip stay); no animation that costs frames on a list of 100 scenes (animate only the rows that changed).

### 2. The patterns, applied to the strip and the list

- **Selection** moves: the selected highlight of the list slides between rows, and the selected frame outline of the strip follows; no jump.
- **State change** is visible: when a scene's Status icon changes (for example Out of date to Ready) it morphs or pulses once; the eye and the lock cross-fade with a tiny scale; the Ready, Visible and Locked switches of the inspector slide.
- **Arrival and departure keep their place:** a new scene opens a gap in the list and in the strip and arrives into it; a deleted scene closes its gap; Undo plays the same movement back. Reordering by the handle keeps its existing gap behaviour.
- **A refusal nudges:** when a locked scene or a Build refuses an action, the control that was used does a small nudge, and the reason (already produced by `plan()`) appears in the status line next to the pointer's area, with its way out, as it does today.
- **Progress where the work is:** during a Build the scene rows and the strip frames show the scene's run state differently: waiting (a still dot), writing (a gentle pulse), testing (a short progress sweep), repairing (an alternate mark), and a finished scene settles into its normal Status icon. The data is the existing `SceneRun.State`; the Film strip and the list read it through ShowreelKit. Under "Reduce motion" the states differ by icon and label, not by movement.
- **Transition diamonds** pop slightly when selected; a drop target highlights while a catalogue item is dragged over it.
- **Panels** keep the spring token (point 1).

### 3. The strip stops being cluttered (what the owner sees today)

- A thumbnail is **clipped to its own frame**: it never draws into the neighbouring frame. When the frame is narrower than 16:9 the thumbnail is cropped (centred or from the left, say which in the report), never overflowing.
- The big text of the thumbnails does not cross the frames and does not sit under the scene label, the Status icon, the duration or the transition diamonds: either the thumbnail's text is drawn at a size that fits the thumbnail, or the label, icon and duration live in a header and a footer band of the frame that the thumbnail does not cover. Choose the least intrusive that keeps the current look and say which in the report.
- The transition diamonds sit on the cut between two frames without hiding a label or an icon; if two things still collide at a narrow width, the label gives way (it truncates), never the Status icon or the diamond.
- Everything else about the strip (frames, ruler, grid, music lane, colours, the Film toolbar) keeps its current look and behaviour; colours move to the tokens one for one.

### 4. Tokens everywhere in these two areas

Replace the colour literals of the strip and the list with token colours (adding tokens for existing values where needed, each with a contrast test if it carries text or an icon). The source guard's allow-list for the files of these two areas goes to zero; report how many literals remain in the whole app for DS3.

### 5. Nothing else

No new feature, no change to behaviour or to the Build, no change to the inspector or the forms (DS3), no light theme, no skin loading, no change to the top bar. Under "Reduce motion" every pattern still shows its information.

## Tests (no screen)

The motion tokens (durations on the scale and at most 300 ms for direct actions, the speed scale, the "Reduce motion" mapping gives fade or none, a speed of 0 gives none); the panel spring token is the value the three panes use; the source guard (no raw duration or curve in views outside Motion, no colour literal in the strip and list files); the pure layout rule for a thumbnail in a frame (the drawn rectangle always lies inside the frame for a range of frame widths and heights, at 16:9 and narrower, cropped not overflowing) and for the label, icon, duration and diamond slots (no overlap of the Status icon and the diamond at any frame width from very narrow to wide); the per-row identity used for animation; the Build run state to row and frame appearance mapping (every `SceneRun.State` has a distinct label and icon that does not depend on motion). Update tests that referenced old colours or layouts and say which.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE tools/bump_app.py (a minor version); never edit a version by hand. Update docs/Claude/ux-notes.md ("Built in DS2 (date)", what remains for DS3), ROADMAP.md and CLAUDE.md "Open work".

## Verification

During the work: tools/verify.sh --fast. At the end: the complete tools/verify.sh, then tools/rebuild-app.sh.

## Final report (docs/Claude/phases/DS2/report.md)

Step 0 results, what was built point by point, the choices made for the strip (crop, header and footer bands or text size), the motion tokens and where each is used, how many colour literals remain in the app, the version, what is verified and what is not (no screen: nothing drawn or animated is verified, say so plainly), and "To check by hand": the strip with 15 scenes at its width in both Film placements (text no longer crossing frames, labels, icons, durations and diamonds readable, nothing overflowing, zoom and Fit); each motion pattern one by one (the highlight sliding when you select a row and a frame, an icon changing state, the eye and lock toggles, the switches of the inspector, adding a scene and deleting it then Undo, a refused action on a locked scene nudging with its reason, a Build showing waiting, writing, testing and repairing on the rows and frames and settling, a diamond selected, a catalogue item dragged over a diamond); the same with "Reduce motion" on (System Settings, Accessibility, Display); a list of 15 scenes scrolling and animating smoothly; the three panes still sliding with the same bounce. Stop after the phase.
