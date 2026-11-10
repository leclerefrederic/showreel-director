---
type: ux
status: current
phase: 
date: 2026-11-10
summary: "Owner remarks on the scene inspector, including the reversed removal of the Project button."
tags:
  - ux
---

Part of [[ux-notes]].

# Inspector, scene

- ~~Remove the "Project" button at the top right of the scene inspector header.~~ **Reversed by the owner (2026-11-10): removing the way to the project from a scene makes no sense; keep the Project button in the scene inspector header, and the same in the transition inspector (owner: "same for the transition").** It must lead to the project settings (the Project right panel), not only deselect the scene; to settle in DS3 against the rail's Project entry (settled in DS3: every inspector header has the Project button, which opens the Project panel as the rail's entry does).

- Bug seen in use: turning off a scene's look override (switch off) does not show the project's values again, neither in the Look tab nor in the scene tree on the left: the flag says Inherited but the customised values are still displayed.

- Scene Content and Resources tabs merge: an attached resource and a text are both elements of the scene. Proposed name: Composition (a scene is a composition of elements); the items are called elements. Scene inspector tabs become Settings, Composition, Effects, Look.
- The scene tree and the inspector use the same structure: Composition (the elements in priority order, texts, images and sounds mixed, since the order is the priority), Effects (scene-wide), Look (Background, Palette, Fonts, each shown as inherited or overridden). Settings (duration, in the film, review, feeling, passage) are summarised on the scene row. The tree is the overview of the scene's parameters: clicking a group or a node opens the matching inspector tab on that item, where it is managed.
- A resource linked to a scene (by drop or in the manifest) is always an element of its Composition: one that had no element gets one automatically.

- Scene Look tab: an override must be asked for explicitly, with a switch per group (background, palette, fonts), because it departs from the project's base design system. By default the inherited values are shown locked (read-only) with the project's values; turning the switch on unlocks editing for this scene only, turning it off returns to the project value. A drop of a background, palette or look onto a scene asks one short confirmation ("Override for this scene only?") before it creates the override. A scene with an override carries a visible badge in the library, the tree and the reel.

- Known behaviours of W1b to review: a background mood cannot be overridden to "calm" if the project has one (only "revert to project" exists); picking the same value as the project still creates an override.

- The scene inspector is one long form. Split it into tabs: Settings, Effects, Content, Resources (and Look for background and look). Selecting a node of the scene tree opens its tab.
- Seen on screen: a duplicated "Review" heading, a redundant "Ok" status beside the buttons, an "In cuts" field that means nothing to a beginner.
- The app interface is in English while the owner works in French: decide how the interface language is chosen (system language or the project's conversation language).

Phases named in this note: [[phases/DS3/report|DS3]]

Recorded as a decision: [[decisions/Keep the Project button in the scene inspector header]].
