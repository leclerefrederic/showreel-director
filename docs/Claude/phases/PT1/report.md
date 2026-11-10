---
type: phase-report
status: current
phase: PT1
date: 2026-11-10
summary: "Report of PT1: project settings in three tabs (Brief, Format, Look) under the name and base configuration; no conversation language control; app 0.23.0."
app_version: 0.23.0
skill_version: 0.18.2
prompt:
  - "[[phases/PT1/prompt]]"
tags:
  - report
---

# PT1: the project's properties in tabs, and no conversation language choice

## Step 0

- a) The form, in order: Base configuration (progress bar and four items: Film language, Formats, Target duration, Look), Project name, the Film card (Formats, Target duration with its feasibility line and custom field, Film languages), the Brief card (Audience, Message, Tone, Constraints), Control level (three cards), a "More" disclosure (below the fold) holding only the Conversation language picker, then a "Look: set or not" row with "Open the Look".
- b) Control level (Auto, Guided, Precise) is the project's `parameters.controlLevel`; it sets how much of a scene's content the Build may decide (each attribute fixed or auto, the brief carries the level): unchanged, now in the Brief tab.
- c) The only control was the picker under More. The value is `conversationLanguage` (and `conversationLanguageSource`) in `showreel.json`, written once from the Mac when a project is created (`ProjectStore.create`, CL1). Readers: Clap's Wizard prompt ("the app has settled it, from the user's Mac"), `ProjectDocs`, the importer, tests. Nothing in Settings, the new project sheet or the Wizard offered it.
- d) The panel had two tabs (`SettingsTab` project and look), stored as the right panel name and, since SM1, as `settingsTab`. Opened by the rail (`setRight`), by `openSettings(tab)` (links, drops, packages), by a check target and by Clap's `open_block`.

## Built

1. **Tabs:** `ProjectTab` (Kit): Brief, Format, Look, on `TabBarModel` (arrow keys, wrap). The panel draws the project name and the compact base configuration (`ProjectForm(part: .header)`) above the `TabBar`; Brief holds Audience, Message, Tone, Constraints and the Control level cards; Format holds Formats, Target duration and Film languages; Look is unchanged. The whole form stays as the set-up of a new project (`part` nil). A checklist item selects its tab (`ProjectTab.tab(forRequirement:)`: Look to Look, the others to Format).
2. **Name of the second tab: "Format".** It holds formats, duration and on-screen languages, which describe how the film is made; "Film" would repeat the strip's name, "Specs" is jargon.
3. **Model and storage:** `ProjectTab.opening` (the first tab with something unset, else the last used) applies when the panel opens from the rail; `openSettings(tab)` goes to the tab asked for (the checks of the project go to Format, Clap's project block to the default). The tab is stored as `settingsTab` in `.studio` settings (`storedValue`: nil for Brief); an old "project" or missing value is Brief, a stored "look" stays Look, and an old right panel "look" opens Project on Look.
4. **Message padding:** `FormLayout.multilinePadding` (6 pt) as the field's inner vertical padding for the four Brief fields that can grow (`fieldVerticalPadding` environment of `ThemedTextFieldStyle`).
5. **Conversation language:** removed the "More" area and the picker. Kept, unchanged: `ParameterKey.conversationLanguage` (the typed operation Clap or a test can use), the value and its source in the file (never deleted), the Mac's language written at creation, the Wizard prompt line, `ConversationLanguage.origin` (used by tests, no longer by a view), `ProjectDocs`. The "Look: set / Open the Look" row of the old form is removed (the Look tab and the checklist replace it). Film languages stay.

## Deviations

- Version is minor (0.23.0): the stored tab value changes shape.
- `capabilities.json`: the base configuration sentence no longer says the language is editable under More; the settings panel row names the three tabs. `references/portability.md` did not describe a language control: skill untouched.

## Tests

`PT1Tests` (10): tabs and order, arrow keys, default and opening rule, requirement to tab, stored selection and migration, each field of the old form in exactly one place and the name and base configuration above the tabs, multiline padding, no conversation language offered and the Mac's still reaching Clap and the file, an old stored value kept. Updated: `CL1Tests` (no More area), `LookSettingsTests` (the panel's parts), `MemoryTests` (the three tabs), `SM1Tests` (stored tab and default).

## Verified, not verified

Verified: build, tests, `verify.sh`. Not verified (no screen): the panel's look, the tabs, the padding, a click on a checklist item, the tab restored after relaunch, Clap answering in the Mac's language.

## To check by hand

The panel with its three tabs (every field of the old form present once, nothing lost); the project name and the compact base configuration visible on every tab; a click on a checklist item going to its tab; arrow keys between the tabs; the tab restored after quitting and reopening; an older project opening on the right tab; the panel dragged wider and narrower; the Message field's text off its border; no conversation language anywhere (panel, Settings, new project, Wizard); Clap answering in the Mac's language and in the language you write in.
