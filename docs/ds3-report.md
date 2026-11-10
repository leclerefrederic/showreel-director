# DS3: forms, inspector and tabs on the tokens (app 0.19.0, skill untouched)

## Step 0 (read only)

a) Literals before: InspectorViews 3, ContentViews 1, ReelViews 2, StoryboardViews 2, SceneStateViews 1, BlockViews 1, ProjectFormViews 9, ProjectSettingsPanel 2, LookViews 10, PickerViews 3, ChatView 3, HistoryViews 7 (the Clap panel), SettingsView 0. All moved to the theme's roles (success, warning, danger, accent, on-accent) except the colour-picker data (`Color(hex:)`, user palettes).
b) Segmented pickers used for panes: the scene inspector, the settings pane, the Clap panel (now real tabs). Kept segmented: Edit / Preview of a file (a mode of one file).
c) The State rows used `Label(title, systemImage:)` whose icon width follows the symbol, hence different left edges; the switch is a label, spacer, 34 pt switch row. Now `IconRow` with fixed slots.
d) Panes: stored in `PanelLayout` (inspector 390, settings 560 before), clamped when drawn by `ShellLayout.frames`, dragged with `SplitHandle`, reset by the reset icon. Now 440 / 620 by default, at most 720 / 900 (`PaneWidth`).
g) The scene note: written by the inspector's Instruction field (removed) and by Clap's `update_scene` (still can); read by the Status tooltip, `SceneStatus`, the Checks ("To review, a change was asked"), the journal and the Build's scene context. Clap can still set `note`. The Status tooltip wording was corrected.
f) "Duplicate" for a scene was in the scene inspector, the strip's context menu and the list's menu (`SceneMenu`): all removed. Remaining uses: `ProjectModel.duplicateScene`, `ProjectStore.duplicateScene` and its tests, and Clap's tools if one names it (none found in the interface). Duplicating a content item (`duplicateItem`) was kept: it is not a scene.
e) The Effects tab: its per-item animation control already existed inside each Composition item row, so the tab was removed and the existing control got the helper as a tooltip. Every place naming the tab: the capabilities row (corrected), `ErgonomicsTests` (updated), `SceneTab(.effects)` now opens Composition.
h) `selection = .none` showed the project inspector; there were two Project buttons (the shared `InspectorHeader` and the scene inspector's own). Both now use `ProjectButton`, which calls `openRail(.project)`; the selection is no longer cleared, because the Project panel shows the settings, not the selection. Every header with the button: scene, transition, resource, look element.
i) See e.

## Built

1. ShowreelKit: `FormLayout` (slots, field height, radius, rhythm, chips), `NumericField` (steps 1 / 0.1 / 5, limits, rounding, clamping with a message, typed values), `TabBarModel`, `PaneWidth` and wider standard widths.
2. `FormViews.swift`: `IconLabel`/`IconRow`, `TabBar` (underline that moves with `Motion.select`, hover, arrows, selected trait, hairline), `StepperField` (chevrons, hold to repeat, Option and Shift), `ChipStyle`, `ProjectButton`.
3. Applied: tabs in the scene inspector, settings pane and Clap panel; stepper on the scene's Duration and on the project's custom duration (minimum 5 s, maximum 600 s: a new bound, say if wrong); State rows aligned; Instruction field and its sentence removed, "Earlier note" read-only; Delete scene destructive style; no scene Duplicate; no Effects tab.
4. Colours: the named areas are at zero (guard in `DS3Tests`). **109 literals remain in 21 files** (BuildViews 6, ChecksView 4, DesignBoardView 2, DragDropViews 7, EditorViews 5, FilmStateViews 11, FontStateViews 3, LibraryView 3, NewProjectViews 1, PackageViews 13, ProjectLifecycleViews 2, ProjectView 2, ReactionViews 13, ResourceViews 12, SetupFormView 2, SetupView 2, WizardStartViews 3, WorkspaceViews 13, plus 5 `Color(hex:)` of user palettes in Content, Inspector and Look): DS4 or owner decisions.

## Not done

- One text-field style for every field (height, radius, focus ring, error state) and a flexible width everywhere: only the Duration fields use the new field.
- Multi-line fields that grow with their text and overlay scroll bars (the rule `FormLayout.areaLines` exists and is tested; the views still use a fixed `TextEditor` height).
- A review of every button's role (primary, secondary, quiet) across the app; only Delete scene and the duration chips were changed.
- Moving every pane-level `.help`; the composition help is on the Overview group, not on the Duration field, so I made no change.
- The Up and Down arrow keys in the stepper use `onMoveCommand`, which a text field may swallow: not verified, and macOS 14's `onKeyPress` is unavailable on the macOS 13 target.

## Tests

`DS3Tests` (11): scale, area growth, stepper, rounding and clamping, stepped debounce, tab model, three scene tabs, pane widths, no colour in the named areas, slots and no scene Duplicate, the Project button. Updated: `DS1Tests` allow-list (109), `ErgonomicsTests` (three tabs), the AS1 session gained `markStepped`.

## Verified, not verified

Verified: complete `tools/verify.sh` (VERIFY OK), `tools/rebuild-app.sh`. **Not verified: anything drawn, hovered, typed or animated.**

## To check by hand

State section (labels on one left edge, switches on one right edge, no Instruction field, an earlier note only when one exists, Delete scene in the destructive style, no Duplicate in the inspector, context menus, list and strip); scene inspector tabs (underline, hover, arrows, the underline moving, Reduce motion); the same bar in the settings pane and the Clap panel; the Duration chevrons (click, hold, arrows, Option, Shift, limits, locked scene disabled with its reason) and the project's custom duration; the Project form at default, wider and narrower; the pane widths (440 / 620 default, dragging, the reset icon); the Project button in the scene, transition, resource and look inspectors; the Settings window.
