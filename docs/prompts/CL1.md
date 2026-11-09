# Phase CL1: the conversation language comes from the Mac, not from a question

Read CLAUDE.md, then docs/ux-notes.md (the entry "Conversation language (owner, after DS1)"), docs/studio-spec.md only for the base configuration, the wizard and the interview gate, and the code: where the conversation language is stored (decisions, showreel.json), the base configuration set and its progress text ("n of 5 set"), the Wizard questions (Wizard.swift), the Manual form (ProjectSettingsForm and the creation form), the derived interview gate, `shared/addendum.md`, `shared/capabilities.json`, and what the skill's interview says about the conversation language (`references/interview.md`, `references/portability.md`). Follow every rule of CLAUDE.md (never run git, English interface, the skill is English only and style-neutral, no out-of-scope work: an idea goes in docs/ideas.md in one line). Views stay free of business logic.

## Why

The setting is redundant: Clap answers in the language the owner writes. What is useful is a sensible language for Clap's very first message (the Wizard speaks before the owner has typed) and a stored value to fall back on when unsure. So the language must come from the Mac by default and stop being a question.

## Step 0 (read-only, 8 lines at the top of docs/cl1-report.md)

a) Where the conversation language is stored, which values are allowed and which list the picker uses.
b) The five items of the base configuration, where the count "n of 5" is computed and shown, and which gates, checks, wizard steps and tests depend on the conversation language.
c) How the Wizard asks it today and how the Manual form shows it.
d) What `addendum.md`, `capabilities.json` and `portability.md` say about it, and what the skill's interview does with it.
e) Existing projects: what they hold, and what must not change for them.

## What to build

1. **Default from the system.** A pure function in ShowreelKit that maps the Mac's preferred languages (inject the list, so a test can pass any) to the first language the app supports (the same list as the picker), and to English when none is supported. It is computed once, when a project is created, and stored in the project like today. Existing projects keep their stored value and are never changed.
2. **No longer a required question.** The base configuration goes from five items to four (reel languages, formats, target duration, a look): update the count and its text everywhere ("n of 4 set"), the derived interview gate, the checks and the workspace-opening rule. The Wizard no longer asks for it (one step fewer, say it in the report). The Manual form no longer lists it among the required fields.
3. **Still editable.** A small "Conversation language" control in the project settings, in a collapsed "More" area (not among the required fields), showing the stored value and where it came from ("From your Mac" until the owner changes it). Changing it is a normal typed setting, journalled, with Undo.
4. **The instruction to Clap.** In `addendum.md` (and the places that build Clap's prompt): reply in the language the user writes in; use the project's stored language for your first message and when you are unsure; never ask for the conversation language, the app has settled it; the film's on-screen languages are a different question and are still asked. Do not change the skill's own method: only the addendum and the app rows of the portability table follow the app. If `references/portability.md` has to change to stay in agreement with `capabilities.json`, that is a skill change: release notes of the skill first, `python3 tools/bump.py patch`, never edit a version by hand.
5. **Nothing else changes.** The film's languages, the formats, the duration and the look keep their place; no new setting beyond the collapsed control; no change to the Build.

## Tests

The mapping function (a French Mac gives French, an unsupported language gives English, the first supported one wins, an empty list gives English); a new project stores the mapped value once and an existing project is untouched; the count is four and its text says so; the interview gate and the workspace-opening rule no longer wait for the language; the Wizard has one step fewer and never asks it; the collapsed control exists, shows its origin and changing it is journalled and undoable; the addendum carries the instruction and `check.py`'s agreement between capabilities and the portability table stays green. Update the tests that assumed five items and say which.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE tools/bump_app.py (and RELEASE-NOTES-SKILL.md before tools/bump.py if the skill changed); never edit a version by hand. Update docs/ux-notes.md ("Built in CL1 (date)"), ROADMAP.md and CLAUDE.md "Open work".

## Verification

During the work: tools/verify.sh --fast. At the end: the complete tools/verify.sh, then tools/rebuild-app.sh.

## Final report (docs/cl1-report.md)

Step 0 results, what was built point by point, the version(s), what is verified and what is not (no screen, no paid call: Clap's real behaviour is not verified), and "To check by hand": create a project on a Mac set to French and to another language (the stored value, the origin text), the progress now says "n of 4", the Wizard has one step fewer and Clap's first message is in the right language, the collapsed control changes the language with Undo, Clap still answers in the language you write in when it differs from the stored one. Stop after the phase.
