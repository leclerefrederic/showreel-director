# Release notes: Showreel Studio

What each version of the Showreel Studio app changes for you, newest first. The short register that the repository checks is `CHANGELOG-APP.md`. The skill built into the app has its own notes in `RELEASE-NOTES-SKILL.md`. The version of the app and of its skill are shown in About Showreel Studio (the app menu).

## 0.9.2 - 2026-11-09

**Fixed**
- **"Clap did not write v2" now says why.** A Build whose agent stopped without writing the version used to end on an alert that sent you to a chat that said nothing. The agent stopped quietly when an answer reached the output cap (8000 tokens): a long Build writes a file per scene, and a tool call cut in the middle was dropped without a word. The alert, the chat and the project's journal now name the cause: the output limit (with its size), the steps limit, a refusal, an empty reply, an error of the API (with its code) or an answer with no file. A cut tool call is never run and never kept.
- **A Build of a long film gets more room.** The output cap and the number of steps grow with the scenes (a film of 15 scenes gets 32000 tokens and 100 steps), up to a ceiling that is never removed. A question to Clap keeps the usual size.
- **A way on after each stop.** "Try again", and, when the limit was the cause, **Generate the scenes one by one**, which asks Clap for one file per answer. Nothing stays frozen, and a version folder that holds only what the app wrote (film.json) is removed, so the next Build reuses its name instead of piling up empty versions. What Clap did write stays, and the message says so.
- **The journal** gets one line per stopped Build ("Build v2 stopped: token-limit") with the message.

**What you need to do**
- Nothing. If a Build of the trailer fails again, the message tells you why.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.1. macOS 13 or later.

## 0.9.1 - 2026-11-09

**What's new**
- **A film with 3D scenes says what the test could not see.** The Build adds an orange step "3D scenes": "This film has 3D scenes. The logic test cannot draw them: play the film to look at them. No MP4 export for this film." The logic test stays green for what it checks, and the step is a note, not a failure: it blocks neither the build nor the verification. A film without 3D has no such step. When every check passed but a step is orange (3D, or a font with no file), the message says "Build done, with a note" instead of "finished with a problem".
- Clap knows that such a film is not tested by the harness and has no MP4 export, never promises the MP4 for it, and offers 3D only when depth is the point of a scene.

**Fixed**
- **The player test no longer fails on a 3D film** (it reported a script error that came from the test host having no WebGL: this was fixed in the skill, 0.18.1).

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.1. macOS 13 or later.

## 0.9.0 - 2026-11-09

**What's new**
- **The music's grid on the storyboard.** When a track is attached and analysed, a discreet grid appears over the frames at the snap level you chose: beats, bars (stronger), sections and drops. Lines thin out as you zoom out so they never crowd, and they never cross a scene's label, duration or state, or a transition marker. The music lane shows the beats, the bar numbers, the sections with their name and the drops, with the instant of a drop in its tooltip. While you drag the edge of a scene or a cut with snapping on, the target line lights up and a label tells where it will land ("Bar 5, beat 1, 0:12.4"). A **Grid** button in the storyboard bar shows or hides the grid (remembered for the project), and when music is attached but not analysed, **Analyse the track** runs the analysis (it never runs by itself).
- **A Transitions tab in the left panel**, between Scenes and Checks. It lists the film's transitions, one row for each pair of scenes ("S01 to S02: Push, 0.6 s", or "Cut"), with a note on those drawn approximately at assembly and on a free instruction not yet read. A click selects the marker on the storyboard and opens its inspector. Under the list, the catalogue of transitions is a source to drag onto the markers; the six that only run as previews are marked and refused with their reason.

**Fixed**
- **A scene taken out of the film can be dragged back.** Its chip under the strip, like the rows of the transitions and of the look's catalogues, was a button, and a button takes the press so a drag never started. They now drag from anywhere on the row.
- **One thumbnail per frame**, never repeated.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.17.0. macOS 13 or later.

## 0.8.5 - 2026-11-09

**Changed**
- **The font cards show Google Fonts and need no network.** "Add the font files" and the question before a Build list the source (Google Fonts), the licence (the font's own), the files and the total size from the skill's list, so the card appears at once and offline. The network is used only after you accept.

**Fixed**
- **Downloading fonts no longer depends on GitHub's limit for anonymous requests.** The files come from Google Fonts' open repository by their exact path, or from Google Fonts' own download list when the repository does not hold a file by that name. Every file is checked (present, not empty, a font, and the size the list gives) and nothing is added unless all of them arrive. If it fails, the message gives the code and the address, and "Try again" and the font's page stay.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.17.0. macOS 13 or later.

## 0.8.4 - 2026-11-09

**Fixed**
- **Dragging a resource no longer blocks the Resources panel.** A drag now ends in one place whatever happens (dropped, refused, outside any target, cancelled with Escape) and leaves nothing behind. The drag carries the same plain-text token as the handle of a scene, which works, and no longer carries an extra type of its own. The small pictures of the rows and of the drag preview are read once in the background and kept in memory, so starting a drag reads no file. The open hand under the pointer is set, not stacked.
- **The drag log can no longer hold the app.** It is written in the background and a write error is ignored. It now also says how each drag ended and whether any target ever saw it.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.8.3 - 2026-11-09

**What's new**
- **Add a resource to a scene without dragging.** Right-click a resource: "Add to scene" lists the scenes of the film (a locked scene is greyed with its reason; an archived scene is not offered) and, for a music file, "Use as the project's music". In the inspector of a resource, "Use in a scene..." opens the same choice. The result is the line at the bottom ("Linked X to S03") with Undo; during a build everything is greyed and says why.

**Fixed**
- **Dragging a resource from the Resources tab now starts.** A row was a button, and a button takes the press for itself, so no drag could begin from it. The whole row now drags, shows a handle and an open hand under the pointer, and the drag carries a preview with the thumbnail and the name. Every drag start is written in `~/Library/Logs/ShowreelStudio/drag.log`.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.8.2 - 2026-11-09

**Fixed**
- **Dragging a resource from Resources onto a scene.** A scene (a frame of the reel, a row of the scene list, a node of its tree) now takes the resource by its own typed payload, straight on the view under the pointer, instead of depending on the app's memory of the drag. The release always ends with a line at the bottom: "Linked X to S03", or the reason it cannot be done (locked or archived scene, build running, lost drag).
- **A drag log to read what happens.** The app writes `~/Library/Logs/ShowreelStudio/drag.log` (about 100 KB, then it is rotated): where each drag started, what it passed over, whether the target accepted and why, and what the release did. No file content and no folder of yours is written in it. Files dragged from the Finder work as before.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.8.1 - 2026-11-09

**What's new**
- **The app asks before a build when a font has no file.** When you start a Build or an Assemble and a font of the Look is still on "Needs files", a card names the fonts, the source (the open Google Fonts repository), the licence and the size, and offers three choices: "Download and continue" (the files are downloaded and approved for the reel, as with Add font files), "Continue with a system font" (the build starts now and the orange Fonts step says so) and "Cancel". Nothing is downloaded without your yes, your choice is in the journal, and the card does not appear when every font has its files.

**Fixed**
- **Dragging a resource onto a scene.** The release now always does something: it links the resource to the scene (it reads "Used in S0x"), or says in the bottom line why it cannot (a locked scene, a build running, a nowhere target). Before, a release that could not be matched to a target again ended without a word.
- **Covers of MP3 files.** The picture embedded in an MP3 (the ID3 tag) is now found, shown in the preview and counted in the details; files without a picture, or with a damaged tag, simply have no cover.
- **Downloading fonts.** When the font repository refuses, the message gives the HTTP code and the address asked. When GitHub's limit for anonymous requests is reached (60 an hour for one address, easy to hit on a shared company network), it says so in plain words, keeps the manual way (the font's page, then the Resources tab) and offers "Try again".
- **The app's own instructions are no longer drawn as your messages.** The start of the Wizard, a build request or a scene draft show a short line ("Wizard started", "Build requested") instead of the text sent to Clap. The text is still sent, still kept in the transcript, and the Sessions view shows it behind "Show the app's instructions" (off by default).
- **Durations.** The Wizard's question and the presets of the Manual form now offer the same five durations: 30, 45, 60, 75 and 90 seconds (a typed value is still accepted).
- **The eye on the frames of the reel is gone.** Take a scene out of the film with the Delete key or "Remove from film" in its menu; it stays under the strip as a dimmed chip (click it or drag it back). The eye with two states stays in the scene list of the library.
- **No more "Mark as validated" in the Look editors.** The style sheet counts as validated as soon as the palette, the fonts and the background are chosen.
- **One thumbnail per frame.** A frame whose scene has a single still no longer repeats it.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.8.0 - 2026-11-09

**What's new**
- **Save a design as a package.** In the project settings, "Save design as package..." keeps the look, the default transition (when the project has one), the tone, the defaults (formats, duration, film languages, control level) and the resources you choose, one by one with their tags and the rights you gave them. A font added with the Add font files card carries its licence text. You give it a name, an author name (remembered for next time, never an e-mail address) and a note. The package is kept in your library, and you can export it as a `.studiopack` file to send. Saving a package does not change the project, so there is nothing to undo. A project that came from a package offers a new version of the same package, with a note saying what changed.
- **Start a project from a package.** In New project, in Wizard and in Manual, an optional step offers the packages of your library, or "Open a .studiopack...". The design is applied to the new project and the resources are copied with their tags and rights. The project stays on its own, with no link to the package, and remembers where it came from. In Wizard, Clap only asks what the package leaves open; in Manual, the form arrives filled in and counts what is set.
- **The import card.** Double-click a `.studiopack`, drop it on the app or open it from the library: the card shows the name, the author, the dates, the version, the short hash, whether the file is intact, "Not signed", whether you already have an older version, and every resource with the rights its author declared. Tick "I confirm I hold the rights to use these resources" to make them available; without it, the package is kept but its resources wait on Needs attention ("Rights not confirmed by you") until you answer for each. The confirmation is recorded with the version, and in the journal of every project that starts from it. A package never skips the automatic checks of the Resources tab: a file they flag stays flagged. Open fonts ask no question.
- **A file you can trust, or not.** The app checks the package's hash: if the file was modified or damaged after the export, the card says so and asks you to continue or cancel. A package never runs anything: file names, sizes, the number of files and the kinds of file are checked first, and a package inside a package is refused.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2 (a project that started from a package adds a `package` record; older files open as before). Embedded skill 0.16.0. macOS 13 or later.

## 0.7.0 - 2026-11-09

**What's new**
- **Details of a resource, by type.** Under the preview in the centre, one line says what matters (for example "1920 × 1080 · PNG · 245 KB", "3:42 · MP3 · 320 kbps · stereo · 8.4 MB", "Fredoka · 300 to 700 · TTF · 189 KB"). The inspector has a Details section in groups (File, Media, Tags, Rights): for an image the dimensions, aspect ratio, resolution, colour profile and transparency, and a warning when it contains location data; for music and sounds the duration, format, bit rate, sample rate, channels and tags (title, artist, album, year, genre, copyright, cover size), with the tempo when the project already analysed that file; for a font the family, weight, italic, glyph count, format, embedding flag and declared licence; for any file its size, folder, dates and state, with the reason it needs attention and the rights answer. Right-click a value to copy it. Reading is done in the background and kept until the file changes.

**Fixed**
- The preview of a music or sound resource plays the file you selected, starts clean (position, tags and cover) whenever you select another resource, and no longer mixes with the playback of the film: only one of them has the sound at a time, and the film's play controls say "Previewing a resource" until you select a scene.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

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
