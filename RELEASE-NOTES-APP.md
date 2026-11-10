# Release notes: Showreel Studio

What each version of the Showreel Studio app changes for you, newest first. The short register that the repository checks is `CHANGELOG-APP.md`. The skill built into the app has its own notes in `RELEASE-NOTES-SKILL.md`. The version of the app and of its skill are shown in About Showreel Studio (the app menu).

## 0.21.3 - 2026-11-10

**Fixed**
- A thumbnail capture that is slow to start no longer fails because of an older capture's timer, and a timeout is no longer remembered as the scene's failure: the frame is tried again.
- Holding a stepper arrow stops when its field disappears (the scene changes, the tab closes).
- Two projects that use a font of the same name over different files each get their own font in previews.
- Closing a project stops its pending thumbnail captures; one still running is dropped instead of being written into the closed project.

**What you need to do**
- Nothing.

**Compatibility**
- Projects open unchanged. The skill is unchanged.

## 0.21.2 - 2026-11-10

**Changed**
- Internal clean-up only: the compiler warnings of the app went from 21 to 4. Nothing you see or use changes.

**What you need to do**
- Nothing.

**Compatibility**
- Projects open unchanged. The skill is unchanged.

## 0.21.1 - 2026-11-10

**Fixed**
- **Blank thumbnails in the Storyboard strip.** On a project that already had a built film, every frame showed a dark picture: the hidden window that takes the pictures was off screen, and in such a window the film never draws. It now sits (almost transparent, deaf to the mouse) in the corner of the screen, and a picture is taken only once the film's own clock shows the moment asked for. If the film does not draw, the frame says so with the reason instead of showing a dark picture.
- The pictures taken by 0.21.0 are not trusted: they are taken again by themselves a moment after the project opens (or with Refresh thumbnail).
- Hovering a frame now says what its picture is (captured from the built film, out of date and why, or why there is none).

**What you need to do**
- Nothing. Open a project that has a built film and wait a few seconds.

**Compatibility**
- Projects open unchanged. The skill is unchanged.

## 0.21.0 - 2026-11-10

**What's new**
- **Thumbnails are the real scene.** In the Storyboard strip and in the scene's inspector, a scene's picture is now a PNG captured from the built film itself, at one representative moment of that scene, instead of a drawing made from its content. Pictures are kept in the project's hidden `.studio/scene-thumbs/` folder and never change the film.
- **Always says what it is.** Before a film is built, or while a scene is not written yet, the frame shows a plain placeholder with the scene's ID, length and first words, and why there is no picture and how to get one (Build). A picture that no longer matches the scene wears a clock mark and a tooltip that says what changed. If a capture fails, the placeholder shows the reason.
- **Refresh thumbnail**, in the frame's menu and in the scene's inspector. It says why it cannot run (a build is on, nothing is built yet, the picture is already up to date, or the scene changed after the last build and only a build can update it).
- Pictures refresh by themselves after a build and after a short quiet moment (1.5 s), one scene at a time, never while a build runs. A scene that is deleted takes its picture with it.

**Changed**
- A frame no longer shows several small pictures of a scene, nor the "AI decides" mark. The viewer keeps drawing a scene from its content when no film is built.

**What you need to do**
- Nothing. Build the film once to get the pictures.

**Compatibility**
- Projects open unchanged; older ones have no `.studio/scene-thumbs/` until a capture. The skill is unchanged.

## 0.20.1 - 2026-11-10

**Fixed**
- **Crash while resizing the window** (`unrecognized selector windowDidResize:`, seen with the green zoom button, a double-click on the title bar or tiling). The guard that asks before closing a window with work in progress could lose the window's own delegate and then fail on the next resize. It now keeps it, never stacks a second guard on the same window, and gives the window's delegate back when its view goes away. Closing still asks as before.

**What you need to do**
- Nothing.

**Compatibility**
- No change to projects. The skill is unchanged.

## 0.20.0 - 2026-11-10

**What's new**
- **Timing inside a scene.** Each element of a scene (words, image, sound) has a timing: in the Composition tab, "Timing in the scene" is Auto (the AI decides, as before) or Fixed, with In and Out in seconds from the start of the scene. A value outside the scene is refused with its reason and nothing is written; a locked scene refuses with the reason of the lock; Undo takes the edits of one field in two seconds back as one step.
- **Elements follow the scene's duration.** When a scene gets shorter, an Out past the new end is pulled back to it; when it gets longer, an Out that was the end follows. The card of the change lists the elements that moved.
- **Pictures drawn from the content.** The picture of a scene, in the Storyboard strip and in the viewer, shows what the content says at a time: the words, the colours of your palette, the images of your resources, only the elements on screen at that moment. A colour or an animation left to the AI is drawn neutral and marked "AI decides": the app never invents what the AI has not produced.
- **One thumbnail per scene**, and several only when the scene's elements really come and go at different times and the frame is wide enough.
- **With nothing selected**, the viewer follows the playhead and shows the scene under it at the right moment of that scene.
- `storyboard.md` and the message sent to the AI at Build carry each element's timing.

**Changed**
- A scene that has content is no longer drawn with the engine's stand-in effect: the viewer shows a picture at a time, not an animation. A scene with no content keeps the stand-in.

**What you need to do**
- Nothing.

**Compatibility**
- Projects open unchanged: `in` and `out` are optional fields of an element, written only when you fix a timing. An older version of the app keeps them without reading them. The skill is unchanged.

## 0.19.3 - 2026-11-10

**What's new**
- **Nothing changes in how the app works.** This release only updates comments in six source files (and the app's README) so that they name the new place of the project's specification, `docs/Claude/studio-spec.md`, after the documentation was reorganised. No behaviour change, no new setting, no change to your projects.

**What you need to do**
- Nothing.

**Compatibility**
- Projects and skill are unchanged.

## 0.19.2 - 2026-11-10

**What's new**
- **The rail's buttons behave the same way.** Film and Build never switch off: clicking the active one does nothing, and the other one is the way back (Build used to return to the Film, Film did not). Inspector, Look, Project and Clap open on a click, replace each other, and close when you click the open one again.
- **Clap opens when something asks for it.** Starting a Build, "Draft scenes" and the link from a blocked element to its card now show Clap's conversation even when Look or Project covered the right side or the side was closed. Before, nothing visible happened in that case.
- **The Inspector's dot** (a selection is waiting) no longer stays on the Inspector when it is open.
- **Every rail button has the same states:** hover, pressed, selected, a focus ring for the keyboard, and the badges that apply. The change is instant when Reduce motion is on.
- **Tooltips** show the name, what the entry does and its shortcut (Shift-Command-A for Clap). Tab reaches the six buttons, the arrow keys move inside a group and wrap, Space and Return activate.

**What you need to do**
- Nothing.

**Compatibility**
- Projects and skill are unchanged.

## 0.19.1 - 2026-11-10

**What's new**
- **One text field style.** The text fields of the inspector, the project form, the Look editors, the resources, the history and the file editor fill the width of their pane and share one height and one corner radius, with an accent ring when focused, a red ring and a message when a value is wrong, and a dimmed look when disabled.
- **Multi-line fields grow with their text** (from two lines up to eight) and show a scroll bar only when there is more to scroll. They show an example of what to write when empty.
- **Up and Down work in the Duration fields** while they have focus, as the chevrons do: Option steps by 0.1 s and Shift by 5 s.
- **Buttons have roles.** Seven buttons that used the default grey look and about thirty action buttons in the build view, the resources, the Look editors, the packages, the set-up screen, the Clap cards and the library are now primary (the main action), secondary, destructive (Cancel build) or quiet (links such as Not now and Back to the viewer).

**What you need to do**
- Nothing.

**Compatibility**
- Projects and skill are unchanged.

## 0.19.0 - 2026-11-10

**What's new**
- **Real tabs.** The scene inspector (Settings, Composition, Look), the settings pane (Project, Look) and the Clap panel (Conversation, Memory, Sessions, Journal) use underline tabs: the active tab in primary text with an accent underline that moves between tabs, a hairline under the bar, a hover state, the arrow keys, and VoiceOver announcing the selected tab. Under Reduce motion the underline changes without moving. Segmented controls stay for real choices of a mode (Edit and Preview of a file).
- **The Effects tab is gone.** The animation of each item is chosen in the Composition tab, in the item's own row (with its help as a tooltip on the control). Nothing in your projects changes.
- **Numeric fields have a stepper.** The scene's Duration and the project's custom target duration have up and down chevrons at the right end of the field: click, hold to repeat; Option steps by 0.1 s and Shift by 5 s. Values are rounded to a tenth of a second, and a typed value out of range is clamped with a message, never silently.
- **The State section is simpler.** Visible, Ready and Locked share one left edge for the icons and labels and one right edge for the switches, and there is no Instruction field any more: ask for a change by editing the scene's fields or by talking to Clap. A note already stored on a scene stays, shown read-only under the switches ("Earlier note: ..."). "Delete scene..." has the destructive style.
- **No Duplicate button for a scene** in the inspector, the context menus, the Storyboard list or the Film strip. Duplicating a content item stays.
- **Project button.** The header of every inspector (scene, transition, resource, look element) has the same quiet "Project" button, which opens the Project panel exactly as the rail does.
- **Wider panes.** The Inspector opens at 440 pt and the Project and Look panes at 620 pt by default, and can be dragged up to 720 and 900 pt. The reset icon puts the standard widths back.
- **Chips and colours.** The 30 s to 90 s choices are chips with selected, hover and disabled states. The inspector, the forms, the Clap panel and the Settings window take their colours from the design tokens.

**What you need to do**
- Nothing.

**Compatibility**
- Projects and skill are unchanged. Clap can still set a scene's note and duplicate a scene with its tools.

## 0.18.0 - 2026-11-10

**What's new**
- **No Save button: what you type is saved.** The scene inspector's Settings and Composition fields (Duration, Feeling and tension, Passage to the next scene, the scene note, the on-screen text and the linked resources), the palette editor, a scene's content items and a transition's timing and parameters save themselves. A text field saves when you leave it, on Return, or when you stop typing for a moment; a duration saves when you leave it or press Return; a switch or a resource link saves at once. The **Save scene**, **Revert**, **Save palette** and **Apply** buttons are gone.
- **Undo is the way back.** Several saves to the same field within two seconds are one Undo step, so Command-Z takes back what you typed in that field, in one press, and Shift-Command-Z puts it back. While you are still typing (before the save) Command-Z undoes your typing in the field as before.
- **You see every save.** A small "Saved" mark with a check appears next to the field and fades after a moment. When a save sends a validated scene back to To review, the status line says so once, with Undo, and the Status icon changes. If a change is refused (a locked scene, a Build in progress, an invalid duration) the field shows why next to it, keeps what you typed, and nothing is lost; a locked scene's fields are disabled with the reason.
- **Changes made elsewhere.** If Clap or Undo changes a field you are not editing, it updates and shows a quiet "Updated". A field you are typing in keeps your text, and your save wins.
- Selecting another scene, switching a tab, closing the pane or the window, or starting a Build saves what is pending first.

**Kept explicit**
- Creating a project, the confirmation cards (Build, Generate, a look change on locked scenes), Clap's proposals, saving or importing a package, the rights question, deleting a scene, and the API key in Settings still ask you to confirm.

**What you need to do**
- Nothing.

**Compatibility**
- Projects and skill are unchanged.

## 0.17.1 - 2026-11-10

**Fixed**
- Clicking a scene in the Storyboard list now also moves the preview to it, as a click on a frame of the Film strip does. The same goes for a "Used in" scene chip in the Resources and a check or a reason that names a scene. A scene that is hidden from the film is selected and the preview stays where it is; while the film plays, it jumps to the scene and keeps playing. A new scene is shown as well as selected. Selecting on the strip scrolls the Storyboard list to the row.

**What you need to do**
- Nothing.

**Compatibility**
- Projects and skill are unchanged.

## 0.17.0 - 2026-11-10

**What's new**
- **The interface answers.** One motion language, defined once: three durations (about 120, 200 and 300 ms), a decelerating curve for what arrives, an accelerating one for what leaves, a small overshoot for confirmations, and the spring of the sliding panes (Look, Project, Clap) as a named value they all use, with the same bounce as before. Nothing you do lasts more than about 300 ms, and nothing blocks your input while it moves.
- **Where it shows.** A scene's Status icon pulses once when it changes; the eye and the lock cross-fade; a control that refuses (a locked scene) gives a small nudge, with the reason in the status line as before; a new scene arrives into its place in the Film strip and a deleted one leaves it; a selected transition diamond pops a little; during a Build each scene's row and frame show its step by a different icon and label (waiting, writing, testing, repairing, failed) and settle into the usual Status icon when the scene is done.
- **Reduce motion** (System Settings, Accessibility, Display) turns every movement into a short fade or nothing; the icons and labels still say what happens.
- **The Film strip is less cluttered.** The picture of a scene stays inside its own frame, cropped from the left, and never draws into the next frame. A frame tall enough has a header band (label and Status icon) and a footer band (duration) that the picture does not cover, so large text in a scene picture no longer sits under them. Short frames look as before.

**Changed**
- The Film strip and the Storyboard list take their colours from the design tokens (same values, nothing looks different apart from the bands above).

**What you need to do**
- Nothing.

**Compatibility**
- Projects and skill are unchanged.

## 0.16.0 - 2026-11-10

**What's new**
- **The rail has two groups**, with a thin line between them: the centre views (**Film**, **Build**) and the right panels (**Inspector**, **Look**, **Project**, **Clap**). A centre view and a right panel are independent: choosing Film or Build never closes a right panel, and opening a right panel never changes the centre.
- **Clap is an entry of the rail.** Its icon pulses while Clap works (a dot under Reduce motion) and carries a badge with the number of proposals waiting for you; the tooltip and VoiceOver say the same ("Clap, working", "Clap, 2 proposals waiting"). Its panel slides in from the right like Look and Project, with the conversation and, as tabs inside it, Memory, Sessions and Journal. **Shift-Command-A** opens Clap and puts the cursor in its input from anywhere in the project window.
- **One right panel at a time.** A click on the open panel's entry closes the right side. A selection shows in the Inspector when no other panel is open; otherwise the open panel stays and the Inspector entry gets a small mark. The panel that was open is remembered for each project (a project with no choice opens with the Inspector).
- **The shell uses the full height.** Under the top bar, the rail, the left panels (Storyboard on top, Resources below) and the right panel each take the whole height; the preview and, under it, the **Film** strip (the timeline) share the centre column. The strip is now titled Film; the left list stays the Storyboard. When the strip is the width of the centre column its toolbar has two rows.
- **Film placement.** A new button at the right end of the top bar (after the Checks badge and the Catalogue) switches the Film strip between "under the preview" and "full width" (along the whole bottom, from the left panels to the right panel). Its pictogram shows the layout in use, its tooltip names the state and the action ("Film under the preview. Click for full width"); the panels move with the spring. The choice is remembered per project.
- **The sizes you drag are yours.** The widths, the Film height and the Storyboard and Resources divider are stored apart from the placement and never changed by it; in a small window they are only clamped for drawing, and come back when the window grows. The window cannot be smaller than the shell needs. A new reset icon next to the placement button puts the standard proportions back (it replaces the old "Reset layout", which did the same), keeps the placement, and says why when the proportions are already standard.

**Changed**
- The right panel no longer has the Inspector and Ask Clap tabs. With the Advanced setting on, the Inspector panel keeps a Files tab.
- Choosing Film or Build no longer closes the Look or Project panel (the rail is no longer exclusive).

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.2. macOS 13 or later.

## 0.15.0 - 2026-11-10

**What's new**
- **The conversation language is no longer a question.** A new project takes the language of your Mac (the first of its preferred languages that the app supports, English if none): Clap writes its first message in it, then answers in the language you write in. The base configuration is now four things (film languages, formats, target duration and a look): "n of 4 set". The Wizard has one question fewer, and the Manual form no longer lists it among the required fields.
- **Still editable**, in Project settings, Project tab, under a collapsed "More": the Conversation language, with where it came from ("From your Mac" until you change it, then "Set by you"). Changing it is a normal setting: journalled, with Undo.

**Changed**
- Clap is told never to ask which language to talk in; the film's own on-screen languages are still asked.
- Projects that already exist keep their stored language and are never changed.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.2. macOS 13 or later.

## 0.14.1 - 2026-11-10

**What's new**
- Nothing new.

**Fixed**
- **The "Design package" footer no longer floats over the project settings form.** In the Project and Look tabs of the project settings, "Design package" and the "Save design as package..." button now sit under the last section, with the same margins as the form, instead of landing on top of the text under "Film languages".

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.2. macOS 13 or later.

## 0.14.0 - 2026-11-10

**What's new**
- **A dark editor look with its own identity.** Graphite surfaces, hairline borders, rounded panels and one teal accent for the selection and the one main action. Every window is dark, Settings included (there is no setting for it yet).
- **A view rail at the left of the workspace**: Film, Look, Build and Project, each with an icon and a short label; the selected one is lit. It does what the Build and Project settings buttons of the top bar did, and those two buttons are gone from the top bar (during the first project setup, the Project settings button is still there). Look opens the project settings on the global look, with the design board in the centre; Film brings back the viewer.
- **The regions are rounded panels one gap apart**, and the dividers are those gaps (they show under the pointer). The right panel's two tabs, Inspector and Ask Clap, are segmented tabs.
- **One set of design tokens** decides every colour, radius, space and text size (the six Status colours of a scene keep their meaning). The text colours and the Status colours are checked for contrast on the panel surfaces.
- **No text under 11 pt.** Every small text (captions, notes, counters) is now 11 pt, the small style.

**Changed**
- The toggle switches and the main buttons use the new styles; the lists and the strip keep their structure and are only moved to the dark surfaces where it was a plain swap. The strip, the lists, the inspector and the forms are redrawn in the next two phases.
- Choosing Film or Build on the rail closes the project settings panel (the rail shows one place at a time).

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.2. macOS 13 or later.

## 0.13.0 - 2026-11-09

**What's new**
- **One Status icon per scene, the same on the list and on the strip.** Six states, worst first, and the tooltip lists every one that applies, with the reason and the way to fix it: Needs attention (red, the scene's code test failed), Not written (grey dashed, no file yet), Out of date (blue arrows), Layout warning (yellow triangle), To review (orange hammer, with your instruction in the tooltip) and Ready (green check, Ready and its file up to date). A "?" above the list explains them.
- **Clear scene rows.** Handle, ID, the name (and the first words under it), the length rounded to 0.1 s, then three fixed columns: Status (read-only), Visible (the eye) and Locked (the lock), both click targets that say why when they refuse. The transition line is indented under the scene it leaves, joined by a thin connector: "Flip card \u00b7 0.55 s", "Cut".
- **Three switches in the inspector: Visible, Ready and Locked,** and a **Delete scene** button at the bottom. Ready means you are satisfied; off means To review, and the scene's instruction says what to change. Only a Ready scene can be locked ("Make the scene Ready first"). Delete scene asks first, names what is lost, can be undone and is journalled; the scene's ID is never given again.
- **A real lock.** A locked scene is frozen in time and space, visible or hidden: no change to its content, look, length, visibility, place or deletion, and no change elsewhere that would move its start (inserting, deleting, showing, hiding or lengthening a scene before it): "S07 is locked at 0:24: unlock it, or change a scene after it". A Build never rewrites it (it is listed as locked on the card), nor Generate or Fix this scene.
- **Locking keeps a copy of the scene's look.** A change of the project's look no longer reaches a locked scene and the "apply anyway" card no longer lists it. Unlocking drops the copy; when it differs from the project's look the unlock card says so.
- **Clap proposes, you decide.** `set_ready` and `delete_scene` are always cards, even with apply-directly; Clap can no longer set a scene's state through update_scene.

**Changed**
- "Validated" is called **Ready** and "WIP" **To review** everywhere you read them (the stored words are unchanged: no migration).
- The Go reads "every visible scene is Ready": a locked scene is Ready, a hidden scene is ignored.
- OK, MODIFY, DITCH and Archive are gone. A scene archived or ditched in an older project is a hidden scene under "Not in the storyboard" (with a note of what it was); showing it brings it back.
- A scene locked before this version keeps following the project's look until it is unlocked and locked again.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.2. macOS 13 or later.

## 0.12.0 - 2026-11-09

**What's new**
- **The left panel is the Storyboard, with the Resources below.** No more tabs for Resources, Scenes and Transitions: the Storyboard (the plan of the montage) takes about two thirds of the panel and the Resources the rest, so a resource and the scene it goes to are always in sight. Drag the divider; its place is remembered for each project. The Resources can be collapsed to their header, or expanded to the whole height (and restored).
- **A flat Storyboard list.** One row per scene, in order, with one thin line between two scenes for the transition ("to Cross dissolve, 0.8 s", "to Cut"), keeping the "approximate render at assembly" and "instruction pending" notes. Click a scene to select it everywhere (list, strip, inspector); click a transition line to select its marker on the strip and open its inspector. Drag a row by its handle: the scene moves with its outgoing transition. Under the list, "Not in the storyboard" shows the scenes that are switched off or archived, with the reason and the way back.
- **State icons on each row, nothing else.** After the ID and the name: review state (to review, approved, to modify), locked, build state of the scene's file (not generated, up to date, stale, edited by hand, failed its test) and layout warnings, in that order, at most four. Each has a tooltip with the reason and, when something needs attention, the way to fix it.
- **The scene's tree is the Overview in the Inspector.** What the tree showed (composition elements in order, effects, look with what is inherited or replaced) is at the top of a scene's inspector; a click on a line opens the matching tab on that element, and a resource dropped on the Overview goes to the scene.
- **Checks are a badge in the top bar** ("Checks 3", red or orange, or plain "Checks" when nothing needs attention). A click opens the list in the centre, grouped as before (Project, Resources, Scenes, Storyboard, Music, Build), and a click on a check goes to what it is about.
- **Keyboard.** With the pointer over the Storyboard list, the up and down arrows move between scenes (as the strip's arrows do) and Delete switches the selected scene off (Undo brings it back).
- A resource can be dropped on a row of the Storyboard, on a frame of the strip or on the Overview of the inspector. A locked scene refuses it with its reason; during a Build everything is refused with its reason.

**Changed**
- The Transitions tab is gone: its lines are in the Storyboard, and the transitions to drag are in the Catalogue (Shift-Command-K).
- The look-override badge of a scene is no longer on its row: it is in the Overview, under Look.
- The strip's and the list's selection are one and the same.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.2. macOS 13 or later.

## 0.11.0 - 2026-11-09

**What's new**
- **The API's "busy" answers are waited out.** A 429 (rate limit), a 529 (overloaded) or a 5xx that the API marks as retryable no longer stops the Build: the app waits the time the API gives in `retry-after` (else 5 s, doubled each time, at most 2 minutes) and asks again, up to 5 times. The panel says "Waiting for the API, retry in 20 s (2 of 5)" and counts down; the journal has a line per attempt with the status and the kind. A lost connection and a busy API share one counter per scene, so a scene never costs more than a few requests. Any other answer (a 400, a 401...) is not asked again and keeps the API's own text. Cancel ends a wait at once, and the time limits of a request do not run while the app waits.
- **Scenes written at the same time.** Settings, Advanced: "Scenes written at the same time", 1 to 4 (3 by default). The frame of the film is written first and alone; then the scenes run in a sliding window, a new one starting as soon as one is done. The film is assembled in the order of the storyboard, whatever the order the files arrived in. Each request now also gets one line per scene of the whole storyboard (words, length, mood, passage into the next scene), because a scene written together with its neighbours cannot see them.
- **When the API limits requests during a parallel Build**, the number at once goes down by one for the rest of that Build ("Lowered to 2 scenes at once: the API is limiting requests"), never below 1.
- **A scene that fails does not stop the ones being written.** The Build ends after them and offers "Continue vN". Cancel stops every request in flight; what is already written (and tested) is kept.
- **The panel shows several scenes writing at once**, a bar that moves at each file, and two times: the real time and the writing time added up.
- **The confirmation card has a time**: "about 6 min at 3 scenes at once (118 output tokens a second, measured on the last Build)". It starts from 125 tokens a second and 7 000 tokens a scene, then uses what the last Build measured (recorded in the journal after each Build). Always an estimate.

**Changed**
- Scenes written together cost a little more (each call repeats the scene contract) and cannot see each other's result; one at a time (set 1) is as before.

**What you need to do**
- Nothing. Set "Scenes written at the same time" to 1 to write one scene at a time as before.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.2. macOS 13 or later.

## 0.10.3 - 2026-11-09

**What's new**
- **Every request has a time limit that a keep-alive cannot extend.** A request is cut when no text or tool argument arrives for 120 s, even if the API keeps sending its pings ("No content from the API for 120 s on S04, only keep-alive pings"), and when it lasts longer than 8 minutes ("Request exceeded 8 min"). The 8 minutes are a setting (Settings, Advanced, "Longest request (minutes)"). A stream that closes before the API says the answer is complete is a lost connection, no longer a finished answer.
- **A cut request is asked again by itself**, up to 2 more times, with a short wait: the panel says "Connection lost on S07, retrying (1 of 2)" and the journal has a line per try. A request writes nothing until a scene is complete, so asking again only costs the request. After the tries the scene fails and the Build ends on "Continue vN".
- **The Build leaves a trail.** The journal and `~/Library/Logs/ShowreelStudio/build.log` have a line for the start of the Build, the start and the end of each request (seconds, bytes, content tokens, pings, stop reason, cause), each retry, each Cancel (and who asked: the button, closing the window, quitting) and the end.
- **The panel says what is really happening.** While a scene is tested it says "Testing S04" with the time, no longer "Preparing" with a frozen counter; a request that is alive but quiet says "no data for 25 s".
- **One rule for "tested".** A scene is taken over from an earlier version only when its own record says it passed its test. "Generate" and "Fix this scene" now test the scene after writing it and record the result, like the Build. A scene that was never tested (for example one that was generated before this version) is tested again at the next Build, with no request, and written only if the test fails.
- **The card gives the true reason for each scene**: "its content or look changed", "the brief or the music under it changed", "never tested: tested now, no request", "the previous build was not reliable: tested again, no request", "its test failed", "edited by hand", "never written".
- **The frame of the film is tested once, before any scene.** A defect in reel.js stops the Build there, with its own error, instead of making every scene fail.
- **Continue from the "Build stopped" alert shows the same card** as the Build tab (what is written, the calls, the cost) before it asks anything.

**Changed**
- Cancel during the last scene's test no longer goes on to assemble the film. Cancel now also stops a generation that Clap started, and any command the app runs (the tests, the assembly) is stopped when it is cancelled or when its time is up (SIGTERM, then SIGKILL after 3 s).
- After a stop, the layout warnings of the scenes already written are kept and listed.
- Folders of Builds that stopped before writing anything but film.json (v1 to v4 in some projects) are removed when the app opens the project and when the next Build starts.
- The old one-message Build brief is gone (only self-tests read it).

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.2. macOS 13 or later.

## 0.10.2 - 2026-11-09

**What's new**
- **A Build writes only the scenes that changed.** A scene whose file is up to date (nothing it was written from has changed: its content, its look, the brief, the music under it) and that passed its test is copied from the previous version, with no request. A locked scene is copied too. A scene that changed, was never written or failed its test is written. Changing one word in one scene now costs one request, not fifteen.
- **The card says it plainly**: "Build v6: 1 scene will be written, 14 reused unchanged (2 locked)", with the calls, the cost and the time for the written scenes only. When nothing changed it says "Nothing changed since the last build" and offers only **Assemble** (free): it puts the montage, transitions and music as they are now into the film.
- **A scene you edited by hand** that is out of date is kept as it is unless you tick it on the card (like Generate).
- **Rewrite everything**, with its own confirmation and its cost (all the requests), writes every scene that is not locked again, and the frame of the film. A Build that continues after a stop keeps that choice.
- The frame of the film (project.json, reel.js) is reused too when what it is written from is unchanged.
- The journal has one line per scene: "S05 written" or "S03 reused from v4".

**Changed**
- If the scene contract changed since a scene was written, the card says so ("2 reused scenes were written under an older contract") but does not rewrite them by itself: they passed their test. Rewrite everything applies the new contract.
- The first Build after this update writes the frame again (older versions did not record what it was written from).

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.2. macOS 13 or later.

## 0.10.1 - 2026-11-09

**What's new**
- **Each scene is tested right after it is written.** The skill's own logic test runs on that one scene (no AI, no cost) the moment its file is saved. The scene's line in the Build panel goes through "testing", then "done" or "failed (test)". The scenes are tested one after the other as the Build goes.
- **A scene that crashes is rewritten once, automatically.** A code error (an exception, a scene that does not load, a value that is not a number) sends Clap the exact error, the scene and its file, with a request to write that scene only: the panel says "repairing". Never more than one rewrite per scene and per Build. If the second try fails too, the scene is marked "failed (test)" with the error and left as an empty frame, the Build carries on with the other scenes, and it ends with "Continue" (Try again writes the scene again, Continue the build leaves it aside).
- **The contract Clap is given says the exact form of the engine's names.** `ease` is an object of functions (`ease.out3(t)`), never `ease(t)`; the list comes from the engine's own file when the request is made, and a test compares it with the engine as it really is. This is the error that stopped a scene of the trailer on every frame.
- **Layout warnings are listed, not repaired.** Text over text or outside the screen is a matter of taste, so nothing is rewritten by itself. The panel counts them per scene, the end of the Build says "3 scenes have layout warnings" with **Show them**, and each scene there has **Fix this scene**: one new generation of that scene with the warnings as its instruction, after a confirmation card (a locked scene cannot be fixed).
- **The final test no longer drowns you.** It reports "0 code errors, 6 layout warnings" instead of "66 issues", and the layout warnings appear as an orange note, not as a failed test.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.2. macOS 13 or later.

## 0.10.0 - 2026-11-09

**What's new**
- **"Build a new version" writes the film one scene at a time.** It used to ask Clap for all the scenes in one answer: minutes of silence, everything lost on a cut. Now one request writes the frame of the film (project.json, reel.js), then one request writes each scene, each file saved the moment it is written, then the app assembles, builds and tests the film with no AI. A confirmation card first says how many requests, which files, and a rough cost. Locked scenes keep their file from the earlier version, with no request.
- **Each request is given what it needs**: the scene file's contract and the engine's helpers (read from the skill, so they cannot drift), the scene's content and look, the music under it, its neighbours and transitions, and a short summary of the scenes already written. Clap rarely has to read the engine again.
- **A panel that tells the truth.** "Scene 4 of 15", one line per step (waiting, writing, done, failed) with its tokens and time, the total, and what Clap is doing: Reading, Preparing (nothing received yet) or Writing. The token count includes the scripts Clap writes as tool arguments.
- **No more silent hangs.** If the API sends nothing for 90 seconds (Settings, Advanced, "No-answer timeout"), the request is cut and the message says "No answer from the API for 90 s" with the scene.
- **A Build that stops can continue.** After Cancel, an error or a timeout, the scenes already written stay. The button says "Continue", picks up at the first missing scene, and the alert offers "Try again" or "Continue the build" (leaves the failed scene as an empty frame). "Start over" asks first.
- "Generate" shows the same per-scene states.

**Changed**
- Clap no longer receives one big build message in the chat: the app runs the requests itself and says in the chat that the Build started and, if it stops, why.

**What you need to do**
- Nothing. Give the Go and press the Build button; the card shows the cost first.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.1. macOS 13 or later.

## 0.9.3 - 2026-11-09

**Changed**
- **No limit on Clap while the app is a prototype.** Clap's answers, in the chat, in a Build and in "Generate", now use the most the model accepts (128 000 output tokens for the default model) instead of 8 000, and the steps of a request are bounded only by a guard of 1 000 against a loop. The size that grew with the scenes in 0.9.2 is gone: one behaviour everywhere. If a model you chose allows less, the API says how much and the app asks again once with that value; if the API still refuses, the message names the error and the value asked.
- **The Build panel shows what the request costs as it runs**: "Step 7, about 12 400 output tokens", updated while Clap writes (an estimate between the API's exact figures). **Cancel build** stays, and is now the way to stop a loop: a Build that loops costs until you cancel it.
- If an answer is still cut by the model's maximum, the message says so, with the number, and offers "Generate the scenes one by one".

**What you need to do**
- Watch the counter on a long Build, and cancel if it climbs without scenes appearing.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.1. macOS 13 or later.

## 0.9.2 - 2026-11-09

**Fixed**
- **"Clap did not write v2" now says why.** A Build whose agent stopped without writing the version used to end on an alert that sent you to a chat that said nothing. The agent stopped quietly when an answer reached the output cap (8000 tokens): a long Build writes a file per scene, and a tool call cut in the middle was dropped without a word. The alert, the chat and the project's journal now name the cause: the output limit (with its size), the steps limit, a refusal, an empty reply, an error of the API (with its code) or an answer with no file. A cut tool call is never run and never kept.
- **A Build of a long film gets more room.** The output cap and the number of steps grow with the scenes (a film of 15 scenes gets 32000 tokens and 100 steps), up to a ceiling that is never removed. A question to Clap keeps the usual size.
- **A way on after each stop.** "Try again", and, when the limit was the cause, **Generate the scenes one by one**, which asks Clap for one file per answer. Nothing stays frozen, and a version folder that holds only what the app wrote (film.json) is removed, so the next Build reuses its name instead of piling up empty versions. What Clap did write stays, and the message says so.
- **The journal** gets one line per stopped Build ("Build v2 stopped: token-limit") with the message.

**What you need to do**
- Nothing. If a Build of the trailer fails again, the message tells you why.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.1. macOS 13 or later.

## 0.9.1 - 2026-11-09

**What's new**
- **A film with 3D scenes says what the test could not see.** The Build adds an orange step "3D scenes": "This film has 3D scenes. The logic test cannot draw them: play the film to look at them. No MP4 export for this film." The logic test stays green for what it checks, and the step is a note, not a failure: it blocks neither the build nor the verification. A film without 3D has no such step. When every check passed but a step is orange (3D, or a font with no file), the message says "Build done, with a note" instead of "finished with a problem".
- Clap knows that such a film is not tested by the harness and has no MP4 export, never promises the MP4 for it, and offers 3D only when depth is the point of a scene.

**Fixed**
- **The player test no longer fails on a 3D film** (it reported a script error that came from the test host having no WebGL: this was fixed in the skill, 0.18.1).

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.18.1. macOS 13 or later.

## 0.9.0 - 2026-11-09

**What's new**
- **The music's grid on the storyboard.** When a track is attached and analysed, a discreet grid appears over the frames at the snap level you chose: beats, bars (stronger), sections and drops. Lines thin out as you zoom out so they never crowd, and they never cross a scene's label, duration or state, or a transition marker. The music lane shows the beats, the bar numbers, the sections with their name and the drops, with the instant of a drop in its tooltip. While you drag the edge of a scene or a cut with snapping on, the target line lights up and a label tells where it will land ("Bar 5, beat 1, 0:12.4"). A **Grid** button in the storyboard bar shows or hides the grid (remembered for the project), and when music is attached but not analysed, **Analyse the track** runs the analysis (it never runs by itself).
- **A Transitions tab in the left panel**, between Scenes and Checks. It lists the film's transitions, one row for each pair of scenes ("S01 to S02: Push, 0.6 s", or "Cut"), with a note on those drawn approximately at assembly and on a free instruction not yet read. A click selects the marker on the storyboard and opens its inspector. Under the list, the catalogue of transitions is a source to drag onto the markers; the six that only run as previews are marked and refused with their reason.

**Fixed**
- **A scene taken out of the film can be dragged back.** Its chip under the strip, like the rows of the transitions and of the look's catalogues, was a button, and a button takes the press so a drag never started. They now drag from anywhere on the row.
- **One thumbnail per frame**, never repeated.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.17.0. macOS 13 or later.

## 0.8.5 - 2026-11-09

**Changed**
- **The font cards show Google Fonts and need no network.** "Add the font files" and the question before a Build list the source (Google Fonts), the licence (the font's own), the files and the total size from the skill's list, so the card appears at once and offline. The network is used only after you accept.

**Fixed**
- **Downloading fonts no longer depends on GitHub's limit for anonymous requests.** The files come from Google Fonts' open repository by their exact path, or from Google Fonts' own download list when the repository does not hold a file by that name. Every file is checked (present, not empty, a font, and the size the list gives) and nothing is added unless all of them arrive. If it fails, the message gives the code and the address, and "Try again" and the font's page stay.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.17.0. macOS 13 or later.

## 0.8.4 - 2026-11-09

**Fixed**
- **Dragging a resource no longer blocks the Resources panel.** A drag now ends in one place whatever happens (dropped, refused, outside any target, cancelled with Escape) and leaves nothing behind. The drag carries the same plain-text token as the handle of a scene, which works, and no longer carries an extra type of its own. The small pictures of the rows and of the drag preview are read once in the background and kept in memory, so starting a drag reads no file. The open hand under the pointer is set, not stacked.
- **The drag log can no longer hold the app.** It is written in the background and a write error is ignored. It now also says how each drag ended and whether any target ever saw it.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.8.3 - 2026-11-09

**What's new**
- **Add a resource to a scene without dragging.** Right-click a resource: "Add to scene" lists the scenes of the film (a locked scene is greyed with its reason; an archived scene is not offered) and, for a music file, "Use as the project's music". In the inspector of a resource, "Use in a scene..." opens the same choice. The result is the line at the bottom ("Linked X to S03") with Undo; during a build everything is greyed and says why.

**Fixed**
- **Dragging a resource from the Resources tab now starts.** A row was a button, and a button takes the press for itself, so no drag could begin from it. The whole row now drags, shows a handle and an open hand under the pointer, and the drag carries a preview with the thumbnail and the name. Every drag start is written in `~/Library/Logs/ShowreelStudio/drag.log`.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.8.2 - 2026-11-09

**Fixed**
- **Dragging a resource from Resources onto a scene.** A scene (a frame of the reel, a row of the scene list, a node of its tree) now takes the resource by its own typed payload, straight on the view under the pointer, instead of depending on the app's memory of the drag. The release always ends with a line at the bottom: "Linked X to S03", or the reason it cannot be done (locked or archived scene, build running, lost drag).
- **A drag log to read what happens.** The app writes `~/Library/Logs/ShowreelStudio/drag.log` (about 100 KB, then it is rotated): where each drag started, what it passed over, whether the target accepted and why, and what the release did. No file content and no folder of yours is written in it. Files dragged from the Finder work as before.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.8.1 - 2026-11-09

**What's new**
- **The app asks before a build when a font has no file.** When you start a Build or an Assemble and a font of the Look is still on "Needs files", a card names the fonts, the source (the open Google Fonts repository), the licence and the size, and offers three choices: "Download and continue" (the files are downloaded and approved for the reel, as with Add font files), "Continue with a system font" (the build starts now and the orange Fonts step says so) and "Cancel". Nothing is downloaded without your yes, your choice is in the journal, and the card does not appear when every font has its files.

**Fixed**
- **Dragging a resource onto a scene.** The release now always does something: it links the resource to the scene (it reads "Used in S0x"), or says in the bottom line why it cannot (a locked scene, a build running, a nowhere target). Before, a release that could not be matched to a target again ended without a word.
- **Covers of MP3 files.** The picture embedded in an MP3 (the ID3 tag) is now found, shown in the preview and counted in the details; files without a picture, or with a damaged tag, simply have no cover.
- **Downloading fonts.** When the font repository refuses, the message gives the HTTP code and the address asked. When GitHub's limit for anonymous requests is reached (60 an hour for one address, easy to hit on a shared company network), it says so in plain words, keeps the manual way (the font's page, then the Resources tab) and offers "Try again".
- **The app's own instructions are no longer drawn as your messages.** The start of the Wizard, a build request or a scene draft show a short line ("Wizard started", "Build requested") instead of the text sent to Clap. The text is still sent, still kept in the transcript, and the Sessions view shows it behind "Show the app's instructions" (off by default).
- **Durations.** The Wizard's question and the presets of the Manual form now offer the same five durations: 30, 45, 60, 75 and 90 seconds (a typed value is still accepted).
- **The eye on the frames of the reel is gone.** Take a scene out of the film with the Delete key or "Remove from film" in its menu; it stays under the strip as a dimmed chip (click it or drag it back). The eye with two states stays in the scene list of the library.
- **No more "Mark as validated" in the Look editors.** The style sheet counts as validated as soon as the palette, the fonts and the background are chosen.
- **One thumbnail per frame.** A frame whose scene has a single still no longer repeats it.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.8.0 - 2026-11-09

**What's new**
- **Save a design as a package.** In the project settings, "Save design as package..." keeps the look, the default transition (when the project has one), the tone, the defaults (formats, duration, film languages, control level) and the resources you choose, one by one with their tags and the rights you gave them. A font added with the Add font files card carries its licence text. You give it a name, an author name (remembered for next time, never an e-mail address) and a note. The package is kept in your library, and you can export it as a `.studiopack` file to send. Saving a package does not change the project, so there is nothing to undo. A project that came from a package offers a new version of the same package, with a note saying what changed.
- **Start a project from a package.** In New project, in Wizard and in Manual, an optional step offers the packages of your library, or "Open a .studiopack...". The design is applied to the new project and the resources are copied with their tags and rights. The project stays on its own, with no link to the package, and remembers where it came from. In Wizard, Clap only asks what the package leaves open; in Manual, the form arrives filled in and counts what is set.
- **The import card.** Double-click a `.studiopack`, drop it on the app or open it from the library: the card shows the name, the author, the dates, the version, the short hash, whether the file is intact, "Not signed", whether you already have an older version, and every resource with the rights its author declared. Tick "I confirm I hold the rights to use these resources" to make them available; without it, the package is kept but its resources wait on Needs attention ("Rights not confirmed by you") until you answer for each. The confirmation is recorded with the version, and in the journal of every project that starts from it. A package never skips the automatic checks of the Resources tab: a file they flag stays flagged. Open fonts ask no question.
- **A file you can trust, or not.** The app checks the package's hash: if the file was modified or damaged after the export, the card says so and asks you to continue or cancel. A package never runs anything: file names, sizes, the number of files and the kinds of file are checked first, and a package inside a package is refused.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2 (a project that started from a package adds a `package` record; older files open as before). Embedded skill 0.16.0. macOS 13 or later.

## 0.7.0 - 2026-11-09

**What's new**
- **Details of a resource, by type.** Under the preview in the centre, one line says what matters (for example "1920 × 1080 · PNG · 245 KB", "3:42 · MP3 · 320 kbps · stereo · 8.4 MB", "Fredoka · 300 to 700 · TTF · 189 KB"). The inspector has a Details section in groups (File, Media, Tags, Rights): for an image the dimensions, aspect ratio, resolution, colour profile and transparency, and a warning when it contains location data; for music and sounds the duration, format, bit rate, sample rate, channels and tags (title, artist, album, year, genre, copyright, cover size), with the tempo when the project already analysed that file; for a font the family, weight, italic, glyph count, format, embedding flag and declared licence; for any file its size, folder, dates and state, with the reason it needs attention and the rights answer. Right-click a value to copy it. Reading is done in the background and kept until the file changes.

**Fixed**
- The preview of a music or sound resource plays the file you selected, starts clean (position, tags and cover) whenever you select another resource, and no longer mixes with the playback of the film: only one of them has the sound at a time, and the film's play controls say "Previewing a resource" until you select a scene.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.6.0 - 2026-11-09

**What's new**
- **A clearer Resources tab.** Files are grouped by type (Images, Sounds, Music, Fonts), then by state, and a group can be folded; the app remembers it for the project. The file you select is shown in the centre: the image, a sound or a piece of music with its tags, its cover and a small player, or a font as a specimen.
- **Tags.** Give a resource tags (a logo, a wallpaper...), filter the list by tag, rename a tag everywhere. The tag "placeholder" marks a stand-in, and the release gate lists it as before.
- **Four states.** Available, Used in S01, S07 (one clickable tag per scene; it is worked out from the scenes, you never type it), Proposal (Clap suggests it: Approve or Decline) and Needs attention.
- **Automatic checks, no AI and no key.** A file you add is available at once. If something looks wrong (a low resolution, a heavy file, a name that suggests real data, a copyright notice in the file, a font whose licence is unknown or forbids embedding) it waits on Needs attention with the reason in plain words. It cannot be used, Clap cannot see it, and the build refuses it, until you replace it, accept the risk with a short reason, or answer what you are allowed to do with it.

**Changed**
- The permanent fields "Licence note", "Note" and "Used in scenes" and the status menu are gone. The rights question appears only for a flagged file.
- A file you add is approved straight away when it is clean (it used to wait for your approval).
- A font you drop in by hand now needs its licence answered; one added by the Add font files card does not.

**What you need to do**
- Nothing. Open an older project: its resources show in the new groups, with the states worked out from the manifest. Nothing in the files changes.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.5.1 - 2026-11-09

**Changed**
- Nothing you can see: the New project screen moved to its own file so that the checks on the Library window stay true.

**What you need to do**
- Nothing.

## 0.5.0 - 2026-11-09

**What's new**
- **Two ways to start a project.** The New project screen offers two cards, chosen once: Wizard, where Clap asks a few questions and then proposes a starting pack (the base setup, a look, the scenes and their order, the music if you gave some) as cards you accept one by one or all at once; and Manual, where you fill a compact form yourself. Both end in the same interface. Wizard needs an API key; without one its card says so and tells you how to connect one, or to choose Manual.
- **A clearer project form.** Formats are tiles with their shape, the duration has quick values and says at once whether it is feasible, the film languages are chips you pick from a list, the brief fields are compact with an example in each, and the control level is three cards. The required setup shows "n of 5 set" and the workspace opens when it is complete.
- If Clap cannot go on during the Wizard, a clear message and a button take you to the form, with the answers you already gave.

**Changed**
- The words Beginner and Expert are gone, and there is no switch between them in a project. An older project keeps working: Beginner reads as Wizard and Expert as Manual.
- "Mark as validated" no longer exists for the interview: it counts as done when the base setup is complete. The Go is still the only validation you give.

**What you need to do**
- Nothing. Open an older project as usual; nothing is changed in its file.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.4.1 - 2026-11-09

**Changed**
- Clap now knows that generating a scene whose file you edited by hand overwrites your edit, and says so before it proposes it. The card already showed it; the assistant's instructions now match.

**What you need to do**
- Nothing.

## 0.4.0 - 2026-11-09

**What's new**
- **Marks everywhere.** A scene, an item or a resource that is read-only because Clap proposes a change, or because the film is being built, now shows a thin orange outline and a small button on the reel's frames, in the scene tree and in the Resources list, as it already did in the scene list. The tooltip gives the reason and the way out; a click on a proposal's mark takes you to its card.
- **Badges in one order.** On the list, the tree, the reel and the inspector, a scene shows its review state first and its build state next, side by side. The temporary outline never covers them.
- **Generate follows the changes.** The offer in the player now includes the scenes whose file is out of date, not only the ones with no file. It is still one card with the files, the number of calls and an estimated cost; locked scenes are left out with their reason. A scene whose file you edited by hand is only generated if you tick it, and the card says your edit will be overwritten. The reel's counter counts both missing and stale scenes.
- **Buttons and menu items say why.** Disabled buttons in the palette and moods editors, the memory form, the editor, the set-up screens, the new project, update and restore sheets, the preview and the wizard now explain themselves in a tooltip. Undo and Redo in the Edit menu say "nothing to undo" or "building the film" in their own title.

**What you need to do**
- Nothing.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.3.0 - 2026-11-09

**What's new**
- **Fonts in the film.** Each font of the Look shows its state: Needs files, Preview only or Embedded. When files are missing, a sentence says what the film will do instead (use a system font, which looks different and can vary between computers) and a button, Add the font files, fixes it.
- **Add font files.** One card shows the font, where it comes from (the open Google Fonts repository, from the skill's fixed list only), its licence (SIL Open Font License, the text is kept), the files with their total size, and that the network is needed. Accepting the card approves the files for the film and downloads only the weights the Look uses. It can be undone, and Clap can propose the same card.
- **Embedded in the build and in Assemble.** Approved font files are embedded in the film. A font with no file gives an orange "Fonts" step that names it. Adding or removing font files makes the assembled film stale, but no scene.
- **Font files you drop in Resources** show their family and weight, and which part of the Look uses them. A font needs its licence note before you can approve it.

**Changed**
- The build asks Clap not to list the Look's fonts itself: the app embeds the approved ones.

**What you need to do**
- For each font that says "Needs files", press Add the font files and read the card. If the network is blocked, download the font from its page and drop the files in Resources.
- Assemble or build again to get the fonts into the film.

**Compatibility**
- Project format revision 2. Embedded skill 0.16.0. macOS 13 or later.

## 0.2.0 - 2026-11-09

**What's new**
- **Scene states.** Every scene is WIP, Validated or Locked. A Locked scene refuses every change to its content, length or look, from you and from Clap, and says why. Only a Validated scene can be locked. "Lock all validated" locks them in one step. A click on the state badge opens a small menu.
- **Ask Clap.** The assistant's tab is called Ask Clap. Conversation, Memory, Sessions and Journal are in a selector at its top (they used to be in the project settings).
- **Global look and locked scenes.** When a change to the project's look would change locked scenes that follow it, the card lists them and says so. You can apply anyway or refuse.
- **One file per scene.** A film is built as one file per scene, put together by the app with no AI. Clap can write the file of one or several scenes only, after one card that lists the scenes, the number of calls and an estimated cost. A locked scene is never written again without unlocking it.
- **Assemble and Play.** "Assemble" puts the film together for free. Play plays only the assembled film; if the film is stale, it is assembled when you press Play. A scene with no file shows as an empty frame with its ID.
- **States you can read.** Each scene shows whether it is not generated, up to date, stale or edited by hand, and the reel header says whether the film is up to date, stale or has scenes to generate. A film in the old single-file format plays as it is and says so.
- **The interface reacts.** While Clap proposes a change, the elements it touches are marked and read-only, with a banner to accept or refuse. While Clap works, a chip says what it is doing. While the film is built, everything is read-only, with a progress panel and a Cancel build button. Every change gives a line at the bottom with Undo, and a refusal says why and what to do. Closing the window, quitting, updating or restoring while work is in progress asks first and says what will be lost.
- **Transitions.** Transitions that only approximate at assembly, and free instructions that a generation has not read yet, are marked.

**Changed**
- A version that a stopped or failed build left behind is never the one that plays: the player keeps the last version that was built and tested, and the version is marked incomplete.
- A new Build asks Clap for scene files instead of one big file.
- Review states are named WIP, Validated and Locked (the older words open, ok and modify still read correctly).

**What you need to do**
- Open each existing project and accept "Update project" in the banner. The app keeps a backup first and can restore it.
- To move a project to the one-file-per-scene format, run a new Build. Until then it plays as before.
- Nothing to install for the skill: the app carries its own copy.

**Compatibility**
- Project format revision 2. Embedded skill 0.15.2. macOS 13 or later (the Ask Clap icon looks different before macOS 14).

## 0.1.0 - before these notes

The base of the app, before release notes existed. The phases are listed in `docs/phases-done.md`.

**What's new**
- A native Mac app with the assistant (Clap) in a chat, question cards and a key kept in the Keychain; the skill runs inside it.
- Projects with a library, a guided path for beginners and a workspace for experts, generated documents, checks and a first build you can play.
- The editing workspace: a scene library with a tree per scene and ordered content, an inspector, a viewer and a storyboard that is a timeline with transitions, durations, music and a grid.
- Direct manipulation (drag and drop everywhere, undo and redo of every change), the look as project settings with pickers where choices are used, and "Update project" with backups.
- A project memory, a journal of every change and a summary of each session, kept in the project.

**What you need to do**
- Nothing: this is the starting point.
