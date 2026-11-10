---
type: reference
status: current
phase: 
date: 2026-11-10
summary: "The parking lot: the open questions for the owner, generated from docs/Claude/questions/, and the list of ideas, generated from docs/Claude/ideas/."
tags:
  - hub
  - backlog
---

# Ideas parking lot

## Questions to settle with the owner (remind him before writing any prompt)

The notes of `docs/Claude/questions/` are the source: `status: current` is open, `superseded` is settled (with a link to the decision). To settle one, edit its note's status and add the decision, then run `python3 tools/docs_index.py --write`: this list follows. The owner waived these questions during the redesign, see [[decisions/The open questions are waived during the redesign]]. Dashboard: [[Questions.base]].

<!-- generated:questions -->
- QUESTION-001 [[questions/Confirm the Checks badge after use|Confirm the Checks badge after use]] (UI1, 2026-11-10): Confirm the Checks badge in the top bar after using it, or switch to a thin status row under the left panel.
- QUESTION-002 [[questions/Confirm the two-thirds split of the left panel|Confirm the two-thirds split of the left panel]] (UI1, 2026-11-10): Confirm the two-thirds and one-third split of the left panel, never judged on a laptop screen, and the default state of Resources.
- QUESTION-003 [[questions/Is the phase order of the spec still the one we follow|Is the phase order of the spec still the one we follow]] (, 2026-11-10): Spec section 11 point 5, the order of the phases, has no recorded decision, and the project has gone far beyond phases A to D.
- QUESTION-004 [[questions/Keep three scenes written at once as the default|Keep three scenes written at once as the default]] (BG2, 2026-11-10): Whether to keep three scenes written at once as the default, to decide after measuring one against three.
- QUESTION-005 [[questions/May a click on the active Build leave the Build|May a click on the active Build leave the Build]] (RB1, 2026-11-10): RB1 made Build not toggle off, so a second click does nothing and Film is the way back; should Build toggle off?
- QUESTION-006 [[questions/Rework of the Wizard and Manual creation experience|Rework of the Wizard and Manual creation experience]] (P5, 2026-11-10): Rework the Wizard and Manual creation experience, asking the owner first what bothers them in each.
- QUESTION-007 [[questions/Shortcuts for the other right panels|Shortcuts for the other right panels]] (RB1, 2026-11-10): No shortcut opens the Inspector, Look or Project, next to Shift-Command-A for Clap; add one?
- QUESTION-008 [[questions/Should Look light a centre entry|Should Look light a centre entry]] (RB1, 2026-11-10): While the Look panel is open the centre shows the design board but the Film entry stays lit; light Look in the centre group too?
- QUESTION-009 [[questions/Should a lock also freeze the transitions beside a locked scene|Should a lock also freeze the transitions beside a locked scene]] (UI2, 2026-11-10): Whether a lock should also freeze the transitions on both sides of a locked scene, which stay editable today.
- QUESTION-010 [[questions/Should locked scenes from before UI2 take a copy of their look when the project opens|Should locked scenes from before UI2 take a copy of their look when the project opens]] (UI2, 2026-11-10): Whether to give locked scenes from before UI2 a copy of their look automatically when the project opens.
- QUESTION-011 [[questions/Should the Inspector mark show when the side is closed|Should the Inspector mark show when the side is closed]] (RB1, 2026-11-10): A selection with the right side closed opens the Inspector, so the mark shows only while another panel is open; show it when closed?
- QUESTION-013 [[questions/What form should the timing control of an item take|What form should the timing control of an item take]] (W4, 2026-11-10): What form should the in and out of an item take in the inspector: two steppers behind an Auto or Fixed switch, as built, or a strip under the rows?
- QUESTION-014 [[questions/Should an item's timing snap to the music grid|Should an item's timing snap to the music grid]] (W4, 2026-11-10): When a track is analysed, should the in and out of an item snap to the beats and bars of the music grid, or stay free to the tenth of a second?
- QUESTION-015 [[questions/Should timing be in seconds or in beats|Should timing be in seconds or in beats]] (W4, 2026-11-10): Should the in and out of an item be written in seconds from the start of the scene, as built, or in beats when the music has a tempo?
- QUESTION-016 [[questions/Should the viewer play an item's timing live|Should the viewer play an item's timing live]] (W4, 2026-11-10): Should the viewer play a scene with its items coming and going in time, or keep showing a still at a chosen time, as built?
- QUESTION-017 [[questions/Which instant of a scene should its thumbnail show|Which instant of a scene should its thumbnail show]] (W4b, 2026-11-10): Which instant represents a scene in its PNG thumbnail: the W4 still time, the middle, the busiest moment or the last moment before the exit.
- QUESTION-018 [[questions/Should the viewer keep its content drawing before a build|Should the viewer keep its content drawing before a build]] (W4b, 2026-11-10): Before a build has a film to play, should the viewer keep drawing the scene from its content (W4), or show a plain placeholder like the strip.
- QUESTION-019 [[questions/Should the strip mark every frame as fresh or only the stale ones|Should the strip mark every frame as fresh or only the stale ones]] (W4b, 2026-11-10): Whether each strip frame shows a freshness mark all the time, or only the out-of-date frames, which carry a clock mark.
<!-- /generated:questions -->

## Ideas

Ideas for Showreel Studio that are not in the current phase. Nothing here is built, estimated or scheduled until the owner moves an item into `docs/Claude/studio-spec.md`. Add one note per idea in `docs/Claude/ideas/` (copy the properties of an existing one) and run `python3 tools/docs_index.py --write`: this list follows, newest first. Dashboard: [[Ideas.base]].

<!-- generated:ideas -->
- IDEA-001 [[ideas/An icon per transition family|An icon per transition family]] (app, draft): Proposes one icon per transition family, with the exact name in the tooltip, read from the catalogue and overridable by skins.
- IDEA-002 [[ideas/Two pictogram icons as the layout toggle|Two pictogram icons as the layout toggle]] (app, superseded): Merged into the note that holds this line word for word.
- IDEA-003 [[ideas/Show and hide controls for the side panels in the view group|Show and hide controls for the side panels in the view group]] (app, draft): Show and hide controls for the left and right panels, to focus on the preview and the Film strip (the same idea was written twice).
- IDEA-004 [[ideas/Interface skins as JSON design tokens|Interface skins as JSON design tokens]] (app, draft): Interface skins: a JSON file of design tokens loaded at run time, with bundled skins, a picker, import and export, a contrast gate and an icon map.
- IDEA-005 [[ideas/Voice mode for the copilot|Voice mode for the copilot]] (app, draft): Push-to-talk voice mode for the copilot with on-device speech recognition, optional spoken replies and spoken accept or refuse.
- IDEA-006 [[ideas/A debug build mode for rebuild-app.sh|A debug build mode for rebuild-app.sh]] (tooling, draft): A debug app build in 3 to 6 seconds instead of 35, to judge a screen during a phase; the release build stays for the end.
- IDEA-007 [[ideas/Scroll a list by itself when a drag nears its edge|Scroll a list by itself when a drag nears its edge]] (app, draft): Scroll a list or the reel by itself when a drag nears its edge.
- IDEA-008 [[ideas/Drag a font from the Look tab onto a scene|Drag a font from the Look tab onto a scene]] (app, draft): Drag a font from the Look tab onto a scene, with a small menu on drop to choose title or text.
- IDEA-009 [[ideas/Shape items in a scene's content|Shape items in a scene's content]] (app, draft): Add shape items (rectangles, lines) to a scene's content with the same fixed or auto attributes.
- IDEA-010 [[ideas/Draw both scenes in the six catalogue transitions that need them|Draw both scenes in the six catalogue transitions that need them]] (skill, draft): Make the six catalogue transitions that need real scenes (Morph, Match cut, Curtain and others) draw the outgoing and incoming scenes.
- IDEA-011 [[ideas/Draw off-screen scenes at device resolution|Draw off-screen scenes at device resolution]] (skill, draft): Draw the film layer's off-screen scenes at the device resolution and transitions in the stage's own aspect, so an iris is not an ellipse in 9:16.
- IDEA-012 [[ideas/Write the montage as film.json for the build|Write the montage as film.json for the build]] (app, superseded): The app writes the montage as film.json, inlined by build.py, so main.js reads scene starts, durations and transitions instead of copying them.
- IDEA-013 [[ideas/Build without the AI when a scene's content is fixed|Build without the AI when a scene's content is fixed]] (app, draft): Build without the AI when every attribute of a scene's content is fixed (declarative scenes).
- IDEA-014 [[ideas/Choose the interface language from the system or the project|Choose the interface language from the system or the project]] (app, superseded): Merged into the note that holds this line word for word.
- IDEA-015 [[ideas/Several montages sharing one scene library|Several montages sharing one scene library]] (app, draft): Show several montages (master, short, vertical cuts) in the app, sharing one scene library.
- IDEA-016 [[ideas/One module file per scene with a deterministic assembler|One module file per scene with a deterministic assembler]] (skill, superseded): Let the AI write each scene as its own module file with a deterministic assembler, so main.js is reassembled without AI and one scene regenerated.
- IDEA-017 [[ideas/Pin the current look on a locked scene|Pin the current look on a locked scene]] (app, draft): Allow pinning the current look on a locked scene (an override equal to what it shows now) without unlocking it first.
- IDEA-018 [[ideas/Blocked marks and disabled menu items, later|Blocked marks and disabled menu items, later]] (app, draft): Later work on blocked marks for the timeline, resource rows and scene tree, disabled menu items, and a Keep this version choice for a cancelled build.
- IDEA-019 [[ideas/Film state marks and one card to regenerate stale scenes|Film state marks and one card to regenerate stale scenes]] (app, draft): Later film-state work: Clap proposes and Locked during build marks, one card to regenerate stale scenes, keep or delete an incomplete version.
- IDEA-020 [[ideas/A toolbar toggle that gives a reason|A toolbar toggle that gives a reason]] (app, draft): A toolbar toggle component that gives a reason, marks on transition markers and the music lane, and whether an outdated project should be read-only.
- IDEA-021 [[ideas/Interface language, voice for the Wizard and re-running the starting pack|Interface language, voice for the Wizard and re-running the starting pack]] (app, draft): Choose the interface language from the system or project, add voice mode to the Wizard's interview, and re-run the starting pack on an existing project.
- IDEA-022 [[ideas/Resources and Scenes together, R2 analysis and tag colours|Resources and Scenes together, R2 analysis and tag colours]] (app, draft): Resources work: stacked Resources and Scenes, AI analysis of a resource at adding (R2), tag colours, and a tag picker with the tags in use.
- IDEA-023 [[ideas/Check a GPS position in a resource's metadata|Check a GPS position in a resource's metadata]] (app, draft): Check a resource's metadata for a GPS position at adding, and show a resource's details to Clap only with a consent.
- IDEA-024 [[ideas/Design System Manager, reusable packages|Design System Manager, reusable packages]] (app, superseded): Reusable design system packages that pre-configure a new reel: start from one, apply it to a project, save one, and let the AI propose refinements.
- IDEA-025 [[ideas/Decisions on the Design System Manager|Decisions on the Design System Manager]] (app, superseded): The owner's four decisions on packages: the user guarantees usage rights, one archive file, the AI reads design decisions only, a package can feed the skill.
- IDEA-026 [[ideas/Design System Manager promoted to spec section 5.6|Design System Manager promoted to spec section 5.6]] (docs, superseded): The Design System Manager was promoted to spec section 5.6 (proposed), with phases PK1 to PK4 in section 10.
- IDEA-027 [[ideas/Package tone instructions, default transition and drop on a project window|Package tone instructions, default transition and drop on a project window]] (app, draft): PK1 leftovers: tone instructions for Clap in a package, the default transition nothing reads yet, and opening a package by dropping it on a project window.
- IDEA-028 [[ideas/Music cover thumbnails, free font file names and a GitHub token for fonts|Music cover thumbnails, free font file names and a GitHub token for fonts]] (app, draft): C1 leftovers: music cover thumbnails, a list of free font file names to avoid GitHub API calls, and a GitHub token setting for the font lookup.
- IDEA-029 [[ideas/Rework creating a project for the Wizard and for Manual|Rework creating a project for the Wizard and for Manual]] (app, draft): Rework project creation for the Wizard and Manual around the visual pickers, with Clap opening and preselecting them; ask what bothers the owner first.
- IDEA-030 [[ideas/Typed drops for the content list and the resource slots|Typed drops for the content list and the resource slots]] (app, draft): If typed drops work, move the content list and resource slots to typed payloads and retire the geometry resolution of the workspace.
- IDEA-031 [[ideas/A drop target on the inspector of a selected scene|A drop target on the inspector of a selected scene]] (app, superseded): Add a drop target on the inspector of a selected scene so a resource can be dropped on it.
- IDEA-032 [[ideas/A 2D or 3D icon on each scene|A 2D or 3D icon on each scene]] (skill, draft): Show a 2D or 3D icon on each scene, read from a renderer field that assemble.py would record, with MP4 export refusals explained.
- IDEA-033 [[ideas/A budget per Build before distributing the app|A budget per Build before distributing the app]] (app, draft): Bring back a budget per Build (tokens, duration, estimated cost) before distributing the app.
- IDEA-034 [[ideas/Write independent scenes in parallel|Write independent scenes in parallel]] (app, superseded): Write independent scenes in parallel (two or three requests at once) once the per-scene Build is trusted.
- IDEA-035 [[ideas/Test scenes in parallel|Test scenes in parallel]] (app, draft): Test scenes in parallel (two or three at once) when scenes are written in parallel.
- IDEA-036 [[ideas/Ask again after a 429 or 529|Ask again after a 429 or 529]] (app, superseded): Ask again after a short wait a request refused with 429 or 529, instead of stopping the Build.
- IDEA-037 [[ideas/Kill the children of a command, not only the shell|Kill the children of a command, not only the shell]] (app, draft): Kill the children of a command the app runs (process group), not only the shell, so a grandchild cannot outlive a cancelled test.
- IDEA-038 [[ideas/A faithful preview of one scene in the centre|A faithful preview of one scene in the centre]] (app, draft): A faithful preview of one scene in the centre from a one-scene assembled page; measure speed and fidelity first.
- IDEA-039 [[ideas/A thin status row as the alternative to the Checks badge|A thin status row as the alternative to the Checks badge]] (app, draft): If the Checks badge is too far from the work, use a thin status row at the bottom of the left panel instead (same list, same click-through).
- IDEA-040 [[ideas/A free gap between two locked scenes|A free gap between two locked scenes]] (app, draft): A free gap for editing between two locked scenes while keeping the gap constant, instead of refusing any change that moves a locked start.
- IDEA-041 [[ideas/Drop ditched and archived from the file for good|Drop ditched and archived from the file for good]] (app, draft): Keep the stored scene states wip, validated, locked, ditched and the archived flag; a later migration could drop ditched and archived from the file.
- IDEA-042 [[ideas/A light theme and skin loading|A light theme and skin loading]] (app, draft): A light theme, and loading, importing and exporting skins with a picker, on top of the theme object and the icon roles.
- IDEA-043 [[ideas/Show and hide controls for the left and right panels|Show and hide controls for the left and right panels]] (app, superseded): Merged into the note that holds this line word for word.
- IDEA-044 [[ideas/Clap as a drawer beside the Inspector|Clap as a drawer beside the Inspector]] (app, draft): Show Clap as a drawer beside the Inspector, both visible at once.
- IDEA-045 [[ideas/A selected highlight that slides|A selected highlight that slides]] (app, draft): A sliding highlight for the selected row and frame, and the shelved two-pictogram layout toggle with a surround that slides.
- IDEA-046 [[ideas/Fix the comment of ShowreelFile.swift line 140 that names the wrong file|Fix the comment of ShowreelFile.swift line 140 that names the wrong file]] (app, superseded): Fix the comment at ShowreelFile.swift line 140, which names the spec for Scene content, a block of the UX notes.
- IDEA-047 [[ideas/Drag a scene between the storyboard and the Not in the storyboard group|Drag a scene between the storyboard and the Not in the storyboard group]] (app, current): A scene cannot be dragged from the storyboard into the Not in the storyboard group, nor back out of it; the owner noted it during the W4 hand test.
- IDEA-048 [[ideas/A trash for scenes and resources the owner no longer wants|A trash for scenes and resources the owner no longer wants]] (app, current): A trash for every scene and resource thrown away, since the owner asks whether a hidden scene is not one he no longer wants.
- IDEA-049 [[ideas/A short looping GIF as the thumbnail of a scene|A short looping GIF as the thumbnail of a scene]] (app, draft): A short looping GIF as the thumbnail of a scene.
- IDEA-050 [[ideas/Each transition gets its own icon in the strip|Each transition gets its own icon in the strip]] (app, draft): Each transition gets its own icon in the strip.
<!-- /generated:ideas -->
