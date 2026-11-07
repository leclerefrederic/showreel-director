# Feasibility and standards

Purpose: be a critical director, not an order taker. When the requested duration, number of scenes (shots), amount of text, languages or formats cannot work together, say so with numbers, explain which standard or finding backs the limit, and propose workable options. Never silently comply, and never silently shrink the request either.

## When to run it
1. **After round 1** (duration, purpose, message known) and again **after round 2b** (arc known): propose a structure (sections, seconds, scene count) and check any count the user volunteered.
2. **After the storyboard** (`storyboard-review.md` check 1 uses these numbers).
3. **Whenever the user changes** duration, scene count, text, languages, formats or track. Re-run `python3 scripts/feasibility.py` with the new figures.
4. If the user gave counts ("30 shots in 10 seconds"), check them immediately, before any other work except round 0.

Ask for the duration in round 1 (target plus any cut-downs wanted, for example a short and a long version). Do not ask the user for the number of scenes: derive it from the duration, the message and the text, then show it. Check counts only when the user states them or supplies a storyboard.

## Evidence base (state which kind of source backs each limit)
| Topic | Value | Kind of source | How it is used |
|---|---|---|---|
| Subtitle event duration | minimum 5/6 s (five sixths of a second, 0.83 s), maximum 7 s; up to 42 characters per line, 2 lines | Industry guideline: [Netflix Timed Text Style Guide](https://partnerhelp.netflixstudios.com/hc/en-us/articles/215758617-Timed-Text-Style-Guide-General-Requirements) | absolute floor for any text event; essential text longer than 7 s should be split |
| Reading speed on screen | about 17 characters per second for adult subtitles (commonly cited; check the current guide) | Industry guideline | characters per scene = 17 × seconds the text is fully visible |
| Silent reading rate | about 238 words per minute for adult English non-fiction (about 4 words per second), with a range of roughly 175–300 | Research: Brysbaert 2019, [Journal of Memory and Language](https://www.sciencedirect.com/science/article/abs/pii/S0749596X19300786) | upper bound for reading plain text with full attention; a reel with visuals competing needs far less (see budgets) |
| Contrast | text 4.5:1, large text 3:1 | Standard: [WCAG 2.2, 1.4.3](https://www.w3.org/TR/WCAG22/) | colour checks |
| Flashes | no more than three flashes in any one-second period | Standard: WCAG 2.2, 2.3.1 (verify the full text) | flash limit, applies to strobing and full-frame flashes |
| Moving content | content that starts automatically, lasts more than 5 s and sits next to other content needs a way to pause, stop or hide | Standard: WCAG 2.2, 2.2.2 (verify the full text) | the player must offer pause |
| Reduced motion | honour the user's `prefers-reduced-motion` setting | Web standard (CSS media query) | plain version or toned-down motion |
| Interface motion durations | around 300 ms typical, over 400 ms feels slow in UI; exits shorter than entrances | Design system guidance: [Material Design](https://m1.material.io/motion/duration-easing.html) | lower bound for entrances in interface-like motion; film-like or expressive reels may go longer |
| Average shot length | feature films about 4–6 s in recent decades (Bordwell, via Cinemetrics data), action films about 4 s | Film-studies data: [Cinemetrics](https://cinemetrics.uchicago.edu/) | sanity reference: a text-bearing reel scene below 2–3 s is faster than most action films |
| Loudness | broadcast target −23 LUFS (±0.5 LU), true peak ≤ −1 dBTP; streaming platforms commonly normalise near −14 LUFS | Standard: [EBU R 128](https://tech.ebu.ch/docs/r/r128.pdf); platform figures vary, verify | check the embedded track's level, no clipping |
| Frame size and rate | 1920×1080 (16:9), 1080×1920 (9:16), 1080×1080 (1:1), 1080×1350 (4:5); 24/25/30/60 fps | Industry practice, verify per platform | export and stage proportions |
| Voice-over pace | about 130–170 words per minute | Industry rule of thumb | narration word budget |

Platform specifications (maximum length, safe zones, loudness) change: when the destination matters, search the platform's current documentation instead of trusting this table. Rules of thumb below are labelled as such; do not present them as standards.

## Derived budgets (rules of thumb built on the evidence above)
- **Text scene length.** Display time = entrance (0.4 s) + reading (characters ÷ 17) + hold (0.3 s) + exit. Floor 1.5 s for one to three words, about 3 s for a line of six to eight words. Absolute minimum for any text event: 5/6 s.
- **Scenes that carry text.** Comfortable: duration ÷ 5. Stretch: duration ÷ 3. Beyond that the text cannot be read.
- **Visual-only beats** (no text to read): each needs about 1–2 s to register, down to about 0.5 s inside a dense montage; below 0.5 s they are accents (flashes, hits), not scenes, and must respect the flash limit.
- **Words on screen.** Average at most about 2 words per second over the whole film (a quarter to a half of reading capacity, because visuals compete and animation takes time). Cut explanations first.
- **Transitions** consume time: 0.3–0.6 s each; count them in the scene length.
- **Narration.** Words ≤ duration × 2.2 (about 130 wpm net of pauses); with narration, on-screen text becomes emphasis only.
- **Music.** Bar length = 240 ÷ BPM seconds. End on a bar boundary, start scenes on beats and phrase them in 1, 2 or 4 bars; at 124 BPM a bar is 1.94 s, so a 60 s film is about 31 bars.
- **Languages.** Plan for translated text to run longer than English (commonly 20–35% for French or German); shorten the master text or reduce the words.
- **Portrait 9:16.** About 20–24 characters per line at readable size, so budget fewer words or more lines and longer holds.
- **Unique compositions.** Count distinct scene compositions: beyond about 20 unique compositions, expect more feedback rounds.

Reference capacity (scenes that carry text, derived from the formulas): 10 s → 2 comfortable, 3 stretch; 30 s → 6 / 10; 60 s → 12 / 20; 90 s → 18 / 30. Visual-only montage can roughly double these counts.

## How to answer when something is not feasible
Keep it short and constructive: (1) what was asked and what it implies in numbers ("30 shots in 10 s is 0.33 s per shot"), (2) why it does not work, naming the standard or finding, (3) two or three options with their trade-offs, recommended first, such as a longer film, fewer and bigger scenes, a visual-only montage with the text moved to a caption or the accompanying message, a short cut-down plus a long version, or a series of films. Then ask which option to take. Record the decision and the numbers in the brief.

## Structure proposal (show before the look is decided)
A short table: section (hook, problem, solution, proof, closing…), start–end seconds, scene count, words on screen, feeling and tension level. Common practice puts the first impression within the first few seconds and a closing frame held long enough to read (about 3 s or more, longer for legal text). Run `scripts/feasibility.py` on the totals and fix before moving on.
