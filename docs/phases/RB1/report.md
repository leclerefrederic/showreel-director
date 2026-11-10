---
type: phase-report
status: current
phase: RB1
date: 2026-11-10
summary: "Report of RB1: the audit of the rail's buttons, one tested rule, the fixes and four questions for the owner."
app_version: 0.19.2
prompt:
  - "[[phases/RB1/prompt]]"
decisions:
  - "[[decisions/Clap is an entry of the rail]]"
  - "[[decisions/Keep the Project button in the scene inspector header]]"
tags:
  - report
---
# RB1: the behaviour of the rail's buttons (app 0.19.2, skill untouched)

The owner said the behaviour of the rail's buttons "must be reviewed" without saying what is wrong, so the phase started with an audit (step 0, read only) and fixed only clear inconsistencies. Taste choices are in "Questions for the owner".

## Step 0: the audit (state before RB1)

Common to the six: one `Button` in `ViewRailView` (Theme.swift), the model is ShowreelKit's `RailEntry` / `RailState`, the click is `ProjectModel.openRail`, the rail is drawn only in the workspace (so no entry was ever unavailable), the selected state was a surface plus the accent plus an outline, a tooltip from `.help`, the label from the title, the traits `isButton` and `isSelected`. No hover, no pressed state, no focus ring (the system ring only appears under Full Keyboard Access). The arrows moved one entry up or down across all six, without wrap. The selected state is derived from the model's flags, so it cannot drift from what is on screen, except as listed below. Stored at launch: only the open right panel (`rightPanel` in `.studio/ui.json`, "none" for a closed side, no choice means the Inspector); the centre view is never stored (the app opens on the Film).

| Entry | Group | Click, closed | Click, already open | Another right panel open | Centre / right interplay | Shortcut, in the tooltip | Tooltip | Unavailable | Animation |
|---|---|---|---|---|---|---|---|---|---|
| Film | centre | shows the viewer | nothing | not touched | never touches the right side | none | "The film: the viewer, with what you select" (no name) | never (rail only in the workspace) | none on the button |
| Build | centre | shows the Build | **toggled back to the Film** | not touched | never touches the right side | none | "Build the film, test it and play it" (no name) | never | none |
| Inspector | right | opens it | closes the right side | replaces it | does not touch the centre | none | description only | never | panel spring on the panel |
| Look | right | opens it (the centre shows the design board) | closes | replaces | same; while open, the viewer shows the design board and Film stays lit | none | description only | never | panel spring |
| Project | right | opens it | closes | replaces | does not touch the centre | none | description only | never | panel spring |
| Clap | right | opens it | closes | replaces | does not touch the centre | Shift-Command-A, shown | "Clap, state. description (Shift-Command-A)" | never | panel spring; pulse while working (dot under Reduce Motion) |

Visible states: selected for all; badge only for Clap (count) and the Inspector (mark after a selection); pulse only for Clap. Accessibility: label = title (Clap: its state, Inspector: "a new selection is waiting" when marked), hint = description, traits button and selected.

### Inconsistencies found

1. **Build toggled off, Film did not.** The two centre views behaved differently on a second click.
2. **A request for Clap did nothing when Clap's tab was already the stored one.** Build start, "Draft scenes", a card to answer (`ChatModel.focus(card:)`) and the wizard set `inspectorTab = .copilot`; its observer only opens the panel when the value changes. If Look or Project covered the right side, or the side was closed, while the tab was still Clap, the request had no visible reaction (a Build ran with no conversation in view). Four places did it by hand, `openClap` (the shortcut) did it right.
3. **The Inspector's mark could stay on the open Inspector.** Any path that brought the Inspector back without a click on its entry (opening a music target, a check) left the mark on a lit entry, and it could come back later when another panel opened.
4. **The tooltips of five entries did not say the entry's name**, only a description; the standard of "name and shortcut" held only for Clap.
5. **No hover, pressed or focus ring**, and the arrows crossed the group boundary and stopped at the ends instead of moving inside the group.
6. **The three paths to the Project panel agree** (rail entry, the Project button of the inspector headers through `openRail`, `openSettings` from a check or Clap's zone): the same panel, the same tab. The only difference is toggle against open: the header button exists only while the Inspector is open, so Project is closed then and the toggle is an open. No change.
7. **Not a defect, listed:** Look open shows the design board in the centre while Film is lit. And `openZone("inspector")` (a copilot request) opens the Project panel; its name is part of the skill's tool contract, so it stays.
8. **Inspector with nothing selected:** the rail lights Inspector while the panel shows its own empty content; the entry and the panel agree. No change.

## What was fixed (before, after)

1. **One rule in ShowreelKit** (`RailShell.swift`): `RailState.choose` (centre views never toggle off, a right panel closes when its open entry is clicked again, a click on another replaces it), `RailState.buildStarted()`, `RailState.inspectorMarked`, `RailEntry.label` / `tooltip` / `shortcut`, `RailEntry.neighbour` (arrow order), `RightSide` (the stored flags of the right side and the one panel they show; writing a panel always makes it the visible one). The views only call it.
2. Build click when active: toggled to the Film, now nothing; the Film is the way back (before, after tested).
3. Clap requests: `ProjectModel.showClap()` replaces the four hand writes, and a Build start runs `buildStarted()` (Build in the centre, Clap on the right, whatever was open). `setRight` and `rightPanel` go through `RightSide`.
4. The mark: `persistShell` clears it whenever the Inspector is the open panel; the rail draws it only when `inspectorMarked`.
5. Tooltips: name, description and shortcut for the six, the reason and the way back instead when an entry is unavailable (`.disabledWithReason`); same text as the accessibility label.
6. States: one `RailButton` with rest, hover (raised surface), pressed (selected surface), selected (surface, accent, outline), keyboard focus (accent ring) and the badges that apply, from the tokens; the change uses `Motion.quick`, which is nil (a static change) under Reduce Motion.
7. Keyboard: Tab reaches the six; the arrows move inside a group and wrap; Space and Return activate (native buttons). No new shortcut.

## Tests (no screen)

`RB1Tests` (15): click closed, open and with another panel open for every right panel; the centre views never toggle off and never touch the right side, and a right panel never touches the centre; at most one lit entry per group; the unavailable tooltip with reason and way back; the arrow order and wrap; the tooltips (name, description, shortcut only for Clap); the six labels; `RightSide` from seven starting states to every panel; Build start from every state; the mark; selecting a scene or a transition; launch, Reset and the layout button leave the rail alone (by source); every way to open Clap goes through the rail's operations and no hand write remains; the view calls the rule and draws the states (by source).
Changed: `RL1Tests` (two assertions: Build no longer toggles; the shortcut is in the tooltip through `RailEntry.tooltip`).

## Questions for the owner (taste, not decided)

1. Should a click on the active Build leave the Build? RB1 applied the default rule (no centre view toggles off); the Film entry is the way back.
2. While the Look panel is open the viewer shows the design board and Film stays lit. Light Look in the centre group too, or leave it?
3. A shortcut for the other panels (for example Shift-Command-I for the Inspector) is an obvious gap next to Shift-Command-A; none was added.
4. Should the mark on the Inspector also appear when the side is closed and a selection happens? Today a selection opens the Inspector then.

## Version, verified, not verified

Patch **0.19.2**: fixes of behaviour and states, no new capability.
Verified: `tools/verify.sh --fast` during the work; the complete `tools/verify.sh` and `tools/rebuild-app.sh` at the end (results in the last message). The rule, the right-side writes, the arrow order, the tooltips and labels, the mark, the Build start and the wiring (by source) are tested.
**Not verified (no screen): anything drawn or animated**: that the hover, pressed, selected and focus states look right and are distinct at the rail's size, that the ring is visible on the canvas, that the quick animation runs and is static under Reduce Motion, the tooltip delay, the keyboard (Tab, arrows, Space, Return) and VoiceOver on the rail, and that Clap's panel really appears at a Build start.

## To check by hand

1. Click each entry closed, open and with another panel open: Film and Build never close anything; Build twice stays on the Build; Inspector, Look, Project and Clap close on a second click and replace each other.
2. Tab through the rail, then the arrows inside each group (they wrap, they do not leave the group), Space or Return to activate; the focus ring is visible.
3. Hover and press each entry; wait for the tooltip: name, description and, for Clap, Shift-Command-A.
4. Turn Reduce Motion on (System Settings, Accessibility, Display): the states change without animation, Clap shows a dot instead of the pulse.
5. Open Look, then ask for "Draft scenes" or start a Build: Clap's conversation must appear. Do the same with the right side closed.
6. Select a scene while Look or Clap is open: the Inspector entry shows a dot, and it goes when the Inspector opens by any way.
7. Click Reset (the icon) and the layout button: the rail still matches the screen. Quit and reopen: same.
8. Start a Build: the Build entry and Clap are lit, and the Film one is not.
