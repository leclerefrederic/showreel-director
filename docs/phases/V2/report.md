---
type: phase-report
status: current
phase: V2
date: 2026-11-09
summary: "Report of V2: the state of the build and of the reader."
ux:
  - "[[ux/Library, Scenes tab]]"
tags:
  - report
---
# V2 report: state of the build and the reader

## Constats (step 0)

- Q5 is in the code: `Availability`, `Unavailable`, `Reasons`, `ProjectActivity`, `CloseGuard`, `StatusLine`, `BuildProgress` (ShowreelKit), `disabledWithReason`, `BuildProgressPanel`, `cancelBuild`, the closing alert (the app). V2 builds on them.
- **Free instruction of a transition.** It is written in `film.json` and quoted in text in the build message and in `SceneGeneration.prompt` (through `Transition.text`), so a generation reads it for both neighbouring scenes. The engine (`film.js`) ignores it: the assembly alone never applies it. Nothing recorded which instruction a generation had used, so V2 records a fingerprint of each scene's passages at generation (`.studio/build.json`, `passage`); the transition is "instruction pending: used at the next generation of S02 and S03" until both scenes were generated with it, then "instruction used at the last generation"; in the old format "instruction not applied yet". No new generation mechanism.
- **Version read.** Before V2: `playVersion` (the last build that built, even with red checks), else the last folder if it had a `dist/`. With a stopped build's folder (no `dist/`) last, nothing played even when `v2` was fine, and the picker listed the partial folder. No test result was kept per version.

## What V2 does

- `FilmBuild.status` (ShowreelKit): the state of the film (old format, never assembled, up to date, stale, with the reasons) and of each scene, computed from fingerprints kept in `.studio/build.json` (inputs of each scene, the file's hash, the film's parts: montage, music, each scene's inputs and file, and the result of the last test per version). Nothing is stored by hand.
- What makes what stale (tested line by line): order, transition, transition length, music: the film only. Content, scene length, scene look: that scene and the film. A global look change: every scene without its own look, and the film. A review state change: nothing. A scene file written again: the film (it holds the old file), not the scene.
- `Versions.working`: the last version built and tested green. A folder with no page, or a version whose last test was red, is never read; `Versions.incomplete` lists what a stopped build left, and the reader says "Version vN is incomplete (the build was stopped). Build again, or generate the missing scenes."
- `FilmAssembly.run` (no AI): film.json from the montage, the assembler, build.py and the engine's checks on a copy `vN.assembling`; only a green result replaces film.json, main.js, assembly.json and dist in the version. A failure shows the engine's error and leaves the version as it was. Scenes with no file are empty frames: it succeeds, the film is not `ok`. The project is read-only while it runs (the build's freeze, panel and Cancel). `assemble_film` for Clap: free, no card, a line in the journal.
- Generation: `SceneGeneration` only. It now also freezes the project while it runs, with the panel (scene n of N), Cancel and the end of Q5. One card for N scenes: the files, the number of calls, an estimated cost (tokens in, up to 3000 out per scene). Locked scenes are left out of the offer with their reason.
- Player: Play plays only the assembled film. Nothing assembled: Play is disabled with the reason and the banner has Assemble. Stale: Play assembles first ("Assembling..."), nothing runs in the background while editing. Banners: stale since (with Assemble), scenes not generated (with the one card), old format, incomplete version, a failed assembly with the engine's error. Thumbnails are tagged "Preview". Reel header counter and a build mark on each scene (list, reel, tree, inspector), square and distinct from the round review badge. Old format: the film plays as it is, no scene state, one sentence says why.
- Transitions: the six preview-only ones are "approximate render at assembly" in the reel (marker icon and tooltip), the inspector and the preview; free instructions as above.

## Not done / limits

- The release notes tooling of lot R (`tools/bump_app.py`, `RELEASE-NOTES-SKILL.md`, `RELEASE-NOTES-APP.md`) does not exist in the repository: I wrote no release notes and ran only `tools/bump.py` (the skill's portability table changed).
- The offer to generate lists the scenes with no file only; stale scenes are regenerated through Clap's `generate_scenes` or one by one later (idea noted).
- The "Clap proposes" and "Locked during build" marks are still absent from the reel's frames, the resource rows and the scene tree (not built here, noted).
- Nothing was seen on screen.

## What to look at by hand

1. A project that was never assembled (new, or migrated): the Play button of the strip is disabled, its tooltip gives the reason and the way; the viewer shows a banner "The film has not been assembled yet" with Assemble.
2. Assemble: the panel "Assembling and testing" appears, the project is read-only, then the line "Film assembled: N scenes, N transitions" (and which scenes are not generated). The page then plays.
3. Scenes with no file: the film plays with empty frames carrying their IDs; the banner says "S03 and S05 are not generated: shown as empty frames" with "Generate N scenes"; the card lists the files, the number of calls and the estimate; a locked scene is named as left out with its reason; nothing is asked of the AI before the yes.
4. Change a transition or the order: the counter becomes "Film stale", the banner says what changed, no scene mark turns orange; press Play: "Assembling..." then it plays. Change a scene's text: that scene's mark turns orange (stale) and so does the film.
5. The marks: not generated (dashed square), generated (green tick), stale (orange arrows), edited by hand (pencil, after you edit a scene file), in the library list, the storyboard list, the reel's frames (bottom right), the tree and the inspector header; they are square, the review badge is round.
6. The old format (a version with only a hand-written main.js): the counter says "Old format", no scene mark, one sentence explains, the film plays, Assemble and Generate say why they are unavailable.
7. After a cancelled build: the folder `vN` is flagged "incomplete (the build was stopped)", the reader keeps playing the last good version, the picker lists only versions with a page.
8. A transition of a preview-only kind (an old project) and a transition with a free instruction: the marker has a small orange dot, the tooltip and the inspector say "approximate render at assembly" and "instruction pending: used at the next generation of S02 and S03".
