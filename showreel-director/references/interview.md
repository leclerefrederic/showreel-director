# Interview question bank

Use as a menu, not a script. **Depth and express mode** are defined once, in `references/step-1-interview.md` (full interview / I propose, you correct / express, and the list of gates that are never skipped). Otherwise, in a full interview: skip answered items, merge related ones, keep each round to 4 questions max (question tool). Put the recommended option first. Free-text items go in one plain question at the end of the round.

## Round 0 — Languages (always first)
Ask both in one round so the difference is visible.
- **Conversation language**: the language used with the user during the project (questions, brief, storyboard notes, reports). Recommended = the language of the user's first message. Independent of the reel.
- **Reel language(s)**: **English by default**. Ask whether to add languages (switchable in the player), which one is the master text, and whether translations are adapted (idioms, jokes) or literal. Note fonts must cover every chosen language's glyphs.

## Round 1 — Mission
- **Purpose**: internal kick-off / customer or prospect pitch / event or keynote opener / social or web teaser / recruiting / launch. (Decides tone, claims strictness, length.)
- **Audience & context**: who watches, in what setting (big screen with sound, laptop in silence, phone feed), prior knowledge, language level.
- **Duration** (asked here, checked right after the round): no default and no cap; the user decides. Offer ranges that fit the purpose (for example short teaser, mid-length, long) with what each implies (number of scenes, text readability budget, file weight, attention span of the setting), and ask whether cut-downs are wanted (a short and a long version). Don't ask for the number of scenes; derive it. Run the feasibility gate (`references/feasibility.md`) as soon as duration and message are known and be candid about what does not fit. Playback: autoplay loop or one-shot with start screen.
- **Source material**: URL, deck, brief, CRM export, existing showreel/storyboard. Fetch it before asking more.
- **The message**: the one sentence the viewer should remember (free text), and what they should do or feel next (smile, curiosity, "I want a demo").
- **Perceived attributes** (pick up to three, multi-select): easy / simple / fun / robust and reliable / modern / cool / premium / human / innovative / fast / secure / accessible. Add the ones to avoid (for example "gimmicky", "cheap", "corporate"). Recommend the ones the brief and brand already suggest. For each chosen attribute ask what will *show* it rather than say it (a demo that takes three taps shows "easy"; a steady layout and calm pacing show "robust"; a surprise shows "fun").

## Round 2 — Story & voice
- **Arc**: problem → solution → proof → vision / teaser-mystery → reveal / before-after / tour of features.
- **Voice**: offer options derived from the brand and the brief, not from habit (for example institutional and calm / punchy and playful / dry and understated / neutral captions); put the one matching the brief first. Ask whether a recurring character or gag is wanted; don't suggest one unprompted.
- **Claims policy**: which numbers, partners, offers, funding models may appear; which must be labelled "Proposed — to be defined"; internal figures need source + date + "to be revalidated" line; names to hide.
- **Closing**: final line, call to action, logo, URL/QR, legal footnote.

## Round 2b — Emotion & soul
A showreel is remembered for what it makes people feel, not for what it says. Settle the intended feeling before the look, because it drives pace, music energy, colour temperature, type weight, silence and what the first and last seconds do. Ask these four with the question tool (multi-select where noted), then one free-text line.
- **Intended feeling** (pick up to two, multi-select): motivating / engaging / impactful / reassuring / convincing / inspiring / amused / intrigued / urgent. Add what it must **not** feel like (hype, fear, cringe, cold, salesy). Recommend the options that match purpose and audience from round 1.
- **Viewer shift**: from what to what? For example from "sceptical" to "willing to try", from "overwhelmed" to "in control", from "unaware" to "curious", from "worried" to "reassured". One sentence the viewer should be able to say afterwards (free text, last question of the round).
- **Tension shape**: steady and warm / problem tension released by the solution / slow build to one release / several tension and release cycles / a surprise twist near the end. Where it should peak, and whether there is a breath of silence before it.
- **Soul — the human anchor**: a character or recurring object, a real customer moment, the founders' conviction, a truth the audience recognises ("everyone has lived this"), humour, or none (pure product proof). Soul comes from a point of view and specific details, not from adjectives; ask for the one specific image, moment or line that only this brand could own.

Record the answers as the emotional arc in the brief: for each section of the film, the feeling and the tension level (low / rising / peak / release), plus the single memorable moment. Use `references/effects-catalogue.md` ("Feelings and tendencies") to translate feelings into motion choices, and check the storyboard against the arc in `storyboard-review.md`.

## Round 3 — Look & motion
- **References**: ask for one or two examples to resemble (and one to avoid). Describe what you take from them (palette, rhythm, transition families), never copy their content.
- **Visual language**: kinetic typography / geometric shapes and cells / UI-product-led (real screenshots) / illustrated / photo-led / mixed / 3D scenes (WebGL: perspective, particles, shaders, bloom; optional, adds about 0.8 MB, cannot be checked by the Node harness and has no MP4 export, so offer it only when depth is the point).
- **Brand frame**: follow brand guidelines strictly / inspired by / free. Dark or light base. Palette (give hex values if any).
- **Typography**: brand font (licence allows embedding?) or director's choice; display vs text pairing.
- **Visual devices**: characters that persist across scenes, crosswords/big letters, bubbles/documents/checks, procedural UI panels, maps, charts.
- **Energy curve** (follows the emotional arc from round 2b, don't ask twice): offer shapes that fit the purpose, for example steady and clean / slow build to one peak / calm → peak → calm / several peaks / fast throughout; where the key moment lands and what it is (flash, inversion, scale explosion, particles, camera punch, or none).
- **Motion vocabulary**: don't ask open-ended. Offer a pack (Deadpan, Kinetic punch, Clean product, Playful toy, Cinematic, Tech decode) from `effects-catalogue.md`, then 4 named options per category (text in, text out, transitions, emphasis, numbers, WOW, closing), filtered by the brand rules; how far shapes travel; flashes under 3/s.

## Round 4 — Sound, accessibility & delivery
- **Music**: user's track (file + title + licence) / licensed library pick / silent / synthesized (last resort). Which part of the song matters (drop, break, ending).
- **Sound design**: none (default) / light hits on key words / full SFX.
- **Narration**: none / user-supplied voice-over / synthetic voice. A cloned or synthetic voice needs the voice owner's consent, and some organisations require it to be disclosed: ask.
- **Accessibility**: must it be fully understandable muted? contrast level, flashing limit (under 3 per second by default), reduced-motion or plain version, captions always on.
- **Formats**: desktop 16:9 only / plus mobile 9:16 / MP4 export too (only if `check_env.py` shows node, ffmpeg and `@napi-rs/canvas`, see `scripts/export_mp4.js`: check first and say so; otherwise offer HTML plus capture instructions). (9:16 changes layout design, so decide now.) If 9:16 is chosen and the product screens are landscape, ask how to show them: crop, device frame, or redraw procedurally.
- **Controls** (ask as a multi-select checklist so nothing is forgotten, and keep consistent with the playback choice from round 1): start screen with/without sound · pause/play · seek bar · mute and volume · replay button at the end *or* loop (not both unless asked) · language switch · format switch (16:9 / 9:16) · fullscreen · reduced-motion toggle (shown by default; say if it should be hidden) · captions always on.
- **Sharing**: private artifact / link shared with a team / file attached to an email / event machine offline. Size limit for the HTML.
- **Process**: deadline, number of feedback rounds expected, who validates wording and claims.

## Round 5 — Asset inventory
Ask per class; for each answer record *provided / to fetch / procedural / not needed*.

| Class | What to ask | Production impact |
|---|---|---|
| Logos | SVG or transparent PNG, light and dark versions, clear-space rule, may it be animated | Placement in intro/outro, colour on dark base |
| Brand rules | Guidelines PDF, palette, do/don't | Style sheet |
| Fonts | Files (woff2/ttf/otf) and licence for embedding | Base64 inline; else closest free substitute, said aloud |
| Product visuals | Screenshots, UI recordings, mockups, diagrams, resolution, any with real customer data | Scenes built on real UI; sensitive data is painted over or replaced in the pixels of the copy in `assets/` before embedding (a render-time blur leaves the original inside the file), then check the result |
| Footage / animation | Video clips, Lottie, GIF | Canvas cannot seek video exactly: prefer frame sequences or stills, keep short and light |
| Photos / illustrations | People, places, icons, licence and consent | Size budget; no recognisable third-party people without rights |
| Data & proof | Figures, quotes, customer names, logos of partners, source and date | Claims policy, footnotes |
| Audio | Track, stems, beat map or BPM, voice-over, SFX | Beat map analysis, sync |
| Prior material | Existing deck, storyboard, earlier reel or version folder, text already approved | Reuse wording, layouts, decisions |
| Style references | A video, reel, site or earlier HTML to resemble (or to avoid) | Extract palette, typography, transition families, rhythm and scene length into the style sheet; ask what to keep and what to change. A reference informs, it is not a template to copy |
| Narration | Script, voice-over or voice clone files, language(s) | Scene timing from the audio, captions from the script; sync scenes on the words |
| Legal | Mandatory mentions, disclaimers, trademarks | Footnote scene |

After the audit, run `scripts/organize_assets.py` (see `references/assets.md`): held files (real data, forbidden font, unconfirmed rights) go on a decision sheet as Exclude (recommended) / Provide a redacted copy / Confirm rights (needs a note). Check orientation and format against the chosen aspect ratios. Run `scripts/audit_assets.py` on the folder where the supplied files are (the uploads or connected folder; `assets/` does not exist yet) first and use its flags as questions. After receiving files: list each with type, size, resolution, licence status and the scene where it will appear; flag anything too heavy (budget the base64 total, e.g. under ~25 MB for an email-able HTML), low-resolution (<2× its display size), unlicensed or containing personal data. Ask the user to fix or accept each flag.

## brief.md template

```
# Brief — <project> (version v1, <date>) — written in the conversation language
## Mission: purpose · audience · setting · duration · key takeaway
## Message & perception: the one-sentence message · next action · perceived attributes (and ones to avoid) with the proof that shows each
## Emotion & soul: intended feelings (and ones to avoid) · viewer shift (from → to, the sentence they should say) · tension shape and peak · human anchor / memorable moment · arc table (section · feeling · tension level)
## Story: arc · conversation language · reel languages (master first, default English) · voice/persona · claims allowed / labelled / forbidden · closing
## Look & motion: references (take / avoid) · style · palette (hex) · type · devices · energy curve · key moment · effects pack and per-category choices · forbidden effects
## Sound, accessibility & delivery: track (title, licence, key moments) · sound design · narration (source, consent) · accessibility choices · formats · controls · exports possible · sharing · deadline
## Feasibility: duration (and cut-downs, each with its own duration and scene list) · structure table (section · seconds · scenes · words · feeling/tension) · checks run and decisions taken on anything not feasible
## Assets manifest (the scene column is completed in Step 2b)
| file | role | scene | status (proposed / approved / excluded / placeholder / hold) | licence note (file) | weight | notes |  (generated by `organize_assets.py --md`)
## Assumptions (things the user delegated)
## Decisions log (approved wording, rejected ideas)
## Release gate (must be resolved before the reel leaves our hands): placeholders, unvalidated figures, pending authorisations, legal line
## Open items (owner, due date)
```

## Consistency review

Before writing the brief. Re-read all answers once and fix contradictions yourself or ask one short question. Check at least: **brief completeness** (no section empty: each is answered, confirmed or recorded as an assumption), cut-downs (each with a duration and scene list), playback (one-shot + replay vs loop), controls list complete (start screen, pause, seek, mute/volume, replay or loop, language and format switches), formats vs assets (a landscape screenshot in a 9:16 reel needs a stated treatment), claims vs sources (every figure on screen has source, date, label; the legal line covers every source and date used), timing (`bar = 4×60/BPM` seconds; use the beat map from `analyze_audio.py`, never count by hand), weight budget vs embedded assets, fonts vs languages (glyph coverage), requested outputs vs what the tools can produce, message and attributes vs choices (feasible counts and text budgets per the feasibility check, a "simple" film with dense screens, a "robust" one with jittery motion), emotion vs choices (a reassuring film with fast cuts and flashes, an impactful one with no contrast moment, a tension peak with no music drop to land on).

## Environment check (detail)

Run `python3 scripts/check_env.py` (add `--json` to parse it) to see which tools the session has: Python with numpy and ffmpeg (audio analysis), Node (automatic tests), optional fontTools, brotli, jsdom, `@napi-rs/canvas` (MP4 export) and a headless browser. Tell the user in plain words what is missing and what it changes (for example "no Node: I can't run the automatic tests, so verification relies on contact sheets and your eyes"; "no canvas package: no MP4 export"). Never install anything without asking; if the user agrees, use the install hint the script prints. A missing required tool means falling back to the manual method it lists, and saying so in the brief (for example "beat map entered by hand, to be checked by ear"). Use the result to answer honestly in round 4 about MP4 export and about what will be verified.
