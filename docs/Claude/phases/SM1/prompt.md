---
type: phase-prompt
status: current
phase: SM1
date: 2026-11-10
summary: "Removes the Film up to date dot and Go given button (all scenes Ready is the go), the Look rail entry and the empty inspector's Project settings button."
tags:
  - prompt
---

# Phase SM1: fewer controls, same behaviour

Read CLAUDE.md first and follow every rule (never run git, English interface, answer the owner in French and short, no screen so say what was not seen, no out-of-scope work: an idea goes in a note created with `python3 tools/docs_new.py idea`). Use `graphify query` before reading files. Views stay free of business logic: rules live in ShowreelKit with tests. The owner waived the open questions for the redesign. **Change only what is listed here**, keep every other behaviour.

The owner's words (screenshots of the Film toolbar, the empty inspector, the rail and the top bar): "I need neither the Film up to date information nor the Go given button. If all the scenes are validated we can build the film: that is the implicit go." "Remove the project settings from the inspector." "Look is part of the project. Why have it here as well?" "The Catalogue in the top bar brings nothing: it offers no functionality."

Read docs/Claude/ux-notes.md (entries on the Film toolbar, the rail, "Same slide-in for the Project panel"), the UI2, RL1, RB1, FT1 and MT1 reports, and the code: the Film toolbar's status dot and the Go control (TimelineViews.swift and what it calls), the Go gate and its stored state (`Availability`, the Build button, `showreel.json`), the rail (RL1, RB1's behaviour rule), the Project panel and its tabs, the inspector's empty state (InspectorViews.swift), and everything that opens the Look panel.

## Step 0 (read-only, 10 lines at the top of the report)

a) What the "Film up to date" indicator and the "Go given" control are bound to: the film state, the stored go (where it is written in `showreel.json`, who reads it: the Build button, the Build, Clap's tools, the skill's gate, `capabilities.json`, `references/portability.md`), and what the Build button needs to be enabled today.
b) Whether the skill treats the go as a gate the app must record (SKILL.md gates, `process.json`). The skill stays untouched: if the file needs the value, the app writes it implicitly (see 1).
c) Everything that opens the Look right panel (the rail entry, links in forms, drops of fonts, Clap's proposals, shortcuts) and how the Project panel's tabs are selected and stored.
d) The inspector's empty state: what it shows, its Project settings button, and the other places the Project button appears (scene, transition, resource and look item inspectors).
e) The Catalogue control of the top bar (the four-squares icon next to the layout button): what it opens, whether anything in it can be acted on (apply, add, drag, copy) or it is read-only, who else reads the same view or data (Clap, the Wizard, pickers, menus, shortcuts, tests).

## What to build

1. **Remove the "Film up to date" indicator and the "Go given" button** from the Film toolbar. The rule becomes pure and tested in ShowreelKit: **the Build is available when every visible scene is Ready** (the rule that exists today, with locked scenes counted as Ready for this purpose only if that is how it works now: do not change it), and that is the implicit go. When the owner starts a Build, the app records the go in the file exactly as the old button did, if step 0 b says the file needs it, so the skill, the file format and Clap's tools keep working unchanged. A Build button that cannot start still says why and how (`disabledWithReason`, for example "2 scenes are not Ready"). Remove the dead code of the two controls, keep the film state model if anything else reads it (the Build's incremental reuse, the thumbnails), and list what you removed and what stayed. Never leave a way to start a Build without every visible scene Ready, and never silently.
2. **Remove the Look entry from the rail.** Look is a tab of the Project panel (the Project and Look tabs of the settings pane): everything that opened the Look panel (step 0 c) now opens the Project panel on its Look tab, through the one shared operation that opens Project. The stored tab is restored. The rail keeps Film, Build, Inspector, Project and Clap. Update RB1's behaviour rule, its tests and the tooltips and shortcuts that named Look (if Look had a shortcut, give it to the Project panel's Look tab and say so).
3. **Empty inspector: remove the "Project settings" button** (and the project title block above it if it only served that button; keep the line that tells the owner to select a scene, a resource or a transition). The Project button of the scene, transition, resource and look item inspectors stays as the owner asked earlier: say in the report that it is now the only link from an inspector to the Project panel, and put it as a question for the owner (one line) whether he still wants it now that the rail has Project.
4. **Remove the Catalogue control from the top bar** if step 0 e confirms that it offers no action (the owner's judgement). Remove its view, menu item and shortcut if nothing else uses them; keep any data, model or view that another feature reads (list what stayed and why). If you find an action in it that the owner may not know about, keep the control, say so in the report and put it as a question. The other top bar controls (Checks badge, layout button, reset) do not move.
5. **Nothing else:** no change to the Build itself, the skill, the strip drawing, the other toolbar controls, the Storyboard list, Clap.

## Tests (no screen)

The Build availability rule (all visible scenes Ready, a hidden scene not counted, a scene not Ready named in the reason, locked scenes as today); starting a Build records the go as before and a Build cannot start otherwise; the rail has exactly five entries and none is Look; the top bar has no Catalogue control and its other controls are unchanged; every former path to the Look panel lands on Project with the Look tab selected; the stored tab is restored; the empty inspector has no Project button; opening and closing panels keeps the rail and the screen in agreement (RB1's cases). Update the tests that assumed the Go control, the indicator or the Look rail entry and say which.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE `python3 tools/bump_app.py` (a patch version; a minor one only if you can say why); never edit a version by hand. If `capabilities.json` or `references/portability.md` described the Go button or the Look panel as something the interface does, correct the app's row; if the portability table must change, that is a skill change (release notes of the skill first, `python3 tools/bump.py patch`). Update docs/Claude/ux-notes.md ("Built in SM1 (date)" and what remains), CLAUDE.md "Open work", then `python3 tools/docs_index.py --write`.

## Verification

During the work: `tools/verify.sh --fast`. At the end: the complete `tools/verify.sh`, then `tools/rebuild-app.sh`.

## Final report (docs/Claude/phases/SM1/report.md)

Step 0 results, what was removed and what stayed (and why), the version, what is verified and what is not (no screen: nothing drawn or felt is verified, say so plainly), the question about the Project buttons, and "To check by hand": the Film toolbar without the dot and the Go button; a project with a scene not Ready (Build disabled with its reason) then all Ready (Build enabled, a Build starts); an older project that had the Go given or not given; the rail with five entries; every way to the Look tab (a font link, a Clap proposal, the old shortcut) opening Project on Look; the top bar without the Catalogue icon and nothing else moved; the empty inspector without the button and the scene inspector's Project button still opening the Project panel. Stop after the phase.
