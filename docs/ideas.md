# Ideas parking lot

Ideas for Showreel Studio that are not in the current phase. Nothing here is built, estimated or scheduled until the owner moves an item into `docs/studio-spec.md`. Add one line per idea, newest first, with the date.

- 2026-11-10: voice mode for the copilot: push-to-talk with on-device speech recognition (Apple Speech, `requiresOnDeviceRecognition`, microphone and speech usage strings in Info.plist), optional spoken replies (AVSpeechSynthesizer), spoken accept or refuse on the proposal cards. Nothing leaves the Mac for recognition. Today the system dictation (Edit, Start Dictation) already works in the copilot field.
- 2026-11-10: `tools/rebuild-app.sh --debug`: a debug .app (a build of 3 to 6 s instead of 35 s) to judge a screen during a phase, the release build kept for the end of the phase.
- 2026-11-10: scroll a list or the reel by itself when a drag nears its edge (today the wheel or trackpad scrolls while dragging).
- 2026-11-10: drag a font from the Look tab onto a scene (it needs a title or text choice: a small menu on drop).
- 2026-11-10: shape items in a scene's content (rectangles, lines) with the same fixed or auto attributes.
- 2026-11-10: make the six catalogue transitions that do not run between real scenes (Morph, Match cut, Ink/paper inversion, Curtain, Mirror split, Star reveal) draw the outgoing and incoming scenes.
- 2026-11-10: draw the film layer's off-screen scenes at the device's resolution and the transitions in the stage's own aspect (an iris is an ellipse in 9:16 today).
- 2026-11-10: the app writes the montage as a film.json that build.py inlines (scene starts, durations, transitions), so main.js reads them instead of copying them from the message.
- 2026-11-09: build without the AI when every attribute of a scene's content is fixed (declarative scenes).
- 2026-11-09: interface language chosen from the system or the project's conversation language.
- 2026-11-09: several montages (cuts: master, short, vertical) shown in the app, sharing one scene library.
- 2026-11-09: let the AI write each scene as its own module file (scenes/S01.js) with a deterministic assembler in the skill's scripts, so that the app can reassemble main.js without AI and regenerate one scene only (the premise of phase V, see docs/overnight-report.md).
- Locked scenes and "give them their own look": a locked scene refuses a look override, so today the card's second way out needs an unlock first; allow pinning the current look (an override equal to what the scene shows now, no visible change) on a locked scene.
- Action/reaction, later: blocked marks on the timeline's frames and markers, the resource rows and the scene tree; the standard disabled control for menu items (Undo/Redo, context menus); a "Keep this version" choice for a cancelled build's folder (rename it to vN-partial or delete it) instead of leaving it as written.
- Film state, later: the "Clap proposes" and "Locked during build" marks on the reel's frames, the resource rows and the scene tree (still absent); regenerate the stale scenes in one card (today the offer lists only the scenes with no file); a "Keep or delete this incomplete version" choice; the free instruction of a transition applied by the assembly itself (the engine ignores it today).
