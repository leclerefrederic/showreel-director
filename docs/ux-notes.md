# Showreel Studio: UX notes per block

The owner's remarks while testing, one section per block, newest first. Nothing here is built until the owner turns a note into a brief. Views hold no business logic: they call typed operations, so a rework touches the screen only.

Order of the per-block rework: Project and wizard, Resources, Look, Storyboard and scene, Build and deliver.

## Application (launch, library, settings)

- Panels (library, inspector, storyboard strip) must resize freely with no imposed maximum, only a sensible minimum; sizes remembered per project. Requested by the owner and added to the W3a pass as a separate item.

- The Library window opens at launch by default (built in phase T).

## Library, Scenes tab

- Each scene must expand into a tree of what composes it: Raw (images, sound, etc.), Texts, Effects, Background (inherited from the project), Look (inherited from the project). The goal is to see at a glance what a scene is made of (scheduled as phase W1b).

## Inspector, scene

- Known behaviours of W1b to review: a background mood cannot be overridden to "calm" if the project has one (only "revert to project" exists); picking the same value as the project still creates an override.

- The scene inspector is one long form. Split it into tabs: Settings, Effects, Content, Resources (and Look for background and look). Selecting a node of the scene tree opens its tab.
- Seen on screen: a duplicated "Review" heading, a redundant "Ok" status beside the buttons, an "In cuts" field that means nothing to a beginner.
- The app interface is in English while the owner works in French: decide how the interface language is chosen (system language or the project's conversation language).

## Scene content

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

## Storyboard and scene editor

## Storyboard and music

- The project's music should show under the storyboard with its waveform and analysis. Stretching a scene to the left or right snaps to the track's grid (stick to grid), so scenes are timed on the music.

## Build and preview

## Deliver
