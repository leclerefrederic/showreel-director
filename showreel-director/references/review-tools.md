# Review tools: which one to use for which decision

Rule: the user never approves a block of text. A decision goes through the question tool or through a page the user operates. Long content lives in a file; the file is presented and then validated with one of the tools below. Every tool returns a *draft* that the skill still confirms in the conversation when something changes.

| Need | Tool | How |
|---|---|---|
| 1 to 4 decisions, plain choices | question tool | max 4 questions per round, 2 to 4 options, recommended first, one short sentence of context |
| 5 or more decisions at once, or any decision that needs to be seen (colours, type, structure options, cut-downs, brief sections, release gate) | **decision sheet** | `python3 scripts/build_decision_sheet.py spec.json --out qa/<name>.html --bg … --fg … --accent …` |
| Effects the user likes | effects lab | `scripts/build_effects_lab.py` (hearts, "Copy my picks") |
| Scenes of the storyboard | **scene cards** | `scripts/build_scene_cards.py storyboard.md --out qa/scene-cards.html …` (timeline strip, reading-speed warning per scene, OK / MODIFY / DITCH) |
| Look of the first frames | look test build | see "Look test" in `build-guide.md`: a build of 2 or 3 scenes, opened in the player |
| Feedback on the built reel | review build with the **notes pad** | `controls.notes: true` in `main.js` for review builds only; key N or the Note button pauses and stamps time, scene, format and language; "Copy notes" puts them on the clipboard |

If the session cannot present files, use the question tool for the same decisions (split into rounds of 4) and say what is different (see `portability.md`).

## Decision sheet: spec and guardrails
A JSON file with `title`, `intro` and up to 30 `items`. Each item has `id`, `title`, a short `body` (600 characters at most; longer content goes in a file), 2 to 4 `options`, and optionally `swatches` (hex colours), `sample` (`{text, css}` type specimen), `multi`, `note`. Options can carry `recommended` and `needs_note`.

```json
{ "title": "Style sheet", "intro": "Pick one option per line.",
  "items": [
    { "id": "palette", "title": "Palette", "body": "Teal and white on a dark base.", "swatches": ["#0a7d78", "#ffffff", "#101820"],
      "options": [ {"label": "Keep", "recommended": true}, {"label": "Warmer accent"}, {"label": "Change", "needs_note": true} ] },
    { "id": "fig-42", "title": "Open: figure 42% has no source", "body": "Scene S05.",
      "options": [ {"label": "Resolve first", "recommended": true}, {"label": "Waive and accept the risk", "needs_note": true} ] } ] }
```

Built-in guardrails (do not remove them): nothing is pre-selected, the recommended option is only highlighted; "Accept all recommended" is a separate button and never accepts an option that needs a note; "Copy decisions" stays disabled until every item is decided and every required note is written; text is escaped, never interpreted as HTML; the builder refuses a spec with fewer than 2 or more than 4 options, duplicate ids, bad colours or an over-long body. Pass the brand colours once known; before that, use the defaults.

## Typical sheets
- **Brief review** (Step 1): one item per section of the brief that carries a decision (message and audience, feeling and look, sound, delivery, assets), options Keep / Change (needs a note).
- **Style sheet** (Step 2): one item per line with real alternatives; palette items carry swatches, type items carry a specimen with the line of the message in the chosen font.
- **Structure options** (feasibility): two or three workable structures as options (sections, seconds, scenes, words), recommended first.
- **Cut-downs**: which cuts to build (full, short), what each drops.
- **Release gate** (Step 5): one item per open point (placeholder, unvalidated figure, pending authorisation); options Resolve first (recommended) / Waive and accept the risk (needs a note). Waivers are written to the decisions log of `brief.md` with the note.
- **Audio check**: confirm tempo, first beat and the moments the music sheet proposes (drop, breakdown return, ending).
