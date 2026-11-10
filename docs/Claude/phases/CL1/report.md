---
type: phase-report
status: current
phase: CL1
date: 2026-11-09
summary: "Report of CL1: the conversation language comes from the Mac and is stored with its origin."
app_version: 0.15.0
prompt:
  - "[[phases/CL1/prompt]]"
decisions:
  - "[[decisions/The conversation language comes from the Mac]]"
tags:
  - report
---
# CL1: the conversation language comes from the Mac, not from a question (app 0.15.0, skill untouched)

## Step 0 (read only, before building)

a) Stored in `showreel.json` as `conversationLanguage` (a code, lower case, nullable), set through `ParameterKey.conversationLanguage`; the picker and the Wizard use `ProjectLanguages.all`: en, fr, de, es, it, pt, nl.
b) The base configuration had five items (conversation language, film language, formats, target duration, look): `ProjectSetup.missing/requirements/progress` ("n of 5 set"); the interview gate (`gateState("interview")`), the checks, `finishSetup` and the workspace-opening rule all read `ProjectSetup.isComplete`. The Wizard (`Wizard.steps`, the first step), Clap's interview (`WizardInterview`, five questions, the first "Which language do we talk in?"), the starting pack (`base.conversationLanguage`) and the Manual form's Film section depended on it.
c) The Wizard asked it first (with a recommendation from an optional `systemLanguage`, never passed by the app); the Manual form had a picker in the Film section next to the film languages. New projects were created with `conversationLanguage: nil`.
d) `addendum.md` told Clap to ask five setup questions; `capabilities.json` said "(conversation and reel languages, formats...)" and "n of 5 set"; `portability.md` says nothing about it; the skill's own interview (`references/interview.md`, Round 0) asks it: that is the skill's method and was not touched.
e) Existing projects hold their value (or none, for the ones made by the app until now, which asked the question): reading never changes them; none is filled in after the fact.

## What was built

1. **Default from the system**: `ProjectLanguages.system(preferred:)` (ShowreelKit, pure, the list is injected): the first preferred language (`fr-FR`, `pt_BR`...) whose code is in the picker's list, English when none. `ProjectStore.create(... preferredLanguages:)` computes it once when `conversationLanguage` is nil (the app's New project) and stores it with `conversationLanguageSource = "system"`; a language given on purpose is kept (no source).
2. **No longer a required question**: the base configuration is four items ("n of 4 set"), the interview gate and `finishSetup` no longer wait for it; the Wizard lost its first step (one fewer: 17 to 16 steps, counting the project ones 9 to 8) and Clap's interview has four questions; the starting pack no longer carries it; the Manual form no longer has it among the fields.
3. **Still editable**: in the Project form, a collapsed "More" area (closed by default) under the control level with the picker and its origin ("From your Mac", "Set by you" after a change, "Kept from before" for an older project, "Not set"). Changing it is the normal `.parameter(.conversationLanguage)` operation: journalled, with Undo (the origin comes back too); `ParameterKey.set` marks the source "user" when the value changes.
4. **The instruction to Clap**: `addendum.md` (a new bullet and "four setup questions"), the interview prompt ("Never ask which language to talk in... Write your first message in that language, then answer in the language the user writes in"), `capabilities.json` (the base configuration text), `tools.json` (the starting pack's `base` no longer lists it; `update_parameter` still can change it as a card). The skill is untouched: `portability.md` needed no change (its check compares the needs, which did not change), so no skill release.
5. **Nothing else**: film languages, formats, duration, look, the Build and the skill's method are unchanged.

## Decisions and deviations

- A new project's language is stored at creation, and `conversationLanguageSource` is a new optional key of showreel.json (older apps ignore it and keep it).
- "Not set" stays possible for an older project with no value: the form shows it and Clap falls back on English until the owner picks one; nothing fills it in.
- Tests that created a project with no language now get the language of the Mac they run on: they assert the origin ("system") rather than a language, so they do not depend on the machine.

## Tests

`CL1Tests` (7): the mapping (French Mac, unsupported language, first supported wins, empty list, `pt_BR`, every picker language); a new project stores the mapped value once with its origin and an explicit language is kept; an existing project is untouched (file unchanged after reading); four items and the text "n of 4"; the gate and `finishSetup` without a language; the Wizard has one step fewer and its prompt never asks it; the collapsed control exists once, in More, and a change is journalled and undone with its origin; the addendum, capabilities and tools carry the new wording.
Changed: `WizardTests` (the steps, the recommendation test, the resume test), `SetupFlowTests` (the counts "of 4", the interview headers and operations, the pack), `PackageTests` (the interview headers, the counts, the package does not set the language), `LifecycleTests` (the list of what is missing), `C1Tests` (the call without `systemLanguage`).

## Verified, not verified

- Verified: the complete `tools/verify.sh` (VERIFY OK, check.py green with capabilities and the portability table in agreement).
- **Not verified: anything drawn** (no screen), and **Clap's real behaviour** (no paid call): that its first message is in the stored language and that it answers in the language you write in is an instruction, not an observed result.

## To check by hand

1. Create a project on a Mac set to French, then to another language (even an unsupported one: English): the stored value (Project settings, More) and its origin "From your Mac".
2. The progress says "n of 4 set"; the Wizard has one step fewer; Clap's first message is in the right language.
3. Change the language under More: it is journalled and Undo (Edit menu) brings back the previous value and "From your Mac".
4. Write to Clap in a language that differs from the stored one: it should answer in yours.

Recorded as a decision: [[decisions/The conversation language comes from the Mac]].
