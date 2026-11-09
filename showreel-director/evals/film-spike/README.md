# Film layer spike (W3a)

A three-scene test film for `engine/film.js`: one render module per scene, a Push from the first scene to the second and an Iris from the second to the third.
Plain test colours and no wording of any look: it only proves the mechanics. `tools/check.py` builds it, runs the harness and the player test on it, and
`scripts/test_film.js` checks that a transition draws both scenes at once and that the output is the same on every run.
Build it by hand: `python3 scripts/build.py evals/film-spike/v1`, then `node scripts/harness.js evals/film-spike/v1/dist/index.html`.

`v1` writes the montage in main.js (`SRF.film`); `v2` takes it from `film.json` (`SRF.fromData`), the way the app's Build works; `v3` is the scene-file format: `film.json`, `scenes/S01.js` to `S03.js` and `reel.js`, with no `main.js` (`scripts/assemble.py` makes it, `build.py` runs it) and the same three scenes as `v2`, so that it draws the same pixels. `scripts/test_assemble.py` tests the assembler on it.
