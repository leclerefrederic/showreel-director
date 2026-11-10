# DS2: the Film strip and the Storyboard list on the tokens, and the motion language (app 0.17.0, skill untouched)

## Step 0 (read only)

a) Literals left before: TimelineViews 37 (`StripColor` 7 hand-made colours, `.white.opacity`, `.black.opacity`, `.orange`, `Color(white: 0.2)`), StoryboardListViews 4 (teal lock, orange marks, red/orange of the Checks badge). Each maps to a new token with the same value (strip palette, `mark`, `lockOn`) or to an existing role (`danger`).
b) The thumbnails were already clipped and cropped from the left, so they did not overflow into the next frame. The clutter came from large scene text scaled to the lane height under the gradient, the chips (label, Status icon, duration) and the diamonds drawn over it. Diamonds of frames under 72 pt sit in a row above, so they never touch a label or icon.
c) Animations: `Motion` (spring, quick, appear) in DragDropViews.swift, `ClapPulse` in Theme.swift, three raw `.easeOut` in ChatView, one in ReactionViews (`FlashWhenChanged`).
d) Stable IDs: list rows `scene:ID` and `transition:FROM` (`StoryboardList.Entry.id`); strip frames use `scene.id`.
e) The built-film placeholder is a grey frame with the scene ID (assemble.py), not bars. Red and yellow bars at 0:00 are the first scene's own opening (or a bars background) shown by the paused player: expected. Report only.

## Built

1. **Motion tokens** (ShowreelKit `MotionTokens`): 120/200/300 ms, curves, panel spring (0.32, 0.82) and a confirm spring, speed scale (0 = off), one `resolve` function for Reduce motion (fade or nothing), 300 ms cap. `Motion.swift` (app) turns them into animations and modifiers: `nudge`, `stateChange`, `ToggleIcon`, `arrives`/`departs`, `settles`, `pop`, `RunMark`, `ClapPulse`. `Theme.motion` sets them.
2. **Patterns applied**: Status icon pulse, Build run state on rows and frames (`RunAppearance`: distinct label and icon per state), eye/lock cross-fade, nudge on a refused switch, frames arrive and leave, diamond pop, panels on the token, raw curves of ChatView and ReactionViews moved to tokens.
3. **Strip**: pictures clipped inside their rectangle, cropped from the left; frames of at least 104 pt have header and footer bands (label and Status icon, duration), shorter frames keep the chips and gradient as before. The label truncates, never the icon or the diamond.
4. **Tokens**: `Theme.strip` (`StripPalette`), `mark`, `lockOn`. DS1 allow-list for the two files is 0; total went from 189 to **148 colour literals left in 30 files for DS3**.
5. **Tests** (`DS2Tests`, 11): durations and cap, speed 0, Reduce motion, panel spring, no raw motion in views, no colour in the two files, thumbnail inside its frame (many sizes), bands, Status icon vs diamond clearance, stable IDs, run-state looks, token contrast. Changed: DS1Tests allow-list and total; `TimelineTests.testAFrameWithOneStillShowsOneThumbnailAtItsShape` (the thumbnail of a tall frame is now between the bands).

## Choices and deviations

- Crop from the left; header and footer bands for tall frames (least intrusive, same look for short ones).
- **Not done**: the selected highlight does not slide between rows and frames (the surface fades); a drop-target highlight of a diamond keeps its existing look. Line added to docs/ideas.md.
- Reduce motion is read from the system; a pulse uses a scale (no `symbolEffect` on macOS 13).

## Verified, not verified

Verified: `tools/verify.sh --fast`, the complete `tools/verify.sh` (VERIFY OK), `tools/rebuild-app.sh` (SELFTEST OK, BUNDLE OK, pid 41079), app 0.17.0 released with its notes.
**Not verified: anything drawn or animated** (no screen). Layout is tested as rectangles only.

## To check by hand

1. The strip with 15 scenes in both Film placements: text no longer crossing frames, labels, icons, durations and diamonds readable, nothing overflowing, zoom and Fit.
2. Each pattern: Status icon change, eye and lock, inspector switches, adding and deleting a scene then Undo, a refused action on a locked scene (nudge and reason), a Build (waiting, writing, testing, repairing, settling), a diamond selected, a catalogue item dragged over a diamond.
3. The same with Reduce motion on (System Settings, Accessibility, Display).
4. A list of 15 scenes scrolling and animating smoothly.
5. Look, Project and Clap panes: same bounce as before.
