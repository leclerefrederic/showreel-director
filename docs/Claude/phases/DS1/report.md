---
type: phase-report
status: current
phase: DS1
date: 2026-11-09
summary: "Report of DS1: design tokens, the dark theme, the rail of views, shared styles and icons by role."
app_version: 0.14.0
prompt:
  - "[[phases/DS1/prompt]]"
decisions:
  - "[[decisions/The open questions are waived during the redesign]]"
tags:
  - report
---
# DS1: design tokens, dark theme and the new shell (app 0.14.0, skill untouched)

## Step 0 (read only, before building)

a) **Colours, fonts, radii today.** Almost all system colours: about 270 `.foregroundStyle(.secondary)` and 24 `.tertiary`, 67 `Color.primary`, 56 `Color.accentColor`, 19 `Color(nsColor: window/control/underPage/textBackground)`; named palette colours (`.orange` 75, `.green` 32, `.red` 26, `.blue` 10, `.gray`, `.yellow`, `.teal`...) for states; 7 hand-made colours (the strip's `StripColor`); status colours of UI2 as a `tone` mapped to system colours. Text: `.caption` 201 and `.caption2` 48, `.callout` 165, `.headline` 48; `.system(size:)` about 60. The files that matter most (colour or font picks): TimelineViews 74, LookViews 68, ResourceViews 63, InspectorViews 51, ChatView 48, WorkspaceViews 41. Radii were hard-coded (5 to 14).
b) **The window.** `ProjectView` = banners above `WorkspaceView` (library | centre | inspector in an HStack with `SplitHandle`s, the strip below), with the settings dock and the Catalogue as overlays and a native toolbar. Top bar: Library (window), Catalogue (floating card), Reset layout, Build (toggled `centerMode` between viewer and build), Project settings (toggled the settings panel, whose two parts are Project and Look) and the Checks badge (UI1); during the base configuration a Workspace button replaced Catalogue and Build. The centre: `CenterMode` (viewer, build, checks), then for the viewer `Resources.viewerSubject` (design board while the settings are open on Look, a selected resource, else the film).
c) **Text under 11 pt.** `.caption` and `.caption2` are 10 pt on macOS (249 uses in 38 files), and `.system(size: 5, 8, 9, 10)` in 8 places (drag handle, chevrons, the override badge, a transition glyph, a few icons).
d) **Appearance.** The app followed the system. Only the strip forced `.dark` for itself.
e) **`disabledWithReason`.** `.disabled(reason != nil)` (the system dims it), `.help(reason. way)`, a clear cover so that a disabled control still has a tooltip, and an optional caption line under it. It keeps working unchanged on the dark theme.

## What was built, point by point

1. **Tokens** (ShowreelKit/DesignTokens.swift, pure): the values of the brief as hex and numbers, `colors`, the scales, `status(_:)` (the six Status colours from the roles), `rgb`, `luminance`, WCAG `contrast`. **No token had to change**: primary and secondary text are 15.7 / 6.1 on the canvas, 14.5 / 5.6 on the panel, 13.1 / 5.1 on the raised surface; the Status colours against the panel are 5.6 to 10.7; the accent is 9.4; on-accent on the accent is 10.2; faint is 2.2 to 2.4, listed as decorative only.
2. **Theme** (ShowreelStudio/Theme.swift): `Theme`, an observable object with `@Published tokens`, read through `@EnvironmentObject` (views) and through modifiers (`fontSmall`, `fontBody`, `panelContainer`, `rowSurface`, `canvasBackground`, `panelBackground`, `raisedBackground`...); no static colour. The shared styles: `PrimaryButtonStyle` (the accent), `SecondaryButtonStyle`, `DestructiveButtonStyle` (an outline), `ThemedToggleStyle` (a switch, accent when on, a real `Toggle` underneath with its value read), `ThemedTextFieldStyle`, `ThemedTabs` (buttons with the selected trait), the panel container, the selected and hover row surface, and the disabled state (unchanged `disabledWithReason`). `IconRole` (ShowreelKit/IconRoles.swift) is the one table of roles to SF Symbols; the Status symbols come through it. No skin loading, import, export or picker.
3. **Source guard** (`DS1Tests.testNoViewPicksANewColourAndNoTextIsBelow11`): per view file it counts colour literals (`Color(red:`, `Color(white:`, `Color(nsColor:`, `NSColor(`...) and named palette colours (`.orange`, `Color.green`...), font sizes under 11 in `.system(size:)`, and `.caption`, `.caption2`, `.footnote`. Sizes under 11 and the old text styles: **0 allowed**. Colours: an allow-list per file, **189 allowed in 32 files** (TimelineViews 37, PackageViews 13, ReactionViews 13, WorkspaceViews 13, ResourceViews 12...), which may only go down: that is the work left for DS2 (the strip and the lists) and DS3 (the inspector and the forms). The 19 `Color(nsColor:)` are gone.
4. **Dark appearance**: `NSApplication.appearance = darkAqua` at launch and `.preferredColorScheme(.dark)` on the library, the project windows and Settings. No setting. A light theme is one line of `docs/Claude/ideas.md`.
5. **Shell**: canvas background; `ViewRailView` (60 pt) at the far left with Film, Look, Build and Project (an icon and a label, the selected one on the selected surface with the accent, a tooltip, VoiceOver label, hint and selected trait); the library, the centre and the right panel are panels (large radius, hairline border) one 6 pt gap apart, the dividers being the gaps (a short accent bar shows under the pointer); the strip keeps its content, clipped to the same radius; the preview keeps its rounded frame and the transport stays. The rail's model is ShowreelKit's `RailEntry`; the click is `ProjectModel.openRail`. The right panel's Inspector and Ask Clap tabs are `ThemedTabs`.
   - **What each old button became.** Build, in the top bar -> the rail's Build (same toggle between the Build view and the viewer). Project settings -> the rail's Project (the settings panel on its Project part) and Look (the same panel on its Look part, with the design board in the centre as before). New: the Film entry (the viewer, closing the panel).
   - **No place in the rail, still in the top bar**: Library (a window), Catalogue (a floating card), Reset layout, the Checks badge (the checks list is a centre view opened from its badge, and no rail entry is selected while it shows), and, during the first setup, Workspace and Project settings (the rail is only in the workspace).
   - **One small behaviour change**: the rail is exclusive, so choosing Film or Build closes the settings panel (the two buttons used to be independent and the panel could stay over the Build view).
   - The top bar is the native toolbar and keeps its content; it is on the dark appearance but its buttons are not restyled with the tokens (a native toolbar does not take custom styles without losing its behaviour): said, not hidden.
6. **Legibility**: 249 `.caption`/`.caption2` became `fontSmall` (11 pt, with the weight kept: `.semibold` and `.bold` remain, the weights rule is for DS2/3); the `.system(size:)` of 5, 8, 9 and 10 pt became 11 (7 places); 19 system backgrounds became the panel or raised surface; 4 selected-row backgrounds became `rowSurface`; 41 `.borderedProminent` buttons became the primary style; every `.toggleStyle(.switch)` became the themed switch; the Status icons and the legend take their colours from the theme. Everything else (named colours, `StripColor`) is left for DS2 and DS3.
7. Nothing else changed: no new feature, setting or behaviour; the Build, the skill and the shared tools are untouched. Existing tests all pass; none of them referenced the top bar's Build or Project settings buttons, so none changed (`UI2Tests.testTheLegendHasTheSixStatesTheEyeAndTheLock` now reads the lock and eye symbols from the icon table).

## Tests

`DS1Tests` (15): the contrast function (the classic cases), the text on every surface, the Status colours and the accent on the panel, faint below the text threshold on purpose, the values of the brief, no size under 11 and ascending scales, every token read by Theme.swift, the theme as an observable object in the environment with the app dark, every icon role mapped and the six Status symbols distinct (and the Status icons coming through the table), the rail (one entry per old centre view, targets, where the workspace is, the reason the old button gave), the rail and the top bar wired to the same views (source), the source guard with its allow-list and a test that the guard sees what it should.

## Verified, not verified

- Verified: `tools/verify.sh --fast` during the work, the complete `tools/verify.sh` (VERIFY OK), `tools/rebuild-app.sh` (SELFTEST OK, BUNDLE OK, the app opens, pid 74483). The tokens, the contrast, the icon table, the rail model, the wiring (by source) and the guard are tested.
- **Not verified: anything drawn.** No screen was used and no project window was opened: nothing about how the window looks (the panels, the rail, the tabs, the switches, the dark surfaces under the strip and the lists) is verified. A view that reads the theme from the environment would fail at run time if one window had no theme injected; the three scenes of the app have it, and the project windows were not opened here.

## To check by hand

1. The whole window on a laptop screen: are the panels and the rail readable, is anything cut or clipped (the rail takes 60 pt and the gaps 6 pt more than before).
2. Each rail entry reaches its view: Film (viewer), Look (the settings on the look, the design board in the centre), Build, Project (the settings on the project part); click the lit one again.
3. The segmented tabs (Inspector, Ask Clap), a switch (Visible, Ready, Locked), a primary button (Build a new version) and a secondary one.
4. A disabled control: it must be dimmed and still say why on hover (Ready on a locked scene).
5. The strip and the lists on the dark canvas: anything unreadable or still light, any text or icon whose colour does not read.
6. The Settings window (Command-,) and the Library window: dark.
7. The six Status colours on the panel surface (the legend under the "?").
8. The keyboard (Tab to the rail and the tabs, Space to press) and VoiceOver on the rail: label, hint and "selected".
