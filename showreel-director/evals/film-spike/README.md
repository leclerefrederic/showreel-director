# Film layer spike (W3a)

A three-scene test film for `engine/film.js`: one render module per scene, a Push from the first scene to the second and an Iris from the second to the third.
Plain test colours and no wording of any look: it only proves the mechanics. `tools/check.py` builds it, runs the harness and the player test on it, and
`scripts/test_film.js` checks that a transition draws both scenes at once and that the output is the same on every run.
Build it by hand: `python3 scripts/build.py evals/film-spike/v1`, then `node scripts/harness.js evals/film-spike/v1/dist/index.html`.
