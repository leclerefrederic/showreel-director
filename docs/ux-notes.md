# Showreel Studio: UX notes per block

The owner's remarks while testing, one section per block, newest first. Nothing here is built until the owner turns a note into a brief. Views hold no business logic: they call typed operations, so a rework touches the screen only.

Order of the per-block rework: Project and wizard, Resources, Look, Storyboard and scene, Build and deliver.

## Application (launch, library, settings)

- Very important (owner): the project must keep the AI's memory so that what was decided, validated or modified is never lost, even if the user changes the model or relaunches the project: a history of the work sessions. Scheduled as phase M (journal, curated memory, session history).

- The AI assistant is named Clap (the word Copilot is too tied to another product). User-facing only: the right panel tabs are Inspector and Ask Clap (with a clapperboard icon, a badge when a proposal is waiting), the panel header reads "Clap, AI assistant", and the interface says plainly that it is an AI. Code names, tool names and file names keep "copilot" where they exist. If asked what it is, Clap answers honestly that it is an AI assistant built on Claude.

- Library window: the project rows need a hover effect at minimum. Opening a project by double-click is not intuitive: one click opens it (with a clear affordance such as a chevron or an Open button on hover). The grey "start" badge looks clickable and does nothing: show the project's progress as plain status text with a clear meaning (for example Setup, Storyboard, Built), not as a button-like pill.
- Library window: remove the Settings button at the bottom. Application settings live only in the app menu (Showreel Studio, Settings, Cmd+,).

- The scene look bug seen earlier came from leftovers of an old project (data written by an older version of the app). Needed: an explicit way to bring an outdated project up to date, and a way to delete a project. Proposal: `showreel.json` gets a format revision number; the Library marks an outdated project and offers "Update project", which lists what will change, keeps a backup first (`.studio/backups/`), migrates and rebuilds the derived caches, with a way back by restoring the backup. Deleting: "Remove from Library" (files kept) and "Move to Trash..." (confirmation naming the folder and its size, never a permanent deletion); a project whose folder is missing shows as missing with "Locate..." and "Remove".

- Look editor chooser: the dropdown listing Looks, Palette, Fonts, Background, Moods, Effects pack is not intuitive. Proposal: the Look tab of the project settings is a list of six rows (icon, name, the current choice as a swatch or sample); clicking a row opens that editor (drill-in with a back button, like macOS System Settings), with the current choice pinned at the top and the library below.
- A new project must not start without its base configuration, even in Expert mode, because everything else depends on it. Proposal: a required setup at creation, the same data in both modes (the wizard in Beginner, one compact form in Expert), covering the languages (conversation and reel), the formats, the target duration and a look (palette, fonts, default background); the workspace opens only when these are set. Audience, message and tone stay optional.
- Checks: they should live in the left panel as a Checks tab (with a badge counting what is red or orange), grouped by area (Project, Resources, Scenes, Storyboard, Music, Build). Clicking a check opens the element to configure: the project setting, the resource, the scene or the transition concerned.

- The Look tab (palette, fonts, backgrounds, effects, transitions, looks) does not belong in the left library: the look is a project parameter, not an asset like a scene or a resource. The library keeps assets only (Resources, Scenes). Proposal pending validation: the global look (looks board, palette, fonts, default background, mood and effects pack) moves to the project settings in the top bar; the catalogues of effects, transitions and backgrounds become pickers inside the scene inspector (Effects tab, per-scene Look), the transition inspector, plus an optional floating catalogue palette that stays a drag source.

- Project settings belong in the top bar of the project window (one button opening the project's parameters: audience, message, tone, languages, formats, duration, constraints, control level). App settings (API key, gateway, model, environment, skill version) do not belong in the toolbar: they stay in the application menu (Showreel Studio, Settings, Cmd+,), because they are about the app and not about a project.

- Overall feel: too much like a form-based Windows application of the 2000s. More drag and drop everywhere (reorder elements, rearrange, drop resources onto scenes), more fluid, visual and dynamic. Up and Down buttons should go. Scheduled as W5 (direct manipulation) and P (feel).

- Bug seen on screen after the resizable panels: the storyboard strip cannot be resized vertically (the library and inspector widths work).

- Panels (library, inspector, storyboard strip) must resize freely with no imposed maximum, only a sensible minimum; sizes remembered per project. Requested by the owner and added to the W3a pass as a separate item.

- The Library window opens at launch by default (built in phase T).

## Library, Scenes tab

- Bug found testing W5: a resource cannot be dragged from the library onto a scene, because Resources and Scenes are separate tabs of the same panel, so the source and the target are never visible together. Fix: the reel frames (always visible) and the selected scene's inspector accept drops, and tabs switch by themselves when a drag hovers over them (spring-loaded tabs). To consider in the feel pass: showing Resources and Scenes together (stacked sections) instead of tabs.

- A scene can be renamed (a name chosen by the user, shown next to its ID). The ID (S01, S02) stays stable and is never renamed or reused; the name is only a label, used in the library, the tree, the reel and the copilot's messages.

- Each scene must expand into a tree of what composes it: Raw (images, sound, etc.), Texts, Effects, Background (inherited from the project), Look (inherited from the project). The goal is to see at a glance what a scene is made of (scheduled as phase W1b).

## Inspector, scene

- Remove the "Project" button at the top right of the scene inspector header: the project settings are already always reachable from the top bar.

- Bug seen in use: turning off a scene's look override (switch off) does not show the project's values again, neither in the Look tab nor in the scene tree on the left: the flag says Inherited but the customised values are still displayed.

- Scene Content and Resources tabs merge: an attached resource and a text are both elements of the scene. Proposed name: Composition (a scene is a composition of elements); the items are called elements. Scene inspector tabs become Settings, Composition, Effects, Look.
- The scene tree and the inspector use the same structure: Composition (the elements in priority order, texts, images and sounds mixed, since the order is the priority), Effects (scene-wide), Look (Background, Palette, Fonts, each shown as inherited or overridden). Settings (duration, in the film, review, feeling, passage) are summarised on the scene row. The tree is the overview of the scene's parameters: clicking a group or a node opens the matching inspector tab on that item, where it is managed.
- A resource linked to a scene (by drop or in the manifest) is always an element of its Composition: one that had no element gets one automatically.

- Scene Look tab: an override must be asked for explicitly, with a switch per group (background, palette, fonts), because it departs from the project's base design system. By default the inherited values are shown locked (read-only) with the project's values; turning the switch on unlocks editing for this scene only, turning it off returns to the project value. A drop of a background, palette or look onto a scene asks one short confirmation ("Override for this scene only?") before it creates the override. A scene with an override carries a visible badge in the library, the tree and the reel.

- Known behaviours of W1b to review: a background mood cannot be overridden to "calm" if the project has one (only "revert to project" exists); picking the same value as the project still creates an override.

- The scene inspector is one long form. Split it into tabs: Settings, Effects, Content, Resources (and Look for background and look). Selecting a node of the scene tree opens its tab.
- Seen on screen: a duplicated "Review" heading, a redundant "Ok" status beside the buttons, an "In cuts" field that means nothing to a beginner.
- The app interface is in English while the owner works in French: decide how the interface language is chosen (system language or the project's conversation language).

## Scene content

- Bug seen in use: adding another content item (a second text) makes the existing items lose what was typed, and every text field shows the placeholder "Your words" again.
- "Your words" must be a real placeholder (grey ghost text that disappears as soon as the field has focus), never a stored value. An empty text item stays empty. This may be the cause of the bug above if the default text is saved as content.

- Content is a map of what the scene contains and the instructions for the AI. Items: a text, its colour (linked to the palette, or "AI decides"), its animation (fly in, and so on, or "AI decides"), an optional instruction. The user chooses how much control they want. The order of the items is their processing priority.

## Project and wizard

## Resources

- Group the resources by type, then by status.
- Types: Images, Sounds, Music.
- The central zone is the preview of the selected resource.
- For a music file the centre shows its metadata, the cover image when the metadata holds one, and a simple player (play, pause, scrub).
- Resources can carry tags (for example an image can be a logo or a wallpaper), and the list can be filtered by tag.
- Decided: tags live in `showreel.json` (app mechanics, the skill's manifest format is untouched); Music = `audio` tracks, Sounds = `sfx` and `voice`.
- Resource inspector, seen on screen: "Used in scenes" must not be a free text field. It is derived: show a tag per scene that uses the resource (clickable, selects the scene); linking is done from the scene.
- Simplified resource states (owner's direction, refined): a resource is used or it is not. The user sees four things only: **Available** (in the library, approved because the user added it, not used by any scene yet), **Used in S01, S07** (one clickable tag per scene), **Proposal** (only when the AI analysed something and suggests it: a read-only note giving the AI's reason, and two buttons, Approve or Decline; approving makes the resource approved and links it to the scene), and **Needs attention** (see below). A declined proposal is kept out of sight (collapsed "Declined") so the AI does not propose it again.
- Safety stays, but automatic: the app flags a file by itself (name suggests personal or confidential data, resolution too low, heavy file, rights or consent not confirmed, font licence forbids embedding) and marks it **Needs attention** with the reason in plain words; it cannot be used until the user fixes it (replace the file) or accepts the risk with a short reason (this is the skill's hold and waiver, kept under the hood). No status dropdown for the user to manage.
- Under the hood the skill's manifest statuses stay: Available and Used = approved, Proposal = proposed, Declined = excluded, Needs attention = hold. Placeholder becomes a tag ("placeholder", listed in the release gate).
- "Licence note" and "Note" fields: drop them as permanent fields. The rights question is asked only when a file is flagged, with a short list (own work, supplied by the client, licensed, free licence, unknown; unknown puts it on Needs attention) and an optional detail; a note appears only on Needs attention or when the user adds one.
- When a file is added: (1) automatic checks run at once, without AI and without a key (type, resolution, weight, personal-data hints in the name, copyright fields in the metadata, font embedding flag); a flagged file goes straight to Needs attention. (2) AI analysis is a second, optional step for what the rules cannot see (a watermark, a recognisable person, a third-party logo, a screenshot with personal data). It runs by default for files that passed the automatic checks, once the project has the owner's consent for it (a project setting, asked the first time a key is used); a file flagged by the automatic checks is never sent to the AI. The AI can only raise a suspicion, as a Proposal or a Needs attention reason: it cannot know the legal licence of a file, so the decision stays with the user.
- Staging is physical: a file that needs attention stays in `assets/source/` (never in `assets/prepared/`), is left out of the AI's prompt and tools (the copilot cannot read it and Build refuses it, as `build.py` already does for held files). The AI never uses it, whatever it concludes.

## Look and technique

- Option cards in the look editors carry a "Use this palette" style button. Replace the buttons with direct selection: the whole card is the target, it reacts on hover (subtle lift or highlight), and a click selects it at once; the selected state is obvious; keyboard accessible. Same pattern for looks, palettes, fonts, backgrounds, moods and effects packs.
- Possible bug seen on screen (palette editor): the pinned card says "Current palette, Slow film" and shows the Slow film colours, while the "Edit the colours" block below shows the project's own colours (#101820, #FFFFFF, #F2AA4C): the card must show the project's actual palette, labelled with a look name only when it matches that look, otherwise "Custom".

- When the project settings are open, the central viewer shows the project's design system as a visual board (palette with roles, type specimens for titles and text, the background running live, a sample of the chosen animation and mood), updating live as options change. It is visual and speaks for itself.
- In every look editor (looks, palette, fonts, background, moods, effects pack) the chosen option is always visible at the top, large, with its preview; the other options sit below it as a library of materials to pick from. Today everything is blended in one list and the current choice is hard to see.

## Storyboard and scene editor

## Storyboard and music

- The storyboard strip panel resizes but its content does not follow, so a taller panel is useless. The reel must zoom: frames, thumbnails and the music track scale with the panel height, and the time scale can be changed to focus on a portion instead of the whole film (zoom in and out, fit to the whole film, fit to the selection, horizontal scroll, the playhead stays in view).

- The project's music should show under the storyboard with its waveform and analysis. Stretching a scene to the left or right snaps to the track's grid (stick to grid), so scenes are timed on the music.

## Build and preview

## Deliver
