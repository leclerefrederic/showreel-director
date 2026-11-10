# Fix FIX2: selecting a scene in the Storyboard list must also move the preview

Read CLAUDE.md. Follow every rule of CLAUDE.md (never run git, English interface, no out-of-scope work: an idea goes in docs/ideas.md in one line). Fix the first compiler error first. Views stay free of business logic.

## The bug (owner)

Clicking a scene in the Storyboard list selects it in the Film strip, but the preview does not move to it. Clicking a scene in the Film strip selects it in the list and moves the preview. The three places must stay in step.

## Cause found by reading the code (check it, do not trust it)

- The strip's frame tap (`TimelineViews.swift`, around line 474) does `project.select(.scene(scene.id))`, then sets `project.playhead` to the scene's start, then takes the focus.
- The list row's tap (`StoryboardListViews.swift`, around line 196) only does `project.select(.scene(scene.id))`: it never sets the playhead.
- `ProjectModel.stepScene(by:)` (arrows) also selects and moves the playhead and follows it in the viewport. So the rule exists in three places, written three different ways.

## To do

1. **One typed operation** in ProjectModel (for example `focusScene(_ id: String)`) that does what a click on a strip frame does: select the scene, put the playhead at its start in the film, scroll the strip to follow it when needed, and show the film in the centre (if a resource preview or another centre view is showing the viewer's place, return to the film as the strip's click does). Its rules (which time to use for a scene that is hidden or not in the film, what happens while the film is playing) live in a pure function in ShowreelKit with tests. Proposed rules, to confirm or correct in the report: a scene that is in the film moves the playhead to its start; a hidden scene (not in the film) is selected and does not move the playhead; while the film plays, the playhead jumps and the playback continues; the Storyboard list scrolls to keep the selected row visible, as the strip scrolls to the selected frame.
2. **Use it everywhere a user click means "look at this scene":** the list row, the strip frame (replace its own code), the arrow stepping (keep its behaviour), the "Used in" scene chips of the Resources, the click-through of a check that names a scene, the transition lines (a transition already moves the playhead near its cut: keep that), and any other `select(.scene(...))` made by a user action. List every call site of `select(.scene` in the report with its decision: user click (use the operation), side effect of an edit such as adding or duplicating a scene (select only, except that a newly added scene also moves the playhead to it, say so), or other.
3. **Keep the selection in step the other way too:** selecting in the strip scrolls the list to the row, and the inspector shows the same scene (verify, fix only what is missing).
4. **Tests (no screen):** the pure rule (scene in the film, hidden scene, scene with no start yet, playing or paused); the list click and the strip click give the same selection and the same playhead; a hidden scene does not move the playhead; the "Used in" chip and a check's click-through use the operation; the stepping keeps its behaviour. Update any test that assumed the list click did not move the playhead and say which.
5. Release notes in RELEASE-NOTES-APP.md BEFORE tools/bump_app.py (a patch); never edit a version by hand.

## Verification

During the work: tools/verify.sh --fast. At the end: the complete tools/verify.sh, then tools/rebuild-app.sh.

## Final report (docs/fix2-report.md)

The cause as found, the rules chosen, the list of call sites with their decision, what changed, the version, what is verified and what is not (no screen), and "To check by hand": click a scene in the Storyboard list (the preview jumps to its start, the strip outline follows, the inspector shows it); click a frame in the Film strip (the list scrolls to its row); click a hidden scene (selected, the preview does not jump); click while the film plays (it jumps and keeps playing); click a "Used in" chip in the Resources and a check that names a scene; use the arrow keys. Stop after the fix.
