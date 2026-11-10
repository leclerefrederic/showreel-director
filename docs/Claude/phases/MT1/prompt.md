---
type: phase-prompt
status: current
phase: MT1
date: 2026-11-10
summary: "Music lane toolbar: Beat, Bars, Sections, Drop and Analyse buttons, with the track name and BPM; the Beat menu leaves the Film toolbar."
tags:
  - prompt
---

# Phase MT1: the music lane gets its own toolbar

Read CLAUDE.md first and follow every rule (never run git, English interface, skill untouched, answer the owner in French and short, no screen so say what was not seen, no out-of-scope work: an idea goes in a note created with `python3 tools/docs_new.py idea`). Use `graphify query` before reading files. Views stay free of business logic: rules live in ShowreelKit with tests. The owner waived the open questions for the redesign. The owner loves the look of the app today: **change only what is listed here** and keep every behaviour; where a colour has no token, add a token with that value, no new colour literal.

Read docs/Claude/ux-notes.md (the entries on music and the Film strip), the music-related phase reports (find them with `graphify query`), `showreel-director/references` for what the music analysis produces (read only: the skill stays untouched), and the code of the music lane (the waveform, the beat and bar grid, the markers, the Beat menu of the Film toolbar and what it changes, snapping, the analysis call and its result file).

## Step 0 (read-only, 10 lines at the top of the report)

a) What the Beat menu offers today, entry by entry, and what each entry changes (grid display, snapping, marker kinds), and where that state is stored.
b) What the music analysis returns today: beats, bars, tempo (BPM), sections, drops or accents. For each of the five buttons below say whether the data exists; if sections or drops do not, say so plainly.
c) How the music lane is laid out (its header, its height, how it follows the zoom) and where a toolbar fits.
d) How a re-analysis is started today, how long it takes, what it shows while running, and what a Build in progress does to it.

## What to build

1. **A toolbar for the music lane** (a slim bar on the lane's header, same height and button style as the Film toolbar, tokens only) with five buttons and the track information:
   - **Beat**: shows or hides the beat lines (the grid the Beat menu offered). A toggle with its selected state.
   - **Bars**: shows or hides the bar lines. A toggle.
   - **Sections**: colours the portions of the waveform by musical section, with a small palette from the tokens and the section name on hover. A toggle.
   - **Drop**: shows or hides markers on the drops and key accents. A toggle.
   - **Analyse**: runs the analysis of the track again. An action with a visible reaction (running state with a progress mark, then done or failed with the reason), the track kept as it is until the new result is written.
   - **Track name and BPM** shown at the end of the bar (the name truncated with the full name in the tooltip).
2. **Availability, never silent.** A button whose data does not exist (step 0 b) is disabled through `disabledWithReason`: it says why and how to get it ("Run Analyse to find sections"). With no music track, every button says so. Analyse is disabled during a Build with that reason. Do not extend the analysis in this phase, and do not touch the skill: if sections or drops are missing from the analysis, the buttons stay disabled with their reason and one idea note records the gap.
3. **The Beat menu leaves the Film toolbar.** Every function it had must keep a home: the grid choices become the Beat and Bars toggles; if the menu also set snapping or another mode, keep that function in the music toolbar as part of Beat or Bars (state the rule you chose, for example snapping follows the visible grid) or, if you cannot place it without a new control, leave it in the Film toolbar and list it as a question for the owner. Nothing is lost silently. The grid button and the fit button of the Film toolbar stay.
4. **State:** the toggles are view state stored with the other layout settings (restored at launch, independent of the project's content). Their rules (what each toggle shows, what is available, the stored defaults, the snapping rule) are a pure `MusicToolbar` model in ShowreelKit with tests.
5. **Nothing else:** no new analysis, no change to the skill, the Build, the strip frames (FL1), or the Storyboard list.

## Tests (no screen)

Each toggle's visible state and its stored value; availability for every case (no track, data missing, Build running, analysis running, analysis failed) with the reason; Analyse keeps the old result until the new one is written and keeps it on failure; the grid shown by Beat and Bars equals what the old menu showed for the same settings; snapping behaves as the rule you stated; a source guard for colour literals. Update the tests that referenced the Beat menu and say which.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE `python3 tools/bump_app.py` (a patch version unless you can say why it is minor); never edit a version by hand. Update docs/Claude/ux-notes.md ("Built in MT1 (date)" and what remains), ROADMAP.md if a limit is lifted, CLAUDE.md "Open work", then `python3 tools/docs_index.py --write`.

## Verification

During the work: `tools/verify.sh --fast`. At the end: the complete `tools/verify.sh`, then `tools/rebuild-app.sh`.

## Final report (docs/Claude/phases/MT1/report.md)

Step 0 results, what was built point by point, deviations, the version, what is verified and what is not (no screen: nothing drawn, animated or felt is verified, say so plainly), and "To check by hand": each of the five buttons on a track that has all the data and on one that lacks sections or drops (disabled with its reason); the track name and BPM; Analyse running, finishing and failing, and during a Build; snapping after the Beat menu is gone; the toggles restored after quitting and reopening; a project with no music. Stop after the phase.
