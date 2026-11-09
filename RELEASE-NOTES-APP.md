# Release notes: Showreel Studio

What each version of the Showreel Studio app changes for you, newest first. The short register that the repository checks is `CHANGELOG-APP.md`. The skill built into the app has its own notes in `RELEASE-NOTES-SKILL.md`. The version of the app and of its skill are shown in About Showreel Studio (the app menu).

## 0.6.0 - 2026-11-09

**What's new**
- **A clearer Resources tab.** Files are grouped by type (Images, Sounds, Music, Fonts), then by state, and a group can be folded; the app remembers it for the project. The file you select is shown in the centre: the image, a sound or a piece of music with its tags, its cover and a small player, or a font as a specimen.
- **Tags.** Give a resource tags (a logo, a wallpaper...), filter the list by tag, rename a tag everywhere. The tag "placeholder" marks a stand-in, and the release gate lists it as before.
- **Four states.** Available, Used in S01, S07 (one clickable tag per scene; it is worked out from the scenes, you never type it), Proposal (Clap suggests it: Approve or Decline) and Needs attention.
- **Automatic checks, no AI and no key.** A file you add is available at once. If something looks wrong (a low resolution, a heavy file, a name that suggests real data, a copyright notice in the file, a font whose licence is unknown or forbids embedding) it waits on Needs attention with the reason in plain words. It cannot be used, Clap cannot see it, and the build refuses it, until you replace it, accept the risk with a short reason, or answer what you are allowed to do with it.

**Changed**
- The permanent fields "Licence note", "Note" and "Used in scenes" and the status menu are gone. The rights question appears only for a flagged file.
- A file you add is approved straight away when it is clean (it used to wait for your approval).
- A font you drop in by hand now needs its licence answered; one added by the Add font files card does not.

**What you need to do**
- Nothing. Open an older project: its resources show in the new groups, with the states worked out from the manifest. Nothing in the files changes.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.5.1 - 2026-11-09

**Changed**
- Nothing you can see: the New project screen moved to its own file so that the checks on the Library window stay true.

**What you need to do**
- Nothing.

## 0.5.0 - 2026-11-09

**What's new**
- **Two ways to start a project.** The New project screen offers two cards, chosen once: Wizard, where Clap asks a few questions and then proposes a starting pack (the base setup, a look, the scenes and their order, the music if you gave some) as cards you accept one by one or all at once; and Manual, where you fill a compact form yourself. Both end in the same interface. Wizard needs an API key; without one its card says so and tells you how to connect one, or to choose Manual.
- **A clearer project form.** Formats are tiles with their shape, the duration has quick values and says at once whether it is feasible, the film languages are chips you pick from a list, the brief fields are compact with an example in each, and the control level is three cards. The required setup shows "n of 5 set" and the workspace opens when it is complete.
- If Clap cannot go on during the Wizard, a clear message and a button take you to the form, with the answers you already gave.

**Changed**
- The words Beginner and Expert are gone, and there is no switch between them in a project. An older project keeps working: Beginner reads as Wizard and Expert as Manual.
- "Mark as validated" no longer exists for the interview: it counts as done when the base setup is complete. The Go is still the only validation you give.

**What you need to do**
- Nothing. Open an older project as usual; nothing is changed in its file.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.4.1 - 2026-11-09

**Changed**
- Clap now knows that generating a scene whose file you edited by hand overwrites your edit, and says so before it proposes it. The card already showed it; the assistant's instructions now match.

**What you need to do**
- Nothing.

## 0.4.0 - 2026-11-09

**What's new**
- **Marks everywhere.** A scene, an item or a resource that is read-only because Clap proposes a change, or because the film is being built, now shows a thin orange outline and a small button on the reel's frames, in the scene tree and in the Resources list, as it already did in the scene list. The tooltip gives the reason and the way out; a click on a proposal's mark takes you to its card.
- **Badges in one order.** On the list, the tree, the reel and the inspector, a scene shows its review state first and its build state next, side by side. The temporary outline never covers them.
- **Generate follows the changes.** The offer in the player now includes the scenes whose file is out of date, not only the ones with no file. It is still one card with the files, the number of calls and an estimated cost; locked scenes are left out with their reason. A scene whose file you edited by hand is only generated if you tick it, and the card says your edit will be overwritten. The reel's counter counts both missing and stale scenes.
- **Buttons and menu items say why.** Disabled buttons in the palette and moods editors, the memory form, the editor, the set-up screens, the new project, update and restore sheets, the preview and the wizard now explain themselves in a tooltip. Undo and Redo in the Edit menu say "nothing to undo" or "building the film" in their own title.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.3.0 - 2026-11-09

**What's new**
- **Fonts in the film.** Each font of the Look shows its state: Needs files, Preview only or Embedded. When files are missing, a sentence says what the film will do instead (use a system font, which looks different and can vary between computers) and a button, Add the font files, fixes it.
- **Add font files.** One card shows the font, where it comes from (the open Google Fonts repository, from the skill's fixed list only), its licence (SIL Open Font License, the text is kept), the files with their total size, and that the network is needed. Accepting the card approves the files for the film and downloads only the weights the Look uses. It can be undone, and Clap can propose the same card.
- **Embedded in the build and in Assemble.** Approved font files are embedded in the film. A font with no file gives an orange "Fonts" step that names it. Adding or removing font files makes the assembled film stale, but no scene.
- **Font files you drop in Resources** show their family and weight, and which part of the Look uses them. A font needs its licence note before you can approve it.

**Changed**
- The build asks Clap not to list the Look's fonts itself: the app embeds the approved ones.

**What you need to do**
- For each font that says "Needs files", press Add the font files and read the card. If the network is blocked, download the font from its page and drop the files in Resources.
- Assemble or build again to get the fonts into the film.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.2.0 - 2026-11-09

**What's new**
- **Scene states.** Every scene is WIP, Validated or Locked. A Locked scene refuses every change to its content, length or look, from you and from Clap, and says why. Only a Validated scene can be locked. "Lock all validated" locks them in one step. A click on the state badge opens a small menu.
- **Ask Clap.** The assistant's tab is called Ask Clap. Conversation, Memory, Sessions and Journal are in a selector at its top (they used to be in the project settings).
- **Global look and locked scenes.** When a change to the project's look would change locked scenes that follow it, the card lists them and says so. You can apply anyway or refuse.
- **One file per scene.** A film is built as one file per scene, put together by the app with no AI. Clap can write the file of one or several scenes only, after one card that lists the scenes, the number of calls and an estimated cost. A locked scene is never written again without unlocking it.
- **Assemble and Play.** "Assemble" puts the film together for free. Play plays only the assembled film; if the film is stale, it is assembled when you press Play. A scene with no file shows as an empty frame with its ID.
- **States you can read.** Each scene shows whether it is not generated, up to date, stale or edited by hand, and the reel header says whether the film is up to date, stale or has scenes to generate. A film in the old single-file format plays as it is and says so.
- **The interface reacts.** While Clap proposes a change, the elements it touches are marked and read-only, with a banner to accept or refuse. While Clap works, a chip says what it is doing. While the film is built, everything is read-only, with a progress panel and a Cancel build button. Every change gives a line at the bottom with Undo, and a refusal says why and what to do. Closing the window, quitting, updating or restoring while work is in progress asks first and says what will be lost.
- **Transitions.** Transitions that only approximate at assembly, and free instructions that a generation has not read yet, are marked.

**Changed**
- A version that a stopped or failed build left behind is never the one that plays: the player keeps the last version that was built and tested, and the version is marked incomplete.
- A new Build asks Clap for scene files instead of one big file.
- Review states are named WIP, Validated and Locked (the older words open, ok and modify still read correctly).

**What you need to do**
- Open each existing project and accept "Update project" in the banner. The app keeps a backup first and can restore it.
- To move a project to the one-file-per-scene format, run a new Build. Until then it plays as before.
- Nothing to install for the skill: the app carries its own copy.

**Compatibility**
- Project format revision 2. Embedded skill 0.15.2. macOS 13 or later (the Ask Clap icon looks different before macOS 14).

## 0.1.0 - before these notes

The base of the app, before release notes existed. The phases are listed in `docs/phases-done.md`.

**What's new**
- A native Mac app with the assistant (Clap) in a chat, question cards and a key kept in the Keychain; the skill runs inside it.
- Projects with a library, a guided path for beginners and a workspace for experts, generated documents, checks and a first build you can play.
- The editing workspace: a scene library with a tree per scene and ordered content, an inspector, a viewer and a storyboard that is a timeline with transitions, durations, music and a grid.
- Direct manipulation (drag and drop everywhere, undo and redo of every change), the look as project settings with pickers where choices are used, and "Update project" with backups.
- A project memory, a journal of every change and a summary of each session, kept in the project.

**What you need to do**
- Nothing: this is the starting point.
