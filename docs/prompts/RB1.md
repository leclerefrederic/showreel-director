# Phase RB1: the behaviour of the rail's buttons (audit first, then make it consistent)

Read CLAUDE.md, then docs/ux-notes.md (the entries "Rail", "Sizes and reset", "Same slide-in for the Project panel", "Motion: the interface answers" and the UI principle), docs/rl1-report.md, docs/ds2-report.md, docs/batchA-report.md, and the code: the rail (RL1: its two groups, the centre views Film and Build, the right panels Inspector, Look, Project, Clap), `ShellLayout`, the selection model (`project.selection`), the shared operation that opens the Project panel, the Clap pulse and proposals badge, Shift-Cmd-A, `Availability`, `disabledWithReason`, the Motion file. Follow every rule of CLAUDE.md (never run git, English interface, skill untouched, no out-of-scope work: an idea goes in docs/ideas.md in one line). Views stay free of business logic: the rules live in ShowreelKit with tests. The owner waived the open questions of docs/ideas.md for the redesign.

The owner's remark: "the behaviour of the buttons of the left bar must be reviewed". He has not said what is wrong, so this phase **starts with an audit** and fixes only what is a clear inconsistency or breaks the UI principle (every action gets a visible reaction; nothing silently disabled). Anything that is a taste choice is listed in the report as a question for the owner, not decided by you.

## Step 0 (read-only, the top of docs/rb1-report.md)

A table, one row per rail button (Film, Build, Inspector, Look, Project, Clap), with: group; what a click does when its view or panel is closed; when it is already open; when another right panel is open; whether a centre view change touches the right panel and the reverse; the keyboard shortcut (if any) and whether the tooltip shows it; the visible states (selected, hover, pressed, focus ring, badge, pulse); the tooltip text; when it is unavailable and whether a reason is shown; the animation used; the accessibility label, role and selected state; what is restored at launch and what is stored.

Then a list of inconsistencies found between the rows (for example a button that toggles closed while another does not, a state with no visible mark, a shortcut with no tooltip, a panel that opens without a reaction, a selection that does not match what is shown, the Project panel reached by three paths that do not agree, the Inspector with nothing selected).

## What to build

1. **One rail behaviour rule in ShowreelKit (pure, with tests).** Express the rows of step 0 as a rule: which buttons are exclusive in their group, what a click on the active one does (state the rule you apply: by default the centre views never toggle off, and a right panel closes when its open button is clicked again), what happens when a button is unavailable (`disabledWithReason`: the reason and the way back, in the tooltip and to VoiceOver), and the order for the keyboard. The views only call it.
2. **Fix only the inconsistencies of step 0 that are clear defects**, by that rule, and list each fix in the report (before, after). Give every button the same set of visible states (hover, pressed, focus ring, selected, badge where it applies), from the tokens, with the motion tokens for the state change and a static change under Reduce Motion.
3. **Keyboard and accessibility:** every button reachable by Tab, arrow keys move inside a group, Space or Return activates, a tooltip with the standard delay shows the name and the shortcut, each button has an accessibility label and announces its selected state. Do not add new shortcuts beyond the ones that exist, except where a missing one is an obvious gap: list it as a question instead.
4. **Selection and panels agree:** what the rail shows as selected is always what is on screen; no state where a button looks active and its panel is hidden, or the reverse (also after Reset, after a layout change, at launch and when a build starts). Add a test for each of these cases.
5. **Nothing else:** no new button, no restyle, no change to the top bar, the strip, the Storyboard list, the inspector, the Build or the skill.

## Tests (no screen)

Every row of the behaviour rule (click closed, open, with another panel open, centre view change, unavailable with reason, keyboard order and wrap); selected state equals the visible view after each of: launch, Reset, layout toggle, build start, selecting a scene or a transition, opening Project from the three paths; the tooltips contain name and shortcut; the accessibility labels exist for all six. Update the tests that assumed the old behaviour and say which.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE tools/bump_app.py (a minor or patch version, your call, say why); never edit a version by hand. Update docs/ux-notes.md ("Built in RB1 (date)" and what remains), ROADMAP.md and CLAUDE.md "Open work".

## Verification

During the work: tools/verify.sh --fast. At the end: the complete tools/verify.sh, then tools/rebuild-app.sh.

## Final report (docs/rb1-report.md)

The step 0 table and the inconsistencies, what was fixed (before, after), the questions left for the owner (taste choices and missing shortcuts), the version, what is verified and what is not (no screen: nothing drawn or animated is verified, say so plainly), and "To check by hand": click each button closed, open and with another panel open; Tab and arrow keys through the rail; hover and tooltips with shortcuts; Reduce Motion; Reset and the layout button, then check the rail still matches what is on screen; launch the app again and check the same; start a build and check the rail. Stop after the phase.
