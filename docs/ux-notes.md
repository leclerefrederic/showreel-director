# Showreel Studio: UX notes per block

The owner's remarks while testing, one section per block, newest first. Nothing here is built until the owner turns a note into a brief. Views hold no business logic: they call typed operations, so a rework touches the screen only.

Order of the per-block rework: Project and wizard, Resources, Look, Storyboard and scene, Build and deliver.

## Application (launch, library, settings)

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

## Look and technique

## Storyboard and scene editor

## Storyboard and music

- The project's music should show under the storyboard with its waveform and analysis. Stretching a scene to the left or right snaps to the track's grid (stick to grid), so scenes are timed on the music.

## Build and preview

## Deliver
