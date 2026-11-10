---
type: phase-report
status: current
phase: RL1
date: 2026-11-09
summary: "Report of RL1: the two-group rail with Clap, the full-height shell, the Film placement toggle and the reset icon."
app_version: 0.16.0
prompt:
  - "[[phases/RL1/prompt]]"
decisions:
  - "[[decisions/Clap is an entry of the rail]]"
  - "[[decisions/The sizes the owner drags never change with the Film placement]]"
tags:
  - report
---
# RL1: the rail gets two groups and Clap becomes one of its entries (app 0.16.0, skill untouched)

## Step 0 (read only, before building)

a) **The right panel.** `InspectorPane` held two (three with Advanced) tabs: Inspector, Ask Clap, Files. Look and Project were `SettingsDock`, an overlay at the trailing edge of the project view (its own stored width, 380 min / 560 standard), `.transition(.move(edge: .trailing))` with `Motion.spring` (response 0.32, damping 0.82), over whatever the right side showed; dismissed by its x button, Escape or the old top-bar button. Nothing was replaced: it covered.
b) **The rail (DS1).** Film, Look, Build, Project; one selected; Film and Build closed the settings panel (the exclusivity DS1 noted), Look and Project opened it and the centre showed the design board for Look.
c) **The agent's state.** `ChatModel.running`, `ProjectActivity.clap` (thinking or applying) and `activity.proposals` (the cards waiting); the proposals banner (`ProposalsBanner`) was drawn at the top of the right panel, above the tabs.
d) **Shortcuts already used:** Shift-Command-L (Project Library), Command-Z and Shift-Command-Z (Undo, Redo), Command-S (the file editor), Shift-Command-K (Catalogue), Command-Minus, Command-Equal, Command-Plus (zoom), Command-0 (fit), Space (play, over the strip), Command-comma (Settings), the system ones (Q, W, H, M, C, V, X, A). The Clap input had no focus handling: it took the cursor only by a click.
e) **`ui.json` remembered:** applyDirectly, mode, decided, the panel sizes (`layout`: library, inspector, strip, settings, the Storyboard/Resources split and the Resources state), setupRequired, the strip's scale and scroll, the folded Resources groups, the grid. Not the open panel, not any placement.

## What was built

1. **Two groups in the rail** (ShowreelKit `RailEntry`, `RailGroup`, `RailState`): centre views Film and Build, right panels Inspector, Look, Project, Clap, a thin line between them, the DS1 look; icons from the `IconRole` table (new roles: Inspector, Clap, the two layout pictograms, the reset).
1b. **Shell geometry** (`ShellLayout`, pure): under the unchanged top bar the rail, the left panels and the right panel span the full height; the centre column holds the preview and, under it, the Film strip, as wide as the column; gaps of 6 pt and DS1's rounded panels. Minimum widths (left 200, centre 420 under the preview or 360 at full width, right 280, or 380 for Look and Project, strip 200 high, preview 200 high) give a minimum window (about 978 x 418 with the Inspector under the preview); the window cannot be smaller (a frame minimum in `ProjectView`). The strip's toolbar has **two rows** below 860 pt (`TimelineLayout.toolbarRows`): the title and the transport on the first, the zoom, snap, grid, ripple, Add scene and the film state on the second, scrolling sideways if even that is too wide; the ruler, Fit, the zoom memory and the grid draw from the viewport width as before (`setViewportWidth`). The strip is titled **Film** ("Film · 15 scenes · 1:30.0 of 90 s"), its empty text says "The film has no scene yet. Create scenes in the Storyboard...", the left list stays **Storyboard**; the stored keys, the gate names and "Validate storyboard" are unchanged.
1c. **Film placement**: one button in a view group at the right end of the top bar, **after the Checks badge and the Catalogue** (order: Checks, Catalogue, placement, reset). Its icon is a pictogram of the layout in use (a small window with the rail, the left panels, the preview, the right panel and the Film strip lit in the accent), drawn from the theme and moving with the spring (a plain change under Reduce motion); the tooltip names the state and the action ("Film under the preview. Click for full width"), the accessibility label and value say the same. Two modes: under the preview, and full width (the strip from the left panels to the right panel, the rail still full height, the panels shorter). Stored per project in `.studio/ui.json` (`filmPlacement`, default under the preview). The pictogram roles are in the `IconRole` table (as "pictogram.*" identifiers drawn by the theme, which a skin can replace).
1d. **Sizes independent of the placement.** The dragged sizes stay in `PanelLayout` (`.studio/ui.json`), written only by a drag or the reset; the frames are derived (`ShellLayout.frames`), clamped for drawing without overwriting, so a small window and a placement change never touch what is stored. The **reset icon** (next to the placement button) restores `ShellLayout.standardSizes` (the empty layout) and keeps the placement; tooltip "Restore the standard proportions", accessibility label, the panels move with the spring (`Motion.go`), and it is disabled with "The proportions are already standard" through `disabledWithReason`. **The old "Reset layout" button did the same and was replaced, so there is one reset.** There is no place for an interface undo in the app (undo is the project's typed operations), so the reset is not undoable and I did not invent one.
2. **One right panel at a time, independent of the centre**: `RailState` and `ProjectModel.openRail/applyRail`. A click on the open panel's entry closes the right side; Film and Build never touch the right side, a right panel never touches the centre. **Inspector-selection case:** a selection (a scene, a transition, a resource, a look element) opens the Inspector only when the right side is closed or already on the Inspector; otherwise the open panel (Clap, Look or Project) stays and the Inspector entry gets a small accent dot, which goes when the Inspector opens (step 0 showed no existing rule). The DS1 exclusivity is gone. One thing stays by design: while the Look panel is open, the centre viewer shows the design board (that is what Look contains, not a choice of the centre).
3. **Clap's panel**: the Inspector and Ask Clap tabs are gone. Clap opens as its own panel with the conversation and Memory, Sessions and Journal as tabs inside it (the existing `AskClapPane`), the proposals banner on top; it slides in with the same spring as Look and Project (`.move(edge: .trailing)`, `Motion.spring`), no new motion token. With Advanced on the Inspector panel keeps a Files tab (it had no home in the rail).
4. **Clap's entry shows its state** (`ClapIndicator`): a pulse while the agent works (a static dot under Reduce motion), a badge with the proposals waiting; tooltip and accessibility label "Clap, working", "Clap, 2 proposals waiting". The banner stays as it was; a click on the entry (the badge included) opens the panel with the banner on top, which is "the proposals".
5. **The shortcut: Shift-Command-A**, opens Clap and puts the cursor in its input from anywhere in the project window (a hidden button of the workspace; `ChatModel.focusInput` and a `@FocusState` in the composer); shown in the tooltip. `AppShortcuts` lists every shortcut in use (above) and a test checks that the views declare no letter shortcut outside the list.
6. **Remembered state**: the open right panel (or "none" for a closed side) in `.studio/ui.json` (`rightPanel`), restored at opening, only once the workspace is open; no choice means the Inspector.
7. **Action/reaction**: an entry that cannot be used says why and how to get it back (`unavailable`); Tab reaches the rail and the arrows move between entries (`onMoveCommand`); each entry has an accessibility label that includes its state.
8. **Theme**: only tokens; the colour guard of DS1 still passes with no new allowance.
9. Nothing else changed.

## Tests

`RL1Tests` (19): the groups, the order and the separator; one right panel at a time and the close on a second click; the independence of the centre and the right; the Inspector rule and the mark; Clap's states and labels; the pulse and the dot; the shortcut registry (no conflict, every declared letter shortcut known, the tooltip, the focus); the saved and restored panel and placement; both modes' frames for four window sizes and four right-panel states; the minimum windows and the refusal of anything smaller; the stored sizes untouched by the placement and by a small window; the reset and the kept placement; the button's pictogram role, tooltip and accessibility; the top bar's other controls and the position of the view group; the names Film and Storyboard and the strip toolbar's rows; every role mapped and distinct; every unavailable entry with a reason and a way back.
Changed: `DS1Tests` (the three rail tests were rewritten for the two-group rail: the views the top bar offered, the reason of the old button, the wiring; the right panel's tabs are gone), `MemoryTests` (Clap's panel holds the conversation and its tabs).

## Verified, not verified

- Verified: `tools/verify.sh --fast` during the work and the complete `tools/verify.sh` (VERIFY OK). The rail model, the geometry, the persistence, the registry and the wiring (by source) are tested.
- **Not verified: anything drawn** (no screen): that the panels, the rail, the pictograms and the strip's two-row toolbar look right and fit; that Fit, the ruler labels, the grid and the diamonds read at the centre column's width; that the springs and the pulse run; the keyboard and VoiceOver on the rail; the shortcut. The minimum window sizes come from the model, not from a window I saw.

## To check by hand

1. The shell: the rail, the left panels and the right panel full height under the unchanged top bar; the preview with the Film strip under it in the centre column; the strip at its narrower width (two toolbar rows): Fit, zoom, ruler labels, grid and the transition diamonds still readable; the smallest window and the reset.
2. The strip is titled Film, the left list Storyboard.
3. The view group at the top right: one button whose pictogram shows the current layout (it changes on click, the tooltip names the state and the action); under the preview and full width (the panels move with the spring; Fit and the ruler read well in both; nothing is cut at each mode's smallest window); the choice survives a restart.
4. Drag the sizes you like (left and right widths, the Film height, the Storyboard and Resources divider), switch the placement and back: none moved. The reset icon puts the standard proportions back without changing the placement, and is disabled with its reason when they are standard.
5. The two groups and their separator; each right-panel entry sliding in with the bounce and a second click closing it; Film and Build switching without touching the right side.
6. Clap's pane: the conversation and the Memory, Sessions, Journal tabs; the pulse while Clap works; the badge with a waiting proposal and a click on it; Reduce motion on (System Settings, Accessibility, Display): a dot instead of the pulse.
7. Shift-Command-A from the strip and from the inspector.
8. Quit and reopen the project: the open panel is restored.
9. Select a scene while Clap or Look is open: the panel stays and the Inspector entry shows a dot.
10. Tab and the arrows on the rail; VoiceOver reading the entries with their state.
