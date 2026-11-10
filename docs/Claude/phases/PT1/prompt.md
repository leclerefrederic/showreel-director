---
type: phase-prompt
status: current
phase: PT1
date: 2026-11-10
summary: "Project settings in three tabs (Brief, Format, Look) instead of one long scroll; the Clap conversation language control is removed (the Mac's language is used)."
tags:
  - prompt
---

# Phase PT1: the project's properties in tabs, and no conversation language choice

Read CLAUDE.md first and follow every rule (never run git, English interface, skill untouched, answer the owner in French and short, no screen so say what was not seen, no out-of-scope work: an idea goes in a note created with `python3 tools/docs_new.py idea`). Use `graphify query` before reading files. Views stay free of business logic: rules live in ShowreelKit with tests. The owner waived the open questions for the redesign. **Change only what is listed here**, keep every behaviour, every operation and every stored value.

The owner's words (screenshot of the Project settings panel: a Project and a Look tab, then one long scroll holding "Base configuration" with its checklist, the project name, the Film card (Formats, Target duration, Film languages) and the Brief card (Audience, Message, Tone, Constraints and more below)): "Replace it with tabs for the project's properties: 1. Brief and Control level (call it Brief). 2. Format, duration and language (find a term). 3. Look." "The choice of the conversation language for Clap makes no sense: an LLM adapts to the language by itself. By default Clap speaks the language and region of the operating system."

Read docs/Claude/ux-notes.md (entries "Forms", "Real tabs", "Project and wizard"), the DS3, DS3b, CL1, SM1 and RB1 reports, and the code: the Project panel (ProjectSettingsPanel.swift, ProjectFormViews.swift and the cards they draw), `TabBarModel` and its view, how the panel's selected tab is stored (RL1's stored sizes and layout), the conversation language (CL1: where it is read from the Mac, where it is stored, where it is shown, where Clap's prompt and the Wizard use it), `capabilities.json`.

## Step 0 (read-only, 10 lines at the top of the report)

a) Every section of the Project form in order (Base configuration and its checklist, Project name, Film, Brief, "Control level", anything below the fold) with the fields each holds.
b) Where "Control level" sits today (three cards: Auto, Guided, Precise) and what it changes in the project and in the Build.
c) Everything that still offers or stores a conversation language for Clap (a control in the panel, in Settings, in the Wizard or the new project sheet), where the value is written (`showreel.json`, the project, the app settings), and who reads it (Clap's system prompt, the skill's interview, tools, tests).
d) How the Project panel's two tabs are modelled and stored today, and what opens the panel on a given tab (the rail, the shared open operation, links, SM1's Look paths).

## What to build

1. **Three tabs, in this order, built on the existing tab bar (`TabBarModel`, underline style):**
   - **Brief**: the Brief card (Audience, Message, Tone, Constraints and the rest of it) and the Control level (three choice cards: Auto, Guided, Precise, each with its helper text, as today). In this tab give the multi-line fields (Message) the same inner vertical padding as the single-line ones: today the Message text sits tight against its top and bottom border.
   - **Format**: the Film card: Formats, Target duration (with its feasibility line and the custom field), Film languages (the on-screen languages). The tab is called "Format"; if a better word fits the three things it holds (formats, duration, on-screen languages), you may use it, say which and why, and keep it one word. (Alternatives I considered: "Film", "Specs".)
   - **Look**: the Look editor as today.
   The Project tab disappears as such: its content is spread over Brief and Format. **The Project name stays visible above the tabs** (it identifies the panel, so it is not hidden in a tab), and the **Base configuration card (progress bar and checklist) stays above the tabs in a compact form**, visible on every tab. Each item of the checklist selects the tab where that item is set (Film language, Formats and Target duration on Format, Look on Look): a small reaction that replaces the owner's scrolling; no other new behaviour.
2. **The tab model is pure in ShowreelKit with tests:** the three tabs, their order, the default (the first tab with something unset in the base configuration; otherwise the last one used), the stored selection (restored at launch, stored apart from the project's content like the other layout settings), the mapping from each base configuration item to its tab, and the arrow-key order. Every path that opened the panel on "Project" or on "Look" lands on the right new tab through the one shared open operation (an old stored "Project" tab maps to Brief; a stored "Look" stays Look).
3. **Remove the conversation language for Clap from the interface.** No control, no label, no question, anywhere (panel, Settings, new project sheet, Wizard). Clap speaks the language and region of the Mac by default, and follows the language the owner writes in, as the model does: keep the Mac's language and region in Clap's system prompt exactly as CL1 does today, and do not add anything. If step 0 c shows that the project file or the skill's interview needs a conversation language value, the app keeps writing it implicitly from the Mac, so the skill, the file format and Clap's tools keep working unchanged (the skill stays untouched). An old stored value is ignored by the interface, never an error and never deleted from the file. **The Film languages (the languages on the screen of the reel) stay**: they are another thing and the owner did not ask to remove them. List in the report everything you removed and everything that stayed, and correct the app's row of `capabilities.json` if it described a conversation language control (if `references/portability.md` has to change, that is a skill change: release notes of the skill first, `python3 tools/bump.py patch`).
4. **Nothing else:** no change to the fields, their autosave, their validation, the Build, the skill, the Look editors' content, the Wizard's steps or the rail.

## Tests (no screen)

The tab model (three tabs, order, default choice, stored selection and restore, migration of an old stored tab, base configuration item to tab mapping, arrow-key order); every old way to open Project or Look lands on the right tab; no control or stored value for the conversation language is offered, the Mac's language still reaches Clap's prompt, an old stored value is ignored without error; every field of the old form exists in exactly one tab (a test that lists the old fields and finds each once); the project name and the compact base configuration are outside the tabs. Update the tests that assumed the two old tabs or the language control and say which.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE `python3 tools/bump_app.py` (a minor version if the stored tab value changes shape, otherwise a patch; say why); never edit a version by hand. Update docs/Claude/ux-notes.md ("Built in PT1 (date)" and what remains), ROADMAP.md if a limit is lifted, CLAUDE.md "Open work", then `python3 tools/docs_index.py --write`.

## Verification

During the work: `tools/verify.sh --fast`. At the end: the complete `tools/verify.sh`, then `tools/rebuild-app.sh` (in the batch: once at the end).

## Final report (docs/Claude/phases/PT1/report.md)

Step 0 results (including what Control level is), what was built, the name chosen for the second tab, what was removed for the conversation language and what stayed (and why), the version, what is verified and what is not (no screen: nothing drawn or felt is verified, say so plainly), and "To check by hand": the panel with its three tabs (every field of the old form present once, nothing lost), the project name and the compact Base configuration visible on every tab, a click on a checklist item going to its tab, arrow keys between the tabs, the tab restored after quitting and reopening, an older project opening on the right tab, the panel dragged wider and narrower, no conversation language anywhere (panel, Settings, new project, Wizard), Clap answering in the Mac's language and in the language you write in. Stop after the phase.
