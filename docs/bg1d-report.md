# BG1d: a Build writes only the scenes that changed

## Step 0 (read only)

**a) Before.** `BuildJob.plan` looked only inside the new version folder, which is empty: every scene was "not generated", so every unlocked scene was written, one request each (up to date or not). A locked scene was copied from an earlier version (that part was right). A hand-edited scene: not looked at (the new folder has no file). `Generate` on an existing version regenerates only the stale scenes and asks before overwriting an edit.

**b) The previous version as the place to take a file from.** Yes, if the file and its record are there and trusted. The record (`.studio/build.json`) holds the fingerprint of the inputs and of the file per version and scene, so the plan can ask "is this scene up to date in v4?" for each earlier version, newest first, and copy the file and the record. The fingerprint (`SceneModules.inputs`) covers the scene's content, words, control level, length and its effective look (its own override or the project's palette, fonts, background, moods, effects pack). A global look change therefore makes stale exactly the scenes that inherit it. It did not cover the brief (audience, message, tone), the music under a scene, the contract or the skill version.

**c) Contract and skill version in the fingerprint: no, they are said, not forced.** A scene written under an older contract is not wrong: since BG1c each scene passed its own test before being kept. Forcing a rewrite on every contract change would cost 15 requests for a changed comment, and the skill's version moves for reasons unrelated to scenes (the harness, the docs). So each record keeps the contract fingerprint; when reused scenes were written under another one the card says "N reused scenes were written under an older contract" and "Rewrite everything" applies it. Not in the fingerprint, but also recorded: the brief and the music under the scene, taken relative to its start (a scene that only moves by a whole bar is not out of date), so that a change of the brief, the tempo, a drop or a break that touches a scene makes it out of date. Records written before this have none of these and are never made stale by them.

## What was done

- `SceneModules`: records now carry `context` (brief and music), `contract` and `tested`; `status` counts a change of context; `reusable` (up to date, not edited by hand, tested or in a version whose test was green); `carryOver` copies a file with its record; the frame has its own fingerprint per version.
- `BuildJob.plan`: locked scenes are reused; scenes up to date and tested in an earlier version are reused; written: stale, never written, failed its test; hand-edited and out of date: reused as they are unless ticked; `force` writes every unlocked scene and the frame. The frame is reused when what it was written from is unchanged. Each scene has its reason.
- `BuildJob.run`: copies what is reused (a journal line each: "S03 reused from v4"), writes the rest ("S05 written"), marks a scene tested when its own test is clean, keeps "Rewrite everything" and the ticked edits in the marker so that a Build that continues stays what it was asked.
- The card: "Build v6: 1 scene will be written, 14 reused unchanged (2 locked)", calls, cost and about one minute per call for the written scenes only; "Nothing changed since the last build" with only Assemble when nothing is to write; the hand-edited scenes with a tick; "Rewrite everything…" with its own confirmation and its request count; the note about an older contract.
- `addendum.md`, release notes (app 0.10.2), ROADMAP. The skill is untouched.

## Verified, not verified

- Verified: `tools/verify.sh --fast` during the work, the complete one and the rebuild. 11 new tests (BG1dTests): nothing changed means no request and the same bytes, one changed scene is the only one written (and the next plan is clean), never written or failed test, hand-edited with and without the tick, a locked scene, Rewrite everything (and a continued one), a look change that touches only the scenes that inherit it, the brief, an older contract (said, not forced), the film assembled to the same bytes with or without reuse (real assembler).
- Not verified: any real model call (no paid call), the real time of a Build with one changed scene, the look of the card (no screen). The very first Build after this update writes the frame again (no record in older versions).

## To check by hand

1. Change a word in one scene of the trailer, press "Build a new version": the card should say 1 scene written and 14 reused; confirm: the Build should take about a minute.
2. Press the button again with nothing changed: "Nothing changed since the last build", only Assemble.
3. Try "Rewrite everything": its own confirmation with the 16 requests.
