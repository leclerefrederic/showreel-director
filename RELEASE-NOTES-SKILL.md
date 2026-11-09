# Release notes: the skill

What each version of the Showreel Director skill (`showreel-director.skill`) changes for you, newest first. The short register that the repository checks is `CHANGELOG.md`. The same skill is built into Showreel Studio; the app's own notes are in `RELEASE-NOTES-APP.md`.

## 0.18.2 - 2026-11-09

**Changed**
- The logic test sorts what it finds. Its report now prints `code errors: N` and `layout warnings: M` after `issues: N`: a code error is an exception while drawing, a scene file that throws when the film loads, or a value that is not a number; a layout warning is text outside the stage or text over text, which is a matter of taste and sometimes wanted. Each listed line says its kind, and the same error repeated on every frame of a scene is listed once with its count (60 identical lines become one with "x60"). The exit code and the `issues:` line are unchanged.
- The engine reference says the exact form of `ease`: an object of functions (`ease.out3(t)`, `ease.outExpo(t)`), never `ease(t)`, and gives the signatures of `clamp` and `lerp`. The build guide describes `--scene ID` as the quick test of one scene file after writing it.

**What you need to do**
- Reinstall the `.skill`.

## 0.18.1 - 2026-11-09

**Fixed**
- The player test no longer fails on a film with 3D scenes. It runs in a host with no WebGL; it used to answer for WebGL with a stand-in, so Three.js threw and the test reported a script error that was not one. It now says that WebGL is missing, like a real host without it, and the 3D layer takes its documented path.

**Changed**
- The portability table says that a film with 3D scenes is judged in the host's player (the logic test cannot draw WebGL) and that a host without the Node exporter has no MP4 for it.

**What you need to do**
- Reinstall the `.skill`. Existing projects are not affected.

## 0.18.0 - 2026-11-09

**What's new**
- A film can now have 3D scenes: real perspective, fields of particles that move on time alone, shader-lit spheres and glows, bloom, vignette and grain. They are scene files like the others, so words, shapes and transitions drawn in 2D go over or under them. The engine carries the 3D library (Three.js, MIT) only in a reel that uses it; any other reel is unchanged.
- Particles and shaders are building blocks, not a look: a particle field can be pulled toward a point or thrown out, orbit and twinkle; the shader library has noise, a moving-noise sphere, a soft disc and ring, and your own GLSL is checked for the one mistake that compiles without an error (a `//` comment).
- The harness now says when a reel has 3D scenes: it cannot see them (there is no WebGL in Node), so it reports "3D scenes not rendered" instead of a silent green result. A test film (`evals/gl-spike`) and a self-test of the pure parts (`scripts/test_sr3d.js`) come with it.

**Changed**
- A reel with 3D scenes weighs about 0.8 MB more and cannot be exported to MP4 with the Node exporter (no WebGL): the exporter warns, and the skill does not promise MP4 for such a reel. The 3D is judged in a browser.
- The interview offers "3D scenes" as a visual language, with those limits stated first.

**What you need to do**
- Reinstall the `.skill`. Existing projects are not affected.

## 0.17.0 - 2026-11-09

**What's new**
- The list of free fonts now says what to download for each font: the names of the files, their weights and sizes (for the weights a look asks for, 400 and 700, or the one variable file), where the licence text is and which licence it is (almost always the SIL Open Font License, a few families are under Apache). A host app can show what it is about to download without asking any service first.
- A maintainer script, `tools/refresh_font_manifest.py`, rebuilds those lists from Google Fonts without a key or an account.

**Changed**
- `fetch_font.py` downloads from Google Fonts' open repository by those file names instead of listing a folder through the GitHub API, which refuses after 60 requests an hour for one address. A file that the repository holds under another name comes from Google Fonts' own download list.

**What you need to do**
- Reinstall the `.skill`. Existing projects are not affected.

## 0.16.0 - 2026-11-09

**What's new**
- A host app can hand the build the font files of the project's look in a small file next to the project settings. The build embeds them in the film, so the film looks the same on every computer, and it checks them like any other asset: they must be listed and approved.
- Font files can live in `assets/fonts/<font name>/`. The asset organiser's check accepts that folder.

**What you need to do**
- Reinstall the `.skill`. Existing projects are not affected: without the new file the build works as before.

## 0.15.2 - 2026-11-09

**Changed**
- The skill's "about" page now presents the Showreel Director trailer as its demo reel, instead of the earlier demo.

**What you need to do**
- Reinstall the `.skill` to get the updated page. Nothing else changes.

## 0.15.1 - 2026-11-09

**What's new**
- The skill's portability table now says what the desktop app does with the assembled film: it keeps a state for each scene and for the whole film, assembles the film on request with no AI, and plays only the assembled film.

**What you need to do**
- Reinstall `showreel-director.skill` to get the new table. Nothing else changes in how the skill works.

## 0.15.0 - 2026-11-09

**What's new**
- A film can be written as one file per scene (`scenes/S01.js`, `S02.js`, and so on) plus an optional file for the whole film. A new script puts them together into the film's main file without any AI, always with the same result for the same files.
- A scene that has no file does not stop the film: it shows as an empty frame with its ID and is listed as not generated.
- One scene can be written again without touching the others.

**Changed**
- When the desktop app asks for a build, it asks for scene files instead of one main file.

**What you need to do**
- Reinstall the `.skill`. A project that already has a single main file keeps building and playing exactly as before; nothing is migrated for you. To move a project to the new format, run a new Build in the app.

**Compatibility**
- Works with Showreel Studio 0.2.0 or later. Older versions of a project in the single-file format stay readable.

## 0.14.2 - 2026-11-09

**What's new**
- The portability table describes the desktop app's project memory, its journal of every change and its summary of each work session. They stay with the project, whichever AI model you use.

**What you need to do**
- Reinstall the `.skill` to read the updated table.

## 0.14.1 - 2026-11-08

**Changed**
- The portability table follows the app: the look now lives in the project settings, the pickers for effects, transitions and backgrounds sit where they are used, and a floating Catalogue can be dragged from.

## 0.14.0 - 2026-11-08

**What's new**
- A film format for the app's Build: the app writes the montage (order, start, length and transition of every scene) in a file next to the project, and the build reads it. The scenes no longer repeat times and transitions in their own code.
- A list of the transitions that are previews only and cannot run between two real scenes.
- The logic test can look at one scene only.

**What you need to do**
- Reinstall the `.skill`. Existing single-file projects are not affected.

## 0.13.0 - 2026-11-08

**What's new**
- An optional film layer: each scene can be its own module, and the 42 scene transitions of the effects lab can run between two real scenes, drawing both at once. It comes with a small test film and a pixel test. The single main file stays the default.

**What you need to do**
- Nothing, unless you want to try the layer: it is described in the engine reference.

## 0.12.0 - 2026-11-08

**Changed**
- The portability table describes the storyboard as a film reel with transitions between scenes and the project's music grid. The skill itself does not change.

## 0.11.0 - 2026-11-08

**What's new**
- When a project is exported to Showreel Studio, each scene's words become the first item of its content, with every attribute left to the AI (auto).

**Changed**
- The portability table describes a content list per scene with fixed or auto attributes.

## 0.10.1 - 2026-11-08

**Changed**
- The portability table describes the scene library as a tree per scene with a status on each node, and a scene that can replace the project's background and look.

## 0.10.0 - 2026-11-08

**What's new**
- Exporting a project to Showreel Studio now writes the scene library and one montage: scene lengths, rejected scenes archived and switched off, and the note of each passage between scenes.

**Changed**
- The portability table follows the app's editing workspace.

## 0.9.2 - 2026-11-08

**Changed**
- The portability table has two more rows for the desktop app: writing the storyboard, reviewing each scene and giving the Go on screen, and building, testing and playing the reel. The method does not change.

## 0.9.1 - 2026-11-08

**Changed**
- The portability table has a row for choosing the look (palette, fonts, background, effects mood) on screen in the desktop app, with the usual fallbacks to the look board, the font picker, the background picker and the effects lab. The method does not change.

## 0.9.0 - 2026-11-08

**What's new**
- The first numbered version. It covers the interview that leads to a brief, the feasibility checks, the scene-by-scene review, a self-contained HTML build, MP4 export, audio analysis, the look board, the font and background pickers, the effects lab, the asset organiser, reduced-motion support, the fallbacks for sessions with fewer tools, and the export of a project to Showreel Studio.

**What you need to do**
- Install `showreel-director.skill`.
