---
type: phase-report
status: current
phase: 
date: 2026-11-09
summary: "Report of the batch that ran F2 (fonts from Google Fonts without the GitHub API) and T2 (thumbnails, music markers, Transitions tab)."
tags:
  - report
  - archive
---

# Batch 2 report

Backup: `/Users/fleclere/Library/Application Support/ShowreelStudio/backups/batch2-20261109-141526` (app-swift, showreel-director, docs and tools before the batch).

## F2: fonts downloaded from Google Fonts, without the GitHub API: DONE

**Step 0, what the real network says** (a dozen requests in all, none to the GitHub API; run from a Swift test and a Python script on the owner's network):

| Source | Observed | Verdict |
|---|---|---|
| (a) `fonts.google.com/download/list?family=Anton` | HTTP 200, JSON (`)]}'` prefix) with the licence text inline and, for each file, an address on `fonts.gstatic.com` | works with no key; for a variable family it lists static instances under names the repository does not have (and optical-size variants such as `Inter_18pt`, whose font-file family is not "Inter") |
| (a') `fonts.google.com/download?family=Anton` | HTTP 200 but an HTML page (the web app) | not usable |
| (b) `fonts.googleapis.com/css2?family=Anton:wght@400` | HTTP 200, CSS with `fonts.gstatic.com` addresses to .ttf (script user agent) | works, but gives no licence text and no file names |
| (c) `raw.githubusercontent.com/google/fonts/main/ofl/anton/Anton-Regular.ttf`, `OFL.txt`, Poppins Regular and Bold | HTTP 200/206, real .ttf (header 00010000), exact sizes, licence text | works with no key, no account |

**Choice.** Primary: (c), the files of the open repository by their path, which gives exact sizes, the licence and variable files. Fallback: (a), Google Fonts' own download list then `fonts.gstatic.com`, for the few files the repository holds under another name. (b) was not used. No key or token is in the app.

**Done.**
- `engine/fonts-free.json` (70 fonts) now lists for each font: `files` (name, weight, size, `variable`, `list`), `licenseFile`, `license`, `tree`, `specimen`. 32 fonts are one variable file, 5 go through the download list. Two fonts (Satisfy, Syncopate) are under `apache/` in the repository, not `ofl/`: the list says so and their licence is Apache 2.0 (the old code looked them up under `ofl/`, which could never have worked).
- `tools/refresh_font_manifest.py` (maintainer script, no key, never the GitHub API, about 4 requests per font) made that data. I ran it three times while building it (about a thousand light requests to raw.githubusercontent.com and fonts.google.com in all): more than the "very few calls" asked for the *evaluation*, but it is the deliverable, and no GitHub API was involved.
- The "Add font files" card and the card before a Build are built from the manifest with no network (`FontFiles.offer(_:store:)` has no source any more; `FontsAtBuild.prepare` is synchronous). Source line: "Google Fonts (the open google/fonts repository), from the skill's fixed list"; the licence is the font's own.
- Download: every file is fetched and checked (present, not empty, looks like a font, exact size from the repository) before anything is written; the operation removes what it wrote if a write fails; the whole build-time download is one undo step.
- A single-weight family (Anton) serves titles asked at 700 with its 400 file (`FontFiles.effectiveWeight`), otherwise it would have stayed on "Needs files" for ever.
- Errors: 403 and 429 (call limit) say so with the code and address; 404, 5xx and network off have their own message; "Try again" and the manual way remain.
- `fetch_font.py` (skill) no longer uses the API either. Skill **0.17.0**; app **0.8.5**.

**Verified.** `tools/verify.sh` complete: OK. `swift test` twice: 521 tests, 1 skipped (the network test), 0 failures both times (75 s and 74 s). The optional network test (`SHOWREEL_NETWORK_TESTS=1`) downloaded Anton and Poppins through the real source: files with the manifest's exact sizes, parsed as fonts, licence text, embedded state, undo. New tests without network: card built with no source; plans for Anton, Poppins (two weights, bold only), a variable family and an Apache family; every one of the 70 fonts has files, sizes and a licence; a failure on download 1, 2 or 3 leaves nothing; an empty file is refused; a write that fails in the operation leaves nothing; 403/404/429/5xx/network off with a stubbed session; the fallback; a wrong size, an empty file and an HTML page refused; the GitHub API is never called.

**Not verified.** The cards and the alert on screen. The corporate network of another machine. The manifest of the 66 fonts that were not refreshed in the last run carry defaults for `tree` and `license` (ofl, SIL OFL) that match what the earlier runs found.

**Deviations.** More requests than "very few" while building the manifest (see above). `FontsAtBuild.lookupProblem` is gone (nothing is looked up). The batch's other phase follows.

**To check by hand (F2).**
1. In the Look, choose Poppins for the titles: "Add the font files" shows the card at once, even with the network off: source Google Fonts, licence SIL OFL, two files, a size.
2. Accept it: the files arrive; the state turns to Embedded; Undo removes them.
3. Choose Anton: accepted for titles; Embedded.
4. Choose Satisfy: the card says Apache License 2.0.
5. Start a Build with a font without files: the same card with three choices.
6. With the network off, accept a card: the message gives the cause, "Try again" and the font's page.

## T2: thumbnails, music markers and the Transitions tab: DONE

**Step 0, what the code did.**
- *Thumbnails after C1:* `FrameLayout.elements` gives `thumbTiles` 1 always, at the 16:9 shape of the lane's height (`thumbWidth`); the frame draws one `SceneThumb` and the rest of a long frame is the frame's background. Nothing was left to fix in the rule; a test now pins it over a grid of sizes. Not "centred crop to the whole frame": a long frame shows one 16:9 thumbnail at its left, not stretched (stretching would deform or crop heavily); say if you prefer it filled.
- *beats.json* holds the beats, the bars, the bar energy, the indices of the drops, the breakdowns (breaks with a return) and the intro flag. The ruler already numbered the bars and ticked the beats; the lane drew bar lines, the strongest drop and "break" labels. Sections in the analysis are only breaks and their returns (no names such as "Verse"), so the names are "Break" and "Return".
- *Transition markers:* a diamond on the cut (\`TransitionMarker\`, with \`MarkerLayout\`), a click calls \`selectTransition(from:)\`, which selects \`.transition(id)\` and the inspector (\`TransitionInspector\`) opens.
- *Catalogue:* \`Catalogue.choices(.transition)\` with the six preview-only ones \`selectable: false\` and a reason; the operation refuses them.
- *Left tab:* \`LibraryTab\` (resources, scenes, checks) in \`LibraryPane\`.
- *Drag since D3:* plain-text token only, \`DragRun\` ends it, \`drag.log\`. I found the same defect as in D2 in two more places: the rows of the look's catalogues (\`LibraryRow\`, a Button) and the chips of the scenes that are off (a Button): neither could start a drag. Both now use the non-button \`DragRow\` / a plain chip, which is what the new catalogue of transitions uses too.

**Done.** \`MusicGrid\` (ShowreelKit: which lines at which zoom and level, never closer than 12 pt, the lane's marks, the label text, the segments that avoid labels and markers), \`TransitionList\`, \`StudioSettings.gridVisible\`; the grid overlay on the frames, the lane's beat ticks, bar numbers, section names and drops (with tooltip), the snap guide and label while an edge or a cut is dragged, the Grid button, Analyse the track, the Transitions tab with its catalogue; \`DragRow\`. App **0.9.0** (skill unchanged: 0.17.0).

**Verified.** \`tools/verify.sh\` complete: OK. \`swift test\` twice: 534 tests, 1 skipped (the network test), 0 failures both times (77 s each). 13 new tests (T2Tests): one thumbnail whatever the size; no two grid lines closer than 12 pt at 12 zoom levels and 5 snap levels; the kinds per level and which give way; positions read from a beats.json; legible lane marks; no track, no analysis, grid hidden or snap off: nothing; the grid choice remembered in ui.json; the label ("Bar 5, beat 1, 0:08.0", "Drop", "Break", plain time off-grid); no line across a label, a duration, a state or a marker; the list (pairs, "Cut", type and duration, marks, off scenes, empty); the click selecting a marker that exists; the six preview ones refused with their reason and a good one dropped; frozen during a build, editable between locked scenes; the drag ends clean.

**Not verified.** Everything drawn: no screen. In particular the look of the grid lines (opacity, weight), the lane's labels at small sizes, the drag from the catalogue and the drop on markers and on the new rows (compiled and logic tested; the drag log will tell if a drag does not start), the Delete/tab behaviours. The file \`app-swift/Sources/ShowreelStudio/TimelineViews.swift\` changed a lot: if the strip looks wrong, that is where.

**Deviations.** The frame's own drag label (a timecode chip inside the frame) was replaced by the guide line and label of the whole strip (a chip inside a narrow frame would clip). The grid on the frames is a thin overlay on top of the thumbnails (a grid behind opaque frames would never show). No spring-loaded tab for the new tab.

**To check by hand (T2).**
1. Attach an analysed track: lines appear on the frames; change the snap level (Beat, Bar, Section, Drop, Off): the grid follows; Off removes it. Zoom out: beats drop out first, bars stay, no crowding. Bars are stronger than beats, the drops red, the sections orange.
2. Hover the S01 label, its duration and a transition diamond: no line crosses them.
3. The music lane: beat ticks, bar numbers, "Break" and "Return", "Drop" (the strongest says "Strongest drop"); hover a drop: "Drop at 0:xx.x".
4. Drag the right edge of a scene with snapping: a bright line and a label "Bar 5, beat 1, 0:12.4"; hold Option: no snap, plain time.
5. The Grid button hides and shows the grid; reopen the project: its state is kept. Without a track it is greyed with the reason.
6. Attach a track whose analysis failed (or remove analysis/beats.json): "Analyse the track" appears with the reason, and nothing analyses on its own.
7. Transitions tab: a row per pair; click one: the marker is selected on the reel and its inspector opens; drag a transition of the catalogue onto a marker and onto a row: a line at the bottom with Undo; drag one of the six "preview only": refused with the reason; during a Build everything is refused with the reason.
8. Switch a scene off with Delete, then drag its chip back from under the strip into the frames.
9. A long frame shows one thumbnail, not repeated.

## End of the batch

- **Phases:** F2 done, T2 done. None failed, nothing restored from the backup.
- **Versions published:** skill **0.17.0** (F2), app **0.8.5** (F2) and **0.9.0** (T2).
- **Final checks:** \`tools/verify.sh\` complete: OK after each phase and at the end; \`swift test\` twice in a row after each phase (F2: 521 tests; T2: 534; 1 skipped, the optional network test), 0 failures, no unstable test. One \`tools/rebuild-app.sh\` at the end: SELFTEST OK, BUNDLE OK (standalone), app running (pid 32268); the earlier app was closed.
- **Durations (about):** F2 about 55 min of work (about 20 min of it reading, network exploration and the manifest; the rest the Swift rewrite and its tests), tests 75 s each; T2 about 35 min, tests 77 s each; rebuild about 1 min.
- **Deviations from the prompt:** see each phase (more requests than "very few" to build the font manifest, once, with no GitHub API; the frame's drag label replaced by the strip's guide; the grid is an overlay above the thumbnails; fixes to two more drag sources that were buttons).
- **Backup:** see the top of this file.
