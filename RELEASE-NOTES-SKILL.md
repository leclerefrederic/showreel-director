# Release notes: the skill

What each version of the Showreel Director skill (`showreel-director.skill`) changes for you, newest first. The short register that the repository checks is `CHANGELOG.md`. The same skill is built into Showreel Studio; the app's own notes are in `RELEASE-NOTES-APP.md`.

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
