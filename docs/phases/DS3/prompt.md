---
type: phase-prompt
status: current
phase: DS3
date: 2026-11-10
summary: "Asks for the inspector, the forms and the tabs on the tokens, with a form system."
report:
  - "[[phases/DS3/report]]"
ux:
  - "[[ux/Motion, the interface answers]]"
  - "[[ux/Visual direction]]"
decisions:
  - "[[decisions/Keep the Project button in the scene inspector header]]"
  - "[[decisions/The instruction field is the scene note and does not switch Ready]]"
tags:
  - prompt
---
# Phase DS3: forms, inspector and tabs on the tokens

Read CLAUDE.md, then docs/ux-notes.md (the entries "Visual direction", "Motion: the interface answers", "Forms (owner, after DS1)", "Alignment in the inspector", "Real tabs", "Other details seen on the same screenshot", "Same slide-in for the Project panel" and "Sizes and reset"), docs/phases/DS1/report.md, docs/phases/DS2/report.md, docs/archive/BATCH-A/report.md, and the code: the scene inspector (InspectorViews.swift and its State section), the project settings forms (ProjectSettingsPanel.swift, ProjectSettingsForm, GlobalLookSettings and the editors it opens), the Clap panel's tabs (ChatView), SettingsView (the Settings window), Theme.swift, the Motion file, the `DesignTokens`, `IconRole`, `disabledWithReason`. Follow every rule of CLAUDE.md (never run git, English interface, skill untouched, no out-of-scope work: an idea goes in docs/ideas.md in one line). The owner waived the open questions of docs/ideas.md for the redesign: the defaults that exist today stand. Views stay free of business logic.

The owner loves the look of the app today: **change only what is listed here**, and keep every behaviour. Where an existing colour has no token, add a token with that value rather than changing the colour. The selection highlight of the Storyboard list keeps its current fade (the owner chose to keep it).

## Step 0 (read-only, 10 lines at the top of docs/phases/DS3/report.md)

a) The colour literals still left (counts per file from the DS1 guard's allow-list), by area (inspector, forms, Clap panel, Settings window, other).
b) Which controls produce tab-like bars today (segmented pickers used for panes), where, and which genuinely choose a mode or a value.
c) How the label and icon rows of the inspector's State section and of the forms are laid out, and why the labels start at different x positions.
d) How wide the right panel and the sliding panes are by default and how a pane's width is stored and clamped (RL1's stored sizes).
g) Where the scene's note or instruction is written and read (inspector, Status tooltip, Clap's tools, journal, Build context).
f) Every place the interface offers "Duplicate" for a scene (inspector, menus, list, strip) and what else uses the operation (Clap tools, tests).
e) Which buttons use the default grey style where a role (primary, secondary, destructive) applies; which text fields show a scroll track; where the tooltip that covered the Duration label is attached.

## What to build

### 1. One form system (pure rules in ShowreelKit with tests, drawn by ShowreelStudio)

A `FormLayout` of constants on the spacing scale: the icon slot width (one fixed width for every icon and label row), the trailing slot width for a switch, the label gap, the field height, the field radius (a token), the vertical rhythm between fields, the minimum field width. Tests: every value is on the scale of the tokens; the field height is the same for every kind of text field.
- **Icon and label rows** (the State section: Visible, Ready, Locked; and every other row that pairs an icon with a label in forms, menus and lists): one shared row view with a fixed-width icon slot, so the labels share one left edge, and a fixed trailing slot for the switch, so the switches share one right edge. Replace the ad hoc layouts.
- **Text fields**: fill the width of their pane (flexible width, sensible minimum, never a fixed narrow box), one height and one radius from the tokens, a label above or in a fixed column, a placeholder that is a real example, a clear focus ring in the accent, an error state and its inline message next to the field. The custom duration field next to the 30 s to 90 s choices uses the same field style at a width that fits its value.
- **Numeric fields get a stepper** (the owner's request, seen on the scene inspector's Duration field): small up and down chevrons at the right end, inside the field, for every numeric field (the scene's Duration in the inspector, the project's custom target duration, and any other number field you find). A click on a chevron moves the value by one step; the Up and Down arrow keys do the same while the field has focus; Option makes the step fine (0.1 s), Shift makes it coarse (5 s); holding a chevron repeats. The step, the fine and coarse steps, the minimum and the maximum, the rounding to a readable precision (0.1 s) and the clamping are a pure `NumericField` rule in ShowreelKit with tests; the displayed value is always rounded. The chevrons follow the field's states: hover, focus ring, and disabled with its reason (a locked scene's Duration says it is locked and how to unlock it). Typing a value still works and is validated inline; an out-of-range value is clamped with a message, never silently.
- **Multi-line fields** grow with their text up to a limit, and use overlay scrollbars shown only when something scrolls (no empty scroll track on two lines of text).
- **Choice chips** (the 30 s to 90 s durations, the formats, the languages): one chip style from the tokens with selected, hover and disabled states; the selected one uses the selected surface and the accent.
- **Buttons by role**: primary (at most one per view), secondary, destructive (an outline in the danger colour: "Delete scene..." uses it) and quiet. **Remove the "Duplicate" button** (the owner never asked for it): take it out of the scene inspector and out of every other place the interface offers it (context menus, the Storyboard list, the strip). Keep the typed operation and its tests in ShowreelKit and any Clap tool that uses it: do not delete them, and list in the report every remaining use (the interface, Clap's tools, tests) so the owner can decide later. If `capabilities.json` or `references/portability.md` name duplicating a scene as something the interface does, correct the wording of the app's row to what the interface now offers; if the portability table must change, that is a skill change (release notes of the skill first, `python3 tools/bump.py patch`, never edit a version by hand).
- **State section: remove the Instruction field and its helper sentence** ("To ask for a change: switch Ready off and write the instruction. Press Return to keep it."). The owner finds this mechanic makes no sense: it asks for two steps, a hidden commit key and a field that is greyed while Ready is on. The State section keeps three switches (Visible, Ready, Locked) and "Delete scene...". A change is asked for in the ways that already exist: edit the scene's own fields (Feeling and tension and Passage to the next scene in Settings, the content and the animation of each item in the Composition tab once the Effects tab is merged into it, see section 2b), which send the scene back to To review when saved, or talk to Clap with the scene selected. Do not build a replacement field in this phase. Existing data is never deleted: a note already stored on a scene (from an earlier MODIFY or an instruction) stays in the file and is shown read-only, in the Status tooltip of a To review scene and in a quiet line under the switches ("Earlier note: ...") only when one exists. Find every writer and reader of that note (the inspector, the Status tooltip, Clap's tools such as `update_scene`, the journal, the Build's scene context) and list them in the report: keep Clap's ability to read it and the journal, remove only the inspector's way of writing it, and say what Clap's tools can still set. Correct the tooltip of the Status function (the To review text said the instruction field is shown) and the app rows of `capabilities.json` that describe it; if `references/portability.md` has to change to stay in agreement, that is a skill change (release notes of the skill first, `python3 tools/bump.py patch`, never edit a version by hand).
- **Disabled state** keeps its reason from `disabledWithReason` and is readable (the Instruction field, when disabled, says why).
- **Tooltips**: a pane-level help is not attached to the whole pane (the one about the composition must not appear over the Duration field): attach each help to its own control and use the standard delay.

### 2. Real tabs

A reusable tab bar (the pure model in ShowreelKit: the tabs, the selected one, the keyboard order; the view in ShowreelStudio): underline style, the active label in primary text with an accent underline, inactive labels in secondary text, a hairline under the bar, hover state, an accessibility role of tabs with the selected one announced, arrow keys move between the tabs. The underline moves between tabs with the base duration of the motion tokens (no slide under "Reduce motion": a quick fade or at once). Apply it to: the scene inspector (Settings, Composition, Look: the Effects tab is removed, see 2b), the Project and Look tabs of the settings pane, and the Conversation, Memory, Sessions and Journal tabs of the Clap panel. Segmented controls stay where a control chooses a mode or a value (for example a Library or Media style choice); list in the report which controls you left segmented and why.

### 2b. Remove the scene inspector's Effects tab (owner: "the Effects tab has no value")

The tab holds only the "Animation of each item" choice (per item: Auto or a fixed animation) and a read-only "Project effects pack" line with "Change in the project settings". Remove the tab. Move the per-item animation choice into the Composition tab, on the row of the item it applies to (same control, same operation, same rules: a locked scene disables it with its reason), keeping the helper sentence as a tooltip on that control. Drop the read-only pack card (the Project panel and its button already show the pack); if the pack name is useful, show it once as a quiet line at the foot of Composition. Step 0 addition: i) where the Effects tab's controls are written and read, and every other place that names the tab (Clap tools, tooltips, docs, tests). Keep the operations and data unchanged. Tests: the tab model has three tabs for a scene.

### 3. Panes

A wider default width for the settings pane and the inspector (say a value in the tokens, and report it), resizable by dragging the pane's inner edge with the width stored with the other stored sizes (RL1: stored apart from the layout, clamped when drawing, never overwritten) and restored by the reset icon to the standard proportions. A minimum and a maximum width in `ShellLayout`, tested.

**The Project button of the inspectors stays (owner, reversing an old note; "the transition too").** The headers of the scene inspector AND of the transition inspector (and of any other inspector view that has one) keep their "Project" button (icon and label; `InspectorViews.swift` has it in two places, around lines 292 and 393, check which inspector each belongs to and list every inspector view in the report with or without the button, then give all of them the same one): do NOT remove it. Today it only sets `project.selection = .none`. Decide with step 0 what that shows now that Project is a right panel of the rail (RL1): the button must take the owner to the project settings, so make it open the Project right panel exactly as the rail's Project entry does (one shared operation, so the rail entry, this button and the Clap-panel link cannot drift), keep the deselection only if it shows something meaningful and say so. Give it the button style by role (quiet), the icon from `IconRole`, a tooltip ("Project settings") and an accessibility label. Add to step 0: h) what `selection = .none` shows in the inspector today and where the two Project buttons are.

### 4. Tokens everywhere in these areas

Replace the colour literals of the inspector, the forms, the Clap panel and the Settings window by token colours; the source guard's allow-list goes to zero for those files. Report how many literals remain in the whole app and where (they become DS4 or the list of owner decisions, not part of this phase).

### 5. Nothing else

No new feature, no behaviour change, no change to the Build, the skill, the strip or the Storyboard list (done in DS2), no light theme, no skin loading, no change to the top bar or the rail.

## Tests (no screen)

`FormLayout` values on the scale and the field height unique; the `NumericField` rule (one step up and down, fine and coarse steps, clamping at the minimum and maximum, rounding to 0.1 s, a typed out-of-range value clamped with its message, disabled with a reason on a locked scene); the tab model (selection, keyboard order, one selected tab, wrap rules); the pane width rules (default, minimum, maximum, stored and clamped without overwriting, the reset restores the default); the source guard for the files of these areas; the icon and label row's slot widths are the constants of `FormLayout`. Update tests that referenced old layouts and say which.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE tools/bump_app.py (a minor version); never edit a version by hand. Update docs/ux-notes.md ("Built in DS3 (date)" and what remains), ROADMAP.md and CLAUDE.md "Open work".

## Verification

During the work: tools/verify.sh --fast. At the end: the complete tools/verify.sh, then tools/rebuild-app.sh.

## Final report (docs/phases/DS3/report.md)

Step 0 results, what was built point by point, the default pane width chosen, which controls stayed segmented and why, how many colour literals remain in the app and where, the version, what is verified and what is not (no screen: nothing drawn or animated is verified, say so plainly), and "To check by hand": the State section (the three labels aligned on one left edge, the switches on one right edge, no Instruction field, only an earlier note under the switches when one exists, Delete scene in the destructive style, and no Duplicate button anywhere: inspector, context menus, list, strip); the scene inspector's tabs (underline, hover, keyboard, the underline moving, Reduce motion on); the same tab style in the settings pane and in the Clap panel; the Duration field's up and down chevrons at its right end (click, repeat on hold, the arrow keys, Option for 0.1 s and Shift for 5 s, the limits, a locked scene's field disabled with its reason) and the same on the project's custom target duration; the Project form at its default width and dragged wider and narrower (fields fill the width, nothing clipped, the custom duration field, the chips, the languages); the reset icon restoring the pane width; a two-line text field with no empty scroll track; hovering the composition help no longer covers the Duration label; the Settings window. Stop after the phase.
