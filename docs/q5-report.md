# Q5 report: action/reaction

## 0. What the code did before Q5

Every case where an element or an action was refused or disabled, and whether the interface showed a signal, a reason and a way out.

| Case | Before Q5 | Signal | Reason | Way out |
|---|---|---|---|---|
| A proposal of Clap waiting (card) | nothing was blocked: the user could edit the very element; accepting then failed for Clap with "project changed since the proposal" (told to Clap, not shown) | no | no | no |
| Clap working | nothing blocked; the composer turned into Stop; "Clap is busy" notice when asking again; the Build button was disabled | spinner in the chat only | partly (notice) | Stop |
| Build in progress | Build and Test it again disabled; a spinner and Stop in the Build view; every typed operation (the user's and Clap's), undo, drops and file saves still worked | partial | no | Stop (ran the checks on the half-written version) |
| Scene locked | form disabled, caption "Locked: nothing in this scene can change...", refusals as an alert, drops refused with the reason, badge menu with the reason in the item | yes | yes | yes (unlock) |
| Lock switch of a scene that is not Validated | disabled | no | caption below, not tied to the control | partly |
| No API key | Build disabled, "Writing the film needs an AI" box, composer replaced by Connect AI | yes | yes | yes |
| Project to update | banner and Library row "Outdated" with Update project; **nothing is blocked**, edits still work | yes | yes | yes |
| Resource used by scenes | no rule exists (nothing refuses it) | n/a | n/a | n/a |
| Go not available | disabled, text near it says what is missing | yes | yes | yes |
| Form buttons (Apply, Save, Revert, Add, Next...) | disabled while nothing changed or a field is empty | no | no | no |
| Menu items (Undo, Redo, context menus) | disabled | no | no | no |

Closing, quitting and what happens (read in the code):
- **Closing the window:** only `chat.endSession()` ran (a summary is written when there is a key). The agent's task kept running in the background: it went on applying changes, and a card waiting for an answer waited forever (never answered, never journaled).
- **Quitting (Command-Q):** nothing ran. The process ends: a request in flight is lost, the tokens used are not refunded, files already written stay on disk, cards waiting are lost and not journaled. The conversation is kept (it is appended to `.studio/chat` line by line); the session summary is written at the next launch that has a key.
- **A build cut off:** the version folder `vN` stays as written (project.json and the scene files so far, no `dist/`); it is not assembled or tested. The earlier versions and their `dist/` are untouched (a build always writes a new `vN`), so the film stays at its last working version. `Test it again` can run on the partial folder.

## What Q5 does about it

- `ShowreelKit/Availability.swift`: one model (`Availability`, `Unavailable` with reason, way and link, `ProjectActivity` by project root, `CloseGuard`, `StatusLine`, `BuildProgress`, `ClapActivity`). The views read it.
- One choke point: `ProjectStore.plan` refuses every typed operation while a build runs (reason "Building the film: ...", way "Wait for the end, or Cancel the build") and any operation touching an element a proposal waits on; undo, redo, transactions (files added), Update, Restore and the editor's Save go through the same refusal. Clap's `write_file` is limited to the version being built; `generate_scenes` is refused.
- The build ends in all cases with the editing open again (success, error, cancel); Cancel stops the request in flight.
- A proposal not answered when the window closes or the app quits is recorded as refused in the journal.
- Opening another project from the Library opens another window and interrupts nothing: it never warns.

## What to look at by hand

1. A card waits (ask Clap to change a scene's duration): banner at the top of the inspector ("Waiting for your answer: 1 proposal from Clap", Accept all, Refuse all, a link to the card); the scene's row in the library carries the orange mark; its inspector shows the notice and is read-only; a click on the mark or "Show the proposal" scrolls the conversation to the card and outlines it for a moment.
2. Accept: the scene lights up for about a second and the line at the bottom says "Applied: ... Undo". Refuse: the elements come back; nothing is applied.
3. Clap thinking and applying: "Clap is thinking..." / "Clap is applying changes..." in the Ask Clap header and the top bar, then "Clap is done" (or the error, or "Clap was stopped").
4. Build (needs a key and the Go): the Build view shows the progress panel (step, "Scene n of N", time, Cancel build with its explanation), the top bar shows the compact form; edit anything: the line at the bottom says "Not done: Building the film..."; elements show "Locked during build"; undo, drops, stretching in the reel and saving a file are refused the same way; looking, playing an old film and asking Clap a question still work.
5. Cancel build: editing opens again at once (a few seconds if the request is still ending), the line says what stays; the half-written `vN` is in the folder, not built.
6. End of a build: "Build done: N scenes generated, film assembled", or a readable problem; editable in both cases.
7. The alert: close the window (red button and Command-W), quit (Command-Q), and Update project or Restore backup from the project and from the Library, in four situations: a build running, Clap answering, cards waiting, nothing (no alert). Check the texts say what really happens (see above) and that "Keep working" is the default button.
8. Disabled controls: hover the storyboard review buttons on a locked scene, Save scene, Apply in the reel, Build with no key: the tooltip gives the reason and the way.
