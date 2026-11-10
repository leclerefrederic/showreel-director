---
type: phase-prompt
status: current
phase: W4b
date: 2026-11-10
summary: "Asks for scene thumbnails to be PNG captures of the real rendered scene instead of the schematic drawing of W4, audit first."
tags:
  - prompt
---

# Phase W4b: scene thumbnails are a PNG of the real scene (audit first)

Read CLAUDE.md, then `docs/Claude/Index.md` and open only what it points to for: the report of W4 (`docs/Claude/phases/W4/report.md`: what it draws and from what data, and what it flagged as not verified), the reports of W3a, W3b, BG1, BG1c, BA1 and UI1 (scene modules and files, the film layer and compositor, the build, the preview), the idea about "a faithful preview of one scene in the centre" and the one about drawing the film layer's off-screen scenes at the device's resolution (find them by their summaries in the index), the UX notes "Storyboard and music" and "Build and preview", `docs/Claude/studio-spec.md` section 6 (embedded engine), and the code: the thumbnail drawing added in W4, the storyboard strip's frames, `PreviewPane.swift`, the film layer and the scene loader, `Film.write`, the project folder layout (`.studio/`), `Availability`. Follow every rule of CLAUDE.md (never run git; English interface; answer the owner in French and short; the skill is untouched unless the audit proves it must change, and then through `tools/bump.py` with `capabilities.json` matched; never script other apps or the screen: capturing the app's own web view from inside the app is allowed and is the intended way). Views stay free of business logic: the rules live in ShowreelKit with tests.

## The owner's decision (do not reopen)

On 2026-11-10 the owner chose, among no thumbnail, a PNG of the real scene, and an animated GIF: **a PNG of the real rendered scene**. A GIF may come later and is not part of this phase. Record it as a decision note with `python3 tools/docs_new.py decision "Scene thumbnails are a PNG capture of the real scene"` (`affects` the storyboard, the viewer and W4; the reason: the schematic drawing of W4 is not what the film shows).

## What it means

1. A scene's thumbnail is an image captured from the **real rendering of that scene** (the same scene module the film plays, drawn by the app's own web view), at one **representative instant**, not a drawing made from the content items.
2. The PNG is a cache of the scene's current state: it is regenerated when the scene file, its duration, its content that the file depends on, or the project's look changes, and it never changes the film.
3. Before a scene has a real rendering (no Build yet, or the scene is not written yet), the frame shows a **plain placeholder**: ID, duration and first text, with a short line saying why there is no image yet and how to get one (Build). The schematic drawing of W4 is removed (its code, tests and the "AI decides" marking on thumbnails go with it; keep the pure timing rules and the viewer's behaviour of W4 untouched unless step 0 shows the viewer uses the same drawing code, in which case say so and ask, see below).
4. A thumbnail that is out of date (the scene changed since the capture) says so with a visible mark and a tooltip, and offers to refresh; it never silently shows a wrong image.

## Step 0 (read-only, the top of docs/Claude/phases/W4b/report.md)

1. **How a scene renders today** in the film layer and in the preview: where the scene module is loaded, how time is set (can a scene be rendered at a chosen instant without playing?), what happens for WebGL scenes (the Node harness cannot see them; the app's web view can), the resolution the film layer draws at, how long a render takes, and whether a render needs the whole film or one scene.
2. **How to capture**: the web view's own snapshot facility (for example `WKWebView.takeSnapshot`), the size and scale (at least the frame's size at 2x), the cost per scene and for a film of 10 or 30 scenes, whether captures can be queued off the main thread, and the failure cases (a scene that throws, a missing resource, a timeout).
3. **Where PNGs live**: the project's hidden `.studio/` folder is the natural place (user data, never inside the app bundle, and not meant for GitHub); the key of a file (scene ID plus a hash of the inputs that change the image), the invalidation rules, the cleanup of orphans, and the size per project.
4. **The representative instant**: options and their cost (the middle of the scene, the moment the most items are visible using the W4 active-items function, the last moment before the exit, a fixed fraction). Do not decide: see below.
5. **Does the viewer share the drawing code of W4?** If it does, list what would change.

**The choices that are the owner's**: the representative instant; whether the viewer should keep its W4 drawing before a Build; whether the strip shows a freshness mark on every frame or only on stale ones. Do not decide them. For each, create a question note with `python3 tools/docs_new.py question "<title>"` (with `blocks: [W4b]` and a one-line `recommendation`), apply the default you recommend behind it, and list only the IDs and titles in the report, one line each.

## What to build

1. **The capture pipeline in ShowreelKit** (pure parts tested): the key and invalidation of a thumbnail, the queue (one capture at a time, cancellable, never blocking the interface, never during a Build in a way that slows it), the storage in `.studio/`, the orphan cleanup, and the typed operations (refresh one scene, refresh all stale), journaled where the project records operations. The capture itself in the app target.
2. **When it runs**: after a successful Build for every scene whose file changed, when a scene is opened or selected and its thumbnail is stale (lazily), and from a "Refresh thumbnail" action on the frame's menu and in the scene inspector. Not on every keystroke; changes are coalesced and a capture starts after a short quiet delay (name the delay).
3. **The frames**: show the PNG when it is fresh, the PNG with the stale mark when it is not, the placeholder when there is none; every state says what it is and how to change it (action/reaction, `disabledWithReason`, never a silent state); the inspector shows the same image larger.
4. **Remove** the schematic thumbnail drawing of W4 and update its tests, saying which.
5. **Nothing else**: no change to timing rules, the rail, the Build, the transitions, the look or the skill; a GIF, a per-frame film strip of several instants and scene-wide effects are ideas, not this phase (create idea notes with `python3 tools/docs_new.py idea` only if new).

## Tests (no screen)

The key changes exactly when an input that changes the image changes and not otherwise; invalidation after a scene file, duration, look or resource change; the queue (order, cancel, one at a time, a failure leaves the placeholder with its reason); orphan cleanup; old projects with no `.studio/` thumbnails open unchanged; the state of a frame (fresh, stale, none, failed) is derived from the data; the PNG path never leaves `.studio/`. The capture itself cannot be proven without a screen: say so.

## Release

Release notes in `RELEASE-NOTES-APP.md` BEFORE `tools/bump_app.py` (say whether it is a minor or a patch and why); only if the skill changed, `RELEASE-NOTES-SKILL.md` before `tools/bump.py`. Never edit a version by hand. The report names both versions.

## Vault

Report in `docs/Claude/phases/W4b/report.md` with its properties; link the decision and the questions you created; settle any idea this phase built (`status: superseded`, `outcome: built`, link to the report), for example the faithful one-scene preview if it is now delivered; add "Built in W4b (date)" to the UX note "Storyboard and music"; update `CLAUDE.md` "Open work" (the last built is W4b; the next are PK2 and N); run `python3 tools/docs_index.py --write` and `python3 tools/check_docs.py`.

## Verification

During the work: `tools/verify.sh --fast`. At the end: `python3 tools/check.py`, the complete `tools/verify.sh`, then `tools/rebuild-app.sh`. Say which you ran.

## Final report (docs/Claude/phases/W4b/report.md)

Step 0 (how a scene renders, how to capture, where PNGs live, the cost, the questions as IDs and titles); what was built and removed; the versions; the tests; what is verified and what is not (no screen: the capture, the image quality, the freshness marks and the layout are not verified, say so plainly); and "To check by hand": build a film, check every frame shows the real scene and not a drawing; change a scene's text or duration and check its frame is marked out of date and refreshes; open a project with no Build and check the placeholder says why; use "Refresh thumbnail"; check a 3D scene; look in `.studio/` of a project and check the PNGs are there and small; delete a scene and check its PNG is cleaned up. Stop after the phase.
