# FIX2: a click on a scene moves the preview (app 0.17.1, skill untouched)

**Cause (confirmed).** The strip's frame tap selected the scene and set the playhead; the list row only selected; the arrow stepping did its own select and playhead. Three copies of one rule.

**Rules chosen** (pure, `TimelineNav.focus`): a scene in the film puts the playhead at its start (paused or playing: it jumps, playback continues); a hidden scene, or one with no start, is selected and the playhead stays. The strip follows the playhead; the list scrolls to the selected row (new `ScrollViewReader`).

**Operation**: `ProjectModel.focusScene(_:)` (select, show the film, playhead, strip follows).

**Call sites of `select(.scene`**
- List row, strip frame, "Used in" chip, a check's click-through (`.scene(id, tab)`), the way out of a reason (`followLink`), arrow stepping: user clicks, now `focusScene`.
- `addScene`: now `focusScene` (a new scene is shown as well as selected).
- Duplicate scene, a file dropped on a scene (`carryOutDrop`): side effects of an edit, select only.
- Transition lines: unchanged (they move the playhead near the cut).

**Tests**: `FIX2Tests` (the rule on a film with a hidden scene, every click site uses the operation). Updated `UI1Tests.testTheListTheStripAndTheInspectorUseTheOneSelection` (it expected `select(.scene(...))` in both views).

**Verified**: tests, then the complete `tools/verify.sh` and `tools/rebuild-app.sh` (see the end of this session). **Not verified**: anything on screen.

**To check by hand**: click a scene in the list (preview jumps, strip outline follows, inspector shows it); click a frame (the list scrolls to its row); click a hidden scene (selected, preview stays); click while the film plays (it jumps and keeps playing); a "Used in" chip; a check that names a scene; the arrow keys.
