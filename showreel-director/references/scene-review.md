# Scene-by-scene review (gate before generation)

Purpose: the user decides on every scene, one at a time, before any code is written. A storyboard approved as a block hides disagreements that surface later as expensive rebuilds. The review turns each scene into an explicit decision (OK, MODIFY or DITCH), keeps the film coherent as scenes change, and ends with a rewritten storyboard and an explicit go.

## Sequence
1. Brief approved, style sheet approved, storyboard drafted and checked (`storyboard-review.md`, `feasibility.md`). Give every scene a stable ID (S01, S02…); the IDs stay the same in all later feedback rounds.
2. Review the scenes in order, one per question, until the user decides.
3. After the last scene, run the global pass, rewrite the storyboard, ask for the go.
4. Only then start the build (Step 3).

## The scene card (what the user sees for each scene)
Keep it short and scannable, in the conversation language:
- **S07 · bars 12–14 · 21.3–27.1 s (5.8 s)** and its section (for example "solution").
- **Role:** why the scene exists (the message or feeling it carries) and what the film loses without it.
- **On screen:** the text (master language, plus the other reel languages when they differ in length), the image and motion, the chosen effects (named as in the catalogue).
- **Feeling and tension:** level (low / rising / peak / release) and the music event it sits on, if any.
- **Assets:** files used and anything flagged (placeholder, unvalidated figure, pending authorisation).
- **Numbers:** display time versus reading need (characters ÷ 17 per second), words on screen, flashes.
- **Neighbours:** one line on what comes before and after.
A picture helps: when the session can render, add a still of the scene's key frame (see `engine.md`, contact sheets); otherwise describe the frame in one sentence.

## Optional visual sheet
`python3 scripts/build_scene_cards.py storyboard.md --out qa/scene-cards.html --title "<reel name>" --bg <hex> --fg <hex> --accent <hex> [--font <file> --family "<name>"]` turns the storyboard table into one card per scene (ID, time, text, image and motion, feeling and tension, gag or handoff, any other column) with OK / MODIFY / DITCH buttons, a note field for MODIFY, "OK for all remaining", running totals and a "Copy decisions" button. Present it before the review so the user can look at the whole film at once and paste back a first pass. Treat the pasted list as a draft: still confirm every MODIFY and DITCH in the conversation, scene by scene, as below. Pass the brand colours; the sheet imposes no look.

## The decision (one scene per question)
Options, in this order: **OK** (lock it), **MODIFY** (say what to change), **DITCH** (remove it), **OK for this scene and all the remaining ones** (to avoid fatigue on long films). The built-in free-text answer covers anything else (move, merge, split, add a scene, change the duration, "come back to this one later").
- **MODIFY:** ask what to change in one follow-up with quick suggestions (text, image or motion, duration, effect, feeling, asset), apply it, show the updated card, and ask again. Repeat until the user says OK or DITCH. Never move to the next scene while a scene is unresolved, unless the user asks to postpone it (then mark it OPEN and return to it before the global pass).
- **DITCH:** show the consequence before confirming: the gap in time and tension, and propose how to close it (stretch a neighbour, add a breath of silence, merge with a neighbour, replace with a lighter scene). Re-snap the timeline to bars.
- **OK:** mark the scene LOCKED. A locked scene is reopened only if the user asks or a later change forces it (say so, and ask).
Keep a running line after each decision: scenes kept / ditched / modified, time used out of the total, bars, words on screen, and the tension curve in one line (for example "low · rising · peak · release").

## Impact after each change
After every MODIFY or DITCH, recompute the timeline on the beat grid, re-run `scripts/feasibility.py` with the new totals, and check three things: the emotional arc still builds and releases, the one-sentence message and each chosen attribute are still demonstrated, claims still match their sources. Tell the user only what changed or what now fails.

## Global pass (after the last scene)
1. Re-run the full checks: `storyboard-review.md` (including feasibility, readability, accessibility, emotional arc, message and attributes) and the release gate.
2. Translations: show every line of the other reel languages once, grouped, for approval or adaptation (humour and idioms), unless the user reviewed them scene by scene.
3. Rewrite `storyboard.md` as the next version (keep the previous one as an archive file): per scene ID, final timing, text per language, image and motion, effects, feeling and tension, assets, status (OK / MODIFIED / DITCHED with the reason), plus a change log.
4. Update `brief.md`: duration, structure table, decisions log, open items.
5. Show a compact summary of the new storyboard (scene list with times and a one-line description) and ask for the **go**. Generation starts only on an explicit yes. If the user asks for more changes, loop back to the affected scenes only.

## Why the order matters
Ditching or reshaping a scene shifts every later start time and changes the arc; reviewing in order lets the skill re-snap the timeline and rebalance tension as it goes instead of repairing everything at the end.
