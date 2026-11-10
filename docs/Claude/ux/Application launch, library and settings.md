---
type: ux
status: current
phase: 
date: 2026-11-10
summary: "Owner remarks on launch, library and settings, starting with a project memory that keeps what was decided."
aliases:
  - "Application (launch, library, settings)"
tags:
  - ux
---

Part of [[ux-notes]].

# Application launch, library and settings

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
- History belongs to Clap: memory, sessions and journal are reached from the Clap tab, not from project settings. Le titre de l'onglet est "Ask Clap" avec une icône.
- Selector labels are in English (Conversation, Memory, Sessions, Journal).
- A global look change warns on its card about locked scenes that inherit it; the owner decides.
