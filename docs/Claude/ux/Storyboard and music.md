---
type: ux
status: current
phase: 
date: 2026-11-10
summary: "Owner remarks on the Storyboard and music, with what T2 built for the music grid."
tags:
  - ux
---

Part of [[ux-notes]].

# Storyboard and music

- **Built in T2 (2026-11-09).** With a track attached and analysed: a discreet grid over the frames at the snap level (beats, bars, sections, drops; bars stronger than beats; thinned so that lines stay at least 12 points apart; never over a scene's ID, duration or review state, nor over a transition marker); on the music lane the beat ticks, the bar numbers, the sections' limits with their name (Break, Return) and the drops (a distinct mark, tooltip with the instant); while an edge or a cut is dragged with snapping, the target line lights up and a label says where it falls ("Bar 5, beat 1, 0:12.4"); a Grid button in the toolbar (remembered per project); an "Analyse the track" button when the track is attached but not analysed. A frame shows one thumbnail (no repeated tiles) until W4. To judge in the rework: the weight of the lines on a busy film, and whether section names from the analysis (Break, Return) are enough.

- Scene state badge (owner): the round badge on a scene is useful if it carries a clear state: a check means the scene is validated, a padlock means it is locked and cannot be modified under any pretext, and another icon means work in progress (WIP). Proposed model: three states, WIP (default; includes "to modify", with its note), Validated (the skill's OK) and Locked (new); a ditched scene is archived. Locked: every edit is refused with a reason, for the user (content, duration, look overrides, composition, drops) and for Clap's tools; the scene's place in the montage stays movable unless the owner decides otherwise; unlocking is explicit; lock and unlock are typed operations, journaled and undoable. The badge opens a small menu to change the state; each state has an icon and a tooltip; the library list, the tree, the reel and the inspector use the same icons.

- Decision (owner): the eye icon on the frames of the reel is useless, because a hidden scene leaves the reel, so the reel only ever shows visible scenes and the eye can only hide. Remove the eye from the reel frames. Hiding from the film is done by the Delete key or the context menu ("Remove from film"), and a hidden scene stays reachable as a dimmed chip under the strip (drag it back, or click it). The eye with both states stays only in the scene list of the library, where hidden scenes remain listed. This replaces the earlier note about the eye on reel frames.

- On a frame of the reel, the eye icon (visible in the film or not) and the round badge (review state) are unexplained, and the eye appears crossed out on a scene that is in the film, so the icon seems to show the action instead of the state. The eye must show the state (open when visible, crossed when hidden) with a tooltip, and the round badge needs one icon per review state with a tooltip. The duration pill is truncated ("0.867...") and must be rounded and never truncated.

- Direct feedback when resizing a scene in the storyboard: the duration changes but the frame does not visibly follow the pointer, which feels wrong. The frame edge must track the cursor continuously during the drag, the following scenes must shift live when ripple is on, a snap indicator must show the grid position the edge will land on, the duration label must update live, and the change must be committed once on release (one undo step; Escape cancels). The same live feedback applies to dragging the cut between two scenes and to reordering.

- Display defects seen on the first screenshot of the new timeline: (1) a long frame repeats the same thumbnail three times (S01 S01 S01), which is meaningless while a scene has a single still; show one thumbnail, repeated frames only once real frames at different times exist (W4). (2) Ruler labels are rounded wrongly: ticks every 0.25 s read 0:00.2, 0:00.5, 0:00.8; the steps must come from a series of round numbers (0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 30, 60 s) and labels need the decimals they require. (3) The header counter reads "0:00.0 of 90 s" while the film is 6 s: say "6 s of the 90 s target".

- The viewer is blank when nothing is selected and there is no build (seen on the same screenshot). It should follow the playhead: show the thumbnail of the scene under the playhead.

- The storyboard strip is a major UX flaw as it stands (owner, 2026-11-09). Seen on the screenshot: the frames stay tiny inside a tall panel, a 6 s film fills about a seventh of the width, the flat mid-grey background is heavy and low in contrast, the ruler and the music placeholder use tiny text, the music lane is a small dashed box far from the frames, the transition marker covers the duration label of the next scene, and the controls (Snap, Ripple, an unlabeled slider, Add scene, Mark as validated, Give the Go) are a row of raw system controls. It is to be redesigned as a proper editing timeline (phase S, which also covers the zoom of W2b).

- The storyboard strip panel resizes but its content does not follow, so a taller panel is useless. The reel must zoom: frames, thumbnails and the music track scale with the panel height, and the time scale can be changed to focus on a portion instead of the whole film (zoom in and out, fit to the whole film, fit to the selection, horizontal scroll, the playhead stays in view).

- The project's music should show under the storyboard with its waveform and analysis. Stretching a scene to the left or right snaps to the track's grid (stick to grid), so scenes are timed on the music.

## Built in W4b (2026-11-10)

A frame of the strip, and the larger picture in the scene inspector, is a PNG captured from the built film at one moment of the scene, with a placeholder that says why there is no picture, a clock mark when it is out of date and a "Refresh thumbnail" action. See [[phases/W4b/report]].

## Built in FL1 (2026-11-10)

Film strip scenes look like film: the grid is drawn under the frames, the thumbnail is centred whole on a translucent black token (`thumbBackdrop`), each frame has perforation bands above and below and start and end caps (accent when selected). Perforations disappear under 60 pt wide (caps stay) and under 40 pt high. Remains: the thumbnail's own aspect is taken as 16:9 (every capture is); a locked scene's mark is unchanged.

## Built in FT1 (2026-11-10)

The Film toolbar lost the Ripple switch and the Add scene menu; the zoom group (minus, slider, plus, fit menu) is the last control, at the far right. Resize always moves the following scenes. Remains: the Beat (snap) menu, the grid toggle and the music controls move to the music lane in MT1.

## Built in MT1 (2026-11-10)

The music lane has a toolbar (Beat, Bars, Sections, Drop, Analyse, track name and BPM), pinned under the lane. Snapping follows the finest mark shown. Remains: the toolbar sits under the lane, not on a header inside it; Clap's `get_state` still reports the project's stored snap level.
