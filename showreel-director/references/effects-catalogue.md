# Effects catalogue

Purpose: users rarely know the vocabulary of motion design, so they describe an effect vaguely ("something that hits", "smooth") or pick something generic. Offer a named, curated menu so they can point instead of describe, and so the result is never default-looking.

## How to use it
1. **Pack first, details second.** In round 3 offer 3–4 *packs* (below) as the first question; the pack pre-selects a coherent set. Then offer a multi-select per category the user cares about (text in, text out, transitions, emphasis, numbers, WOW, closing), showing 4 named options each with a one-line description. Never list the whole catalogue at once: pick the 4–6 entries that fit the brief (tone, brand rules, energy curve, muted-readable, mobile).
2. **Name + picture in words.** Each option = short name + what the viewer sees ("Slam: the word drops in oversized and settles with a small shake"). Recommended option first.
3. **Brand rules filter the menu.** Remove effects the charter forbids (e.g. glitch, gradients, shadows, tilted logo) before offering anything, and say why they are absent.
4. **Translate vague requests.** "Ça claque / punchy" → slam, zoom punch, flash cut. "Doux / élégant" → fade, soft rise, mask wipe. "Drôle / pince-sans-rire" → small type then scale explosion, stamp, late arrival gag. "Moderne / tech" → scramble decode, slot roll, hard wipe. "Cinéma" → slow push-in, spotlight, silence then hit. Restate your reading in one line and let the user correct it.
5. **Show, don't only tell.** As soon as effects come up, hand the user `engine/effects-lab-sample.html` (neutral, works offline) so they can browse while you ask questions, then rebuild it in their palette. Build the effects lab (`scripts/build_effects_lab.py`, in the brand palette and font) and present it: every effect animated and named, the user's own sample text, hearts to pick, a button that copies the picks to paste in the chat. The previews show the idea with plain canvas code, not the final render, and the names match this catalogue or `effects-index.md` (248 effects, 11 categories incl. UI & product scenes, Camera, Graphic treatments). If the lab cannot be opened, describe the 4–6 candidates in one line each.
6. **Record the choice** in `brief.md` under Motion vocabulary: chosen pack, effects per category, forbidden effects, and which effect is reserved for the WOW (a WOW effect is used once only).
7. **Variety rule.** Per scene use one entrance family and one accent effect; across the reel reuse the same 5–7 effects so it feels designed, and save the biggest effect for the strongest beat.

## Perceived attributes and design cues (starting points, not rules)
| Attribute to convey | Design cues |
|---|---|
| Easy / simple | few elements per scene, generous space, short lines, smooth easing, a flow shown in few steps |
| Fun | bounce and overshoot, surprise, colour, a character, humour in small type |
| Robust / reliable | heavy type, stable grids, regular rhythm, no jitter, proof with numbers and sources |
| Modern | clean grotesque type, restrained palette, crisp wipes and masks, generous alignment |
| Cool | restraint, dark or high-contrast base, confident silence, minimal text, precise timing |
| Premium | slow easing, long holds, fine type, limited palette, no gimmicks |
| Human | people or hand-made details, warm colour, imperfect motion, real voices or quotes |
| Fast | tight cuts, count-ups, whip pans, short lines on beats |
| Secure | calm pacing, locks and checks as quiet props, dark stable base, no flashes |
Show the attribute through what happens on screen; a word like "simple" written on screen proves nothing.

## Feelings and tendencies (starting points, not rules)
| Intended feeling | Pace and rhythm | Motion and effects | Colour, type, sound |
|---|---|---|---|
| Motivating | rising energy, cuts on beats, forward motion | pop, fly in, push, count-up, zoom punch | warm accents, bold type, music with drive |
| Engaging / playful | varied rhythm, surprises, direct address | bounce, elastic, stamp, late arrival, character moments | saturated palette, friendly type, light sound hits |
| Impactful | few words, long holds then sudden hits | scale explosion, slam, silence then hit, flash cut | strong contrast, heavy type, a drop on the key moment |
| Reassuring | slow, steady, generous holds | soft fades, gentle rise, consistent layout, calm morphs | calm palette, regular type, no flashes, soft music |
| Convincing | structured, one claim at a time, proof at calm pace | before/after bars, slot roll, counters, source footnotes | restrained palette, clear hierarchy, real product evidence |
| Inspiring | slow build, wide shots, open ending | slow push-in, curtain open, spotlight, build and snap | light or open space, music swell, final image left to breathe |
| Intriguing | withholding, partial reveals, delayed payoff | mask wipe, scramble decode, silence before reveal | dark base with a single accent |
| Urgent | fast rhythm, tight cuts | whip pan, shake cut, countdown, speed ramp | high-contrast warm colour; avoid if the brand is built on trust |

**Tension tools:** withhold information, slow down, shrink the scene, go quiet, delay the reveal, contrast calm with chaos, leave a question open. **Release tools:** the drop, the reveal, scale, a resolving image, a laugh, a breath of silence. **Soul** comes from a point of view and one specific detail, not from adjectives: a recurring object or character, a truth the audience recognises, a line only this brand could say.

## Packs (starting points)
| Pack | Feel | Typical effects |
|---|---|---|
| Deadpan | Calm, precise, comic by contrast | fade, soft rise, stamp, wind exit, scale explosion on one word, flash cut |
| Kinetic punch | Loud, beat-driven | slam, zoom punch, letter stagger, shake cut, whip pan, particle burst |
| Clean product | Corporate, clear, reassuring | mask wipe, line stagger, slide push, count-up, underline draw, fade to logo |
| Playful toy | Bouncy, colourful | pop, elastic overshoot, bounce, squash and stretch, domino, confetti |
| Cinematic | Slow, dramatic | blur-in, slow push-in, spotlight, silence then hit, curtain open |
| Tech decode | Digital, fast | scramble decode, slot roll, hard wipe, grid reflow, ticker (glitch only if brand allows) |

## Text — entrances
| Effect | What you see | Best for | Energy | Watch out |
|---|---|---|---|---|
| Fade | Opacity in | calm lines, legal text | low | none |
| Rise | Slides up a few px while fading in | default subtitle | low | keep distance small |
| Fly in (L/R) | Slides in from the side with ease | lists, side labels | mid | keep left edges consistent |
| Drop | Falls from above, small settle | humour, weight | mid | do not overlap content below |
| Pop | Scales from 0 with slight overshoot | labels, icons, keywords | mid | no pop on every line |
| Zoom | Scales down from oversized | key words | high | clip at frame edge |
| Slam | Oversized, lands with shake | scale explosion, hero word | high | one per scene max; test long words |
| Typewriter | Letters appear one by one with caret | deadpan, tech | mid | needs ≥3 s total |
| Letter stagger | Each letter rises with offset | titles, brand names | mid | phase offsets, not mechanical |
| Word stagger | Words arrive on successive beats | rhythm lines | mid | align on beats |
| Mask wipe | Text revealed by a moving edge | clean product | low–mid | hard edge looks sharper than soft |
| Scramble decode | Random glyphs resolve into the text | tech, reveal | mid | fixed-width feel, keep short |
| Blur-in | From blurred to sharp | cinematic | low | heavy on mobile canvas, use sparingly |
| Elastic overshoot | Springs past its place and back | playful | mid | avoid on legal/serious lines |

## Text — exits
| Effect | What you see | Best for | Watch out |
|---|---|---|---|
| Fade out | Opacity out | calm | slow if overused |
| Wind exit | Letters blown away left to right | before a transition | needs ~0.6 s |
| Drop out | Falls off the bottom | comic | pair with a floor-drop transition |
| Slide out | Leaves in the entry direction reversed | lists | consistent direction |
| Shrink to corner | Becomes a small title, stays | persistent title | keep readable |
| Strike and replace | Strike-through, new word replaces | corrections, humour | needs 2 s |
| Shatter | Breaks into tiles/pieces | explosion | do not stack with confetti |

## Text — emphasis
Pulse on the beat · RGB split (only if brand allows) · underline draw · highlight swipe · outline-to-fill · shake · colour swap to accent · scale-up on one word · stamp (rotated outlined rubber-stamp aside) · small caps whisper (tiny type for small ideas).

## Numbers and proof
| Effect | What you see | Best for |
|---|---|---|
| Slot roll | Digits/words roll like a slot machine to the new value | before → after swaps |
| Count-up | Number climbs to its value | growth, volume |
| Odometer | Mechanical digit wheels | precision, fun |
| Bar compare | Two bars of different length | before/after |
| Ring fill | Circular progress | rates (only if validated) |
| Strike and replace | Old value crossed out, new one lands | corrections |
Always show source, date and label ("pilot results, to revalidate") with a figure; size the hero number to fit its width.

## Scene transitions
| Effect | What you see | Energy | Watch out |
|---|---|---|---|
| Cut on beat | Hard cut exactly on a downbeat | any | the safest default |
| Flash cut | White/colour flash then new scene | high | max 3 flashes per second |
| Ink/paper inversion | Background and content swap polarity | high | save for the WOW |
| Hard wipe | Edge sweeps across the frame | mid | direction consistent |
| Shape wipe / iris | Circle or shape opens or closes | mid | clear shape language |
| Push / slide | New scene pushes the old one out | mid | keeps continuity |
| Whip pan | Fast slide with streaks | high | motion streaks drawn procedurally |
| Zoom punch | Quick scale-in on a detail, cut | high | use at drops |
| Morph | Shapes interpolate into the next layout | mid | the shape engine's native move |
| Match cut | A shape in scene A becomes a different object in B | mid | needs planning, memorable |
| Shatter / disperse | Elements scatter into tiles | high | pair with a silence |
| Floor drop | Everything falls off the bottom | mid | comic, deadpan |
| Curtain | Two panels part or close | low–mid | theatre feel |
| Page turn | Corner peels | low | skip for tech tones |
| Colour flood | Accent colour fills then recedes | mid | respects "no gradient" |
| Speed ramp | Motion accelerates then freezes | high | needs strong easing |
| Freeze and stamp | Freeze, stamp lands | mid | deadpan |

## Shapes and motion
Pop in place · scatter/gather · orbit · bounce · elastic snap · magnetic snap · domino · wave · pulse · stack/tower · grid reflow · parallax drift · slow push-in · camera punch · shake · squash and stretch · late-arrival gag (a tile flies in a few beats after the others) · character identity (same colour and index across scenes).

## WOW reveals (use one, once)
| Effect | What you see | Needs |
|---|---|---|
| Flash + inversion | Strongest drop: flash then polarity swap, logo appears | a drop in the track |
| Silence then hit | Sound or motion drops out, then everything lands | sparse bar before the drop |
| Scale explosion | One word grows beyond the frame | a short word |
| Shatter to logo | Pieces reassemble into the logo | logo as vector |
| Curtain open | Panels part to reveal | calm scene before |
| Spotlight | Light sweeps and reveals the product | dark base |
| Build and snap | Elements assemble slowly, then snap together on the beat | a riser |

## Closings
Fade to logo · hold with one small check pop (no confetti) · tagline typed · iris close · single confetti bouquet at the very end · logo construction (build the mark) · end card with CTA and legal line (≥4 s for long legal text).

## Mobile 9:16 notes
Prefer vertical stacks and centred text; wipes and pushes should travel vertically or be centred; avoid effects that need the full 16:9 width (long whip pans, wide shatters) unless remapped.
