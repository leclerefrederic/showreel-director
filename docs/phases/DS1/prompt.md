---
type: phase-prompt
status: current
phase: DS1
date: 2026-11-09
summary: "Asks for design tokens, a dark theme and the new shell with the view rail."
report:
  - "[[phases/DS1/report]]"
ux:
  - "[[ux/Library, Scenes tab]]"
  - "[[ux/Visual direction]]"
decisions:
  - "[[decisions/The open questions are waived during the redesign]]"
tags:
  - prompt
---
# Phase DS1: design tokens, dark theme and the new shell

Read CLAUDE.md, then docs/ux-notes.md (section "Visual direction", plus "Library, Scenes tab" for the vocabulary), docs/phases/UI2/report.md, and the code: App.swift, ContentView.swift, the left panel, centre and right regions (LibraryPane, PreviewPane, PlayerViews, BuildViews, InspectorViews, ChatView), the top bar and its buttons, SettingsView, the strip (TimelineViews.swift, only to see what it reads), `disabledWithReason` and Availability, and every place that picks a colour or a font size (search for `Color(`, `.foregroundStyle`, `.font(`, `.caption`, `NSColor`). Follow every rule of CLAUDE.md (never run git, English interface, skill untouched, no out-of-scope work: an idea goes in docs/ideas.md in one line). The owner waived the open questions of docs/ideas.md for this phase: the defaults that exist today stand. Views stay free of business logic.

## Goal

A dark editor look with our own identity (a graphite canvas, rounded panels, one teal accent), applied through ONE set of design tokens so that no view picks its own colour, radius or text size. This phase builds the tokens, the shared control styles and the shell (window, rail, panel containers, top bar). The strip, the lists and the inspector's inside are DS2 and DS3: here they must stay correct and legible on the dark window, not be redrawn.

## Step 0 (read-only, 10 lines at the top of docs/phases/DS1/report.md)

a) Where colours, fonts and radii come from today (system colours, hard-coded values, status colours from UI2): counts per file, the files that matter most.
b) How the window is composed (regions, split views, the top bar, what the four buttons of the top bar switch in the centre) and how the centre pane picks its view.
c) Which text styles are smaller than 11 pt today and where.
d) What the app does about light and dark appearance today.
e) How `disabledWithReason` draws its disabled state and its reason.

## What to build

1. **Design tokens in ShowreelKit (pure, with tests).** A `DesignTokens` type holding hex values and numbers, no SwiftUI. Start from these values and adjust only if a contrast test fails (then say which):
   - Surfaces: canvas #0F1115, panel #161A20, raised #1F232A, selected #1D2A2C.
   - Borders: hairline #262B34, strong #2F3642.
   - Text: primary #E8EAEE, secondary #8B93A1, faint #4A515E (faint is for decoration and disabled only, never for information without a tooltip).
   - Accent (selection and the one primary action) #2DD4BF, on-accent #0F1115.
   - Roles: warning #F5C453, danger #F87171, success #4ADE80, review #F59E0B, out-of-date #60A5FA (the Status colours of UI2 keep their meaning).
   - Lanes: scene #2A3550, scene border #3B4A6A, music #D9A441.
   - Radii: 6, 8, 12. Spacing: 4, 8, 12, 16, 24. Type sizes: small 11, body 13, title 15, large 22, never below 11. Weights: regular and medium only.
   - A pure function for the WCAG contrast ratio, and tests: primary and secondary text against canvas, panel and raised are at least 4.5:1; each Status colour and the accent against panel are at least 3:1; faint is allowed below that but is listed as decorative-only; on-accent against accent is at least 4.5:1.
2. **A theme file in ShowreelStudio** (Theme.swift) mapping tokens to SwiftUI colours, fonts and radii, and the shared control styles: primary and secondary button (one primary per view), destructive outline button, toggle (a switch with the accent when on), segmented tabs, a panel container (rounded, hairline border, panel surface), a selected row, a hover row, a text field, a tooltip-friendly disabled state that still shows the reason from `disabledWithReason`. Use SF Symbols (no new icon font). **Groundwork for future skins (no skin loading in this phase):** the theme is an observable object injected through the SwiftUI environment and every view reads it from there (no static colours, no global constants read at draw time), so that a later phase can swap the tokens at run time; and icons go through a stable semantic role (an `IconRole` enum such as status.review, status.ready, lock.closed, lock.open, visible.on, visible.off, with the six Status roles distinct) mapped to SF Symbol names in ONE table in ShowreelKit, with a test that every role is mapped and that no two Status roles share a symbol. Do not build loading, import, export or a picker of skins. Keep native controls underneath (Toggle, Button, Picker with custom styles) so keyboard use and VoiceOver keep working: every custom control keeps its accessibility label and value.
3. **A source guard test.** A test that scans the ShowreelStudio sources and fails when a view outside Theme.swift contains a colour literal or a font size below 11 that is not in an allow-list; the allow-list starts with what exists today (the count may only go down), and the report says how many remain for DS2 and DS3.
4. **Dark appearance.** The app windows use the dark theme (force the dark appearance on the main window and the Settings window; no setting yet). A light theme is out of scope (one line in docs/ideas.md).
5. **The shell.** Canvas background; the left, centre and right regions as rounded panels with a 6 pt gap; a narrow **view rail** at the far left with an icon and a short label per centre view: Film (the viewer), Look, Build, Project, with the selected one on the selected surface and the accent. The rail replaces the four buttons of the top bar and switches the same centre views, with the same behaviour and the same availability reasons; list in the report any button or view that has no place in the rail instead of dropping it. The top bar keeps what it has today (project name, film state, the Checks badge, whatever else), restyled with the tokens; do not add actions and do not move any behaviour. The right panel's two tabs (Inspector and Ask Clap) become segmented tabs. The preview keeps its rounded frame; the transport stays where it is today.
6. **Legibility of the rest.** The strip, the lists, the inspector and the forms keep their structure and logic. Replace their system colours with token colours only where it is a mechanical swap (text, secondary text, panel backgrounds, selected row), and leave everything else for DS2 and DS3. Raise any text style below 11 pt to the small style; say what moved.
7. **Nothing else changes.** No new feature, no new setting, no behaviour change, no change to the Build, the skill or the shared tools.

## Tests

The contrast tests and the token tests (every token is used by Theme.swift; no size below 11; radii and spacing are on the scales); the source guard; the existing tests all still pass. Add a test that the rail has one entry per centre view that the top bar offered before, and that each entry reaches the same view and keeps its availability reason (use the existing model of the centre pane, not the screen). Update any test that referenced the top bar buttons and say which.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE tools/bump_app.py (a minor version); never edit a version by hand. Update docs/ux-notes.md ("Built in DS1 (date)": what was built, what remains for DS2 and DS3, the allow-list count), ROADMAP.md and CLAUDE.md "Open work".

## Verification

During the work: tools/verify.sh --fast. At the end: the complete tools/verify.sh, then tools/rebuild-app.sh.

## Final report (docs/phases/DS1/report.md)

Step 0 results, what was built point by point, every token that had to change to pass a contrast test and why, what the source guard still allows (counts), what the rail does with each old button, the version, what is verified and what is not (no screen: nothing drawn is verified, say so plainly), and "To check by hand": the whole window on a laptop screen (are the panels and the rail readable, is anything cut or clipped), each rail entry reaching its view, the segmented tabs, a toggle, a primary and a secondary button, a disabled control and its reason, the strip and the lists on the dark canvas (anything unreadable or still light), the Settings window, the colours of the six Status icons on the panel surface, and the keyboard (Tab and arrows) and VoiceOver on the rail. Stop after the phase.
