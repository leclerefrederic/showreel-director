# Brief — Ploma showreel (version v1, 2026-11-07)

Ploma is a FICTIVE brand and product (test project). Source: `assets/source/brief-ploma.md`.

## Mission
- **Purpose:** opening of the annual sales meeting (room, big screen, sound) + emailed to SME/mid-market prospects.
- **Audience:** salespeople and prospects (site managers, maintenance team leads, engineering offices; 20–500 field staff).
- **Setting:** big screen with sound; laptop often muted; sometimes phone.
- **Duration:** ~60 s (track is 61.9 s).
- **Key takeaway:** « Le terrain n'attend plus le bureau ».
- **Reaction:** a smile, then « je veux une démo ».
- **Muted rule:** fully readable without sound; music only adds energy.
- **Playback:** start screen (with / without sound), plays once, ends on closing frame with replay.

## Story
- **Arc:** problem → solution → proof → vision.
- **Languages:** FR primary (master text), EN switch (idioms adapted, not translated literally). Preselect from browser language.
- **Voice:** confident, concrete, deadpan master of ceremony. Short sentences. Banned: « révolutionnaire », « disruptif », « IA de nouvelle génération ». No AI jargon.
- **Recurring gag:** one orange paper-note tile followed from site to office; it gets lost without signal, then syncs itself.
- **Claims allowed (labelled):** pilot-study figures only, each with source + date + « résultats pilote, à revalider »:
  - 2.5 days field→office before Ploma (client pilot interviews, n=6, 2026-06-15)
  - 12 minutes field→office with Ploma (pilot measurement, 2026-09-30)
  - 38 notes per user per week (internal pilot study, 2026-09-30) — optional
- **Claims forbidden:** pricing / « un mois offert » (unvalidated hypothesis); number of pilot teams (confidential); 99.2 % sync rate (to be confirmed); any client name; quotes #2 (pending) and #3 (refused).
- **Quote allowed:** #1 only, anonymous: « On a arrêté de recopier nos notes le soir. » — chef de chantier, client pilote.
- **Closing:** « Ploma. Le carnet qui n'attend pas le réseau. » + mandatory legal line (see assets) + URL placeholder.

## Look & motion
- **Style:** kinetic typography + geometric shapes + 2 real product screens. No photos, no stock.
- **Palette (charte):** ink #10131F (base), paper #F6F1E7, orange #FF6B2C (action), mint #3DDBB0 (success / sync), violet #6C5CE7 (AI). No gradients, no heavy shadows, max 3 accent colours per scene.
- **Type:** Poppins Bold (titles) + Poppins Regular (text), embedded base64 woff2. PlomaDisplay NOT used (proprietary licence, no embedding).
- **Logo:** SVG light / dark only; clear space = height of the « p »; no distortion, rotation, shadow or glitch; fade-in or construction of the « p » allowed.
- **Devices:** persistent orange note tile, tiles/bubbles/checks/pins drawn procedurally, procedural UI props (signal bars, sync line in mint), geometric site-team and office illustrations.
- **Energy curve:** calm → build → explosion → calm. Scenes start on real bars.
- **WOW:** ink → paper inversion with flash at drop A (bar 10), reveals Ploma. Flashes under 3 per second.
- **Motion vocabulary:** rise, fly, drop, pop, slam, slot-roll word swap, wind exit; per-scene easing and phase offsets.

## Sound & delivery
- **Track:** `ploma-track-124bpm.mp3` « Ploma Drive », synthetic, CC0, 124 BPM 4/4, 61.9 s, 32 bars (1 bar ≈ 1.935 s).
- **Key moments (computed from bar length):** intro calm bars 1–4 (0–7.7 s); build bars 5–8 (7.7–15.5 s, riser bar 8); short break bar 9 (15.5–17.4 s); **DROP A bar 10 ≈ 17.4 s**; drop A runs to bar 17 end ≈ 32.9 s; break bars 18–21 (32.9–40.6 s); **DROP B bar 22 ≈ 40.6 s**; drop B to bar 29 end ≈ 56.1 s; outro bars 30–32 (56.1–61.9 s). (Beat map to be verified against the decoded audio.)
- **Sound design:** none.
- **Formats:** desktop 16:9 (1600×900) + mobile 9:16 (900×1600), switch on the start screen, preselected by orientation.
- **Controls:** start screen with / without sound, pause, seek, loop, FR/EN switch. Format switch on the start screen.
- **Sharing:** private self-contained HTML (artifact for review; final HTML file under 20 MB for email).
- **Process:** two feedback rounds; Fred validates wording and figures.

## Assets manifest
| file | role | scene | status | licence | weight | notes |
|---|---|---|---|---|---|---|
| brand/logo-ploma-sombre.svg | logo on ink | opening / closing | provided | brand | ~1 KB | OK, vector |
| brand/logo-ploma-clair.svg | logo on paper | post-WOW / closing | provided | brand | ~1 KB | OK, vector |
| brand/logo-ploma-web-petit.png | — | — | EXCLUDED | brand | 1 KB | 96×24 px, blurry when large |
| brand/palette.json, charte-ploma.md | style rules | all | provided | brand | ~2 KB | applied |
| fonts/Poppins-Bold.ttf | titles | all | provided | OFL 1.1 | 153 KB | embed as woff2 base64 |
| fonts/Poppins-Regular.ttf | text | all | provided | OFL 1.1 | 157 KB | embed as woff2 base64 |
| fonts/PlomaDisplay-Prop.ttf | titles (planned by brand) | — | EXCLUDED | proprietary, web licence not bought | 643 KB | replaced by Poppins Bold |
| product/ecran-01-accueil.png | real UI | solution scene | provided | internal | 39 KB, 1440×900 | OK |
| product/ecran-02-capture-vocale.png | real UI | capture scene | provided | internal | 30 KB, 1440×900 | OK |
| product/ecran-03-sync.png | spare | sync scene (optional) | provided | internal | 29 KB, 1440×900 | spare; sync drawn procedurally |
| product/ecran-04-clients-DONNEES-REELLES.png | — | — | EXCLUDED | contains personal-data-type content | 34 KB | not read for content; redraw procedurally with placeholders if needed |
| product/ecran-05-basse-resolution.png | — | — | EXCLUDED | internal | 4 KB, 480×300 | too small for full screen |
| photos/equipe-terrain.jpg | — | — | EXCLUDED | image rights NOT confirmed | 63 KB | replaced by geometric illustration |
| video/demo-terrain-brut.mp4 | — | — | EXCLUDED | internal | 14.7 MB | too heavy, test pattern, canvas can't seek video exactly |
| audio/ploma-track-124bpm.mp3 | music | all | provided | CC0 | 1.2 MB (≈1.6 MB base64) | beat map to compute |
| data/chiffres.csv | proof | proof scene | provided, filtered | internal | 1 KB | only 3 pilot rows, labelled |
| data/citations.md | quote | proof scene | provided, filtered | internal | 1 KB | quote #1 only |
| legal/mentions.txt | legal line | final scene | provided | — | 1 KB | placed in final scene, legible |
| icons, QR / URL, voice-over, storyboard | — | — | procedural / placeholder / none / by director | — | — | URL placeholder « URL à fournir » flagged on screen |

Estimated final HTML weight: ~2.5 MB (well under the 20 MB limit).

## Assumptions (delegated or defaulted)
- Muted-readable, start screen one-shot, smile-then-demo reaction (recommended options).
- 38 notes/user/week figure is optional, used only if it earns a scene.
- Storyboard written by the director, timed on the bar map.
- Mobile 9:16 gets dedicated text per scene.

## Decisions log
- Approved: arc, FR+EN, pilot-only claims, paper-note gag, kinetic type + shapes + 2 real screens, ink base, WOW inversion at drop A, Poppins, provided track without sound design, 16:9 + 9:16, pause/seek/loop/language controls, plan B for gaps.
- Rejected: PlomaDisplay font, PNG logo, screens 04 and 05, team photo, raw video, pricing, quotes #2 and #3, team count, 99.2 % figure.

## Open items
| item | owner | due |
|---|---|---|
| URL / QR for the closing scene | Fred | before final delivery |
| Approval of quote #2 (if wanted) | Fred | optional |
| Image-rights authorisation for the team photo (only if the photo is wanted) | Fred | optional |
| Validation of pilot figures and their « à revalider » labels | Fred | before final delivery |
| Web licence for PlomaDisplay (if the brand wants it later) | Brand | optional |

## Build notes (v1, 2026-11-07)
- Output: `v1/ploma-showreel.html` (1.8 MB, self-contained); sources in `v1/build/` (main.js, template.html, build.py, qa.js).
- Background plan: ink until drop A, paper (flash + circular wipe) through the sync break, back to ink at drop B for the proof, key line and closing.
- Closing line is shown as the logo (« Ploma. ») followed by « Le carnet qui n'attend pas le réseau. ».
- The 38 notes/user/week figure is not used. Real screens appear in French in both languages (screenshots are not translated).
- Not yet verified: audible sync in a real browser, playback on real phones.
