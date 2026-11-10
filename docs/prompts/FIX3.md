# SHELVED, DO NOT RUN (the owner prefers the current animated single button, 2026-11-10)

# Fix FIX3: the layout toggle becomes two icons with a highlight that moves

Read CLAUDE.md, then docs/ux-notes.md (the entries "Film placement toggle (owner)" and "Sizes and reset (owner)" and the "Motion" section), docs/batchA-report.md, docs/ds2-report.md, and the code: the view group at the right end of the top bar (the layout button and the reset icon, built in RL1), `ShellLayout`, the Motion file and its tokens, the `IconRole` table. Follow every rule of CLAUDE.md (never run git, English interface, no out-of-scope work: an idea goes in docs/ideas.md in one line). Views stay free of business logic.

## What the owner wants

RL1 built ONE button whose pictogram shows the current layout. The owner wants **two icons, one per arrangement, side by side, as a toggle**: each icon is a pictogram of the interface in that arrangement, and the **active one is surrounded** by a highlight. The highlight is the animation: when the owner clicks the other icon, the surround **slides** to it (a toggle, like a segmented control).

## To do

1. **Two pictograms, side by side, in one control.** Left: Film under the preview (the strip under the centre column, the rail, left panels and right panel at full height). Right: Film full width (the strip as a block along the bottom from the left panel to the right panel, the rail at full height). Reuse the two pictograms RL1 drew (shapes from the tokens, registered in the `IconRole` table; keep the two roles, drop the "current layout" role if it has become unused and say so). Each pictogram has its own tooltip that names the arrangement and the action ("Film under the preview", "Film full width"); the control is exposed to accessibility as a group of two radio-style options with the selected one announced.
2. **The active one is surrounded.** A rounded outline and a soft fill from the theme tokens (the selected surface and the accent) around the active icon; the inactive one is plain and gets the usual hover highlight. The surround is one shape that **slides** from one icon to the other with the selection-slide pattern of the motion language (a matched geometry slide with the base duration and the decelerating curve token, no overshoot), and the regions of the window move with the existing spring as they do now. Under "Reduce motion" (the existing single function) the surround changes place with a quick fade or at once.
3. **Build the sliding selection once, reusable.** Put the sliding surround in the Motion file as a reusable modifier or small view (a "sliding selection" for a row of options) with the raw durations and curves only from tokens, so that the Storyboard list's selection highlight can adopt it later; apply it to this control only in this phase and put the list adoption in docs/ideas.md in one line if it is not already there.
4. **Keep everything else of the group:** the separate reset icon next to it (unchanged: it restores the standard proportions without changing the arrangement, disabled with its reason when already standard), the position at the right end of the top bar, the remembered choice per project, the clamping of the stored sizes. Switching arrangement still never changes the stored widths and heights.
5. **Keyboard:** the toggle is reachable with Tab, the arrow keys move between the two options, Space or Return selects the focused one.
6. **Tests (no screen):** the control's model has exactly two options mapped to the two `ShellLayout` placements and the active one follows the stored choice; selecting an option stores it, restores it on reopening and leaves every stored size unchanged; each option has its tooltip text and accessibility label; the pictogram roles are both mapped and distinct; no raw duration or curve in the view (the DS2 source guard stays green); under "Reduce motion" the slide maps to fade or none. Update the RL1 tests that assumed a single button and say which.
7. Release notes in RELEASE-NOTES-APP.md BEFORE tools/bump_app.py (a patch); never edit a version by hand.

## Verification

During the work: tools/verify.sh --fast. At the end: the complete tools/verify.sh, then tools/rebuild-app.sh.

## Final report (docs/fix3-report.md)

What changed, which roles remain, the version, what is verified and what is not (no screen: nothing drawn or animated is verified), and "To check by hand": the two pictograms at the top right and whether each one reads as its arrangement at that size; the surround on the active one; a click on the other icon (the surround slides, the panels move, the strip changes width or goes full width); the same with "Reduce motion" on; Tab, arrows and Space on the toggle; the reset icon unchanged; quit and reopen to see the choice restored. Stop after the fix.
