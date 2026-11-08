# Assets: folders, names, manifest

Every file a project contains has one home and a name that says what it is. The point: nothing generated or derived is ever mistaken for an original, the build only reads files that were explicitly prepared, and the manifest is the single list of what the reel contains.

## Folders (inside `<project>/assets/`)
| Folder | What goes there | Rules |
|---|---|---|
| `source/` | originals as received, with their original names and sub-folders | never modified, never embedded, never read by the build |
| `prepared/` | supplied files made ready to embed (copied as is, converted, resized, redacted) | convention names; the only place supplied files are embedded from |
| `generated/` | everything the skill makes itself: procedural images, rendered icons, frame sequences, synthetic voice, cut audio | convention names; registered in the manifest |
| `MANIFEST.csv` | one row per file | columns: id, file, original, origin, type, status, licence_note, scene, notes |

Other project files: `brief.md`, `style-sheet.md`, `storyboard.md` at the root (replaced versions go to `archive/` as `storyboard_v1.md`); builds in `vN/`; temporary pages in `qa/` named by kind (`contact-<vN>.html`, `cards-scenes.html`, `decision-<name>.html`, `lab-effects.html`); exports in `vN/dist/` named `<slug>_<vN>_<mode>_<lang>.<ext>` (slug from the reel title, mode `d` or `m`).

## Naming convention (prepared/ and generated/)
`<type>-<nn>-<slug>[_<variant>].<ext>`

| Part | Rule |
|---|---|
| type | one of `logo icon shot photo illus img font audio voice sfx video frames` (`shot` = screenshot or UI capture, `illus` = illustration, `img` = other image, `frames` = a folder of numbered frames) |
| nn | two digits, counted per type, never reused: a removed asset keeps its number in the manifest |
| slug | lowercase ascii words joined by hyphens, what it is: `ploma-clair`, `customers-list`, `poppins-bold` |
| variant | optional, after an underscore: `dark`, `light`, `redacted`, `2x`, `fr` |

Examples: `logo-01-ploma-clair.svg`, `shot-04-customers-list_redacted.png`, `font-02-poppins-bold.ttf`, `audio-01-track-124bpm.mp3`, `frames-01-sync-loop/`.

Files that are not embedded (data, quotes, brand guides, licences, notes) stay in `source/` and are listed in the manifest only if they matter to a decision.

## Lab and QA pages before the organiser has run
Fonts chosen in the font picker are fetched with `scripts/fetch_font.py` into a scratch folder and organised like supplied fonts (the licence file travels with them). The effects lab (round 3) comes before round 5, so it may use a font straight from the supplied folder; only embedded builds must use `prepared/` and `generated/`.

## Status
`proposed` (default after organising), `approved` (the user confirmed it may be embedded), `excluded` (kept out on purpose), `placeholder` (stands in for something to be supplied; must be on the release gate), `hold` (blocked until decided: real or confidential data, font licence forbids embedding, rights or consent not confirmed). `build.py` refuses `excluded` and `hold` for the track, fonts and images, and warns for `proposed`. Excluding an asset removes its copy from `prepared/` (the original stays in `source/`). Low-resolution images (under 800x450, or a small logo bitmap), heavy videos (over 5 MB) and heavy audio are put on `hold` automatically.

## Commands (`scripts/organize_assets.py`)
1. `python3 scripts/organize_assets.py <project> --from <folder>` (or no `--from` when files are already loose in `assets/`): plan only, changes nothing.
2. Put the held files on a decision sheet (`review-tools.md`), then `--apply`.
3. `--set shot-04=excluded,logo-01=approved`: record decisions. A file held for looking like real data cannot be approved directly: paint over the sensitive parts in a copy, check the pixels, then `--redacted shot-04=<path>`, then approve.
4. `--register` after the skill saves anything in `generated/`.
5. `--md` prints the manifest as the table for `brief.md` (the scene column is completed in Step 2b).
6. `--check` before the build and before delivery: names, manifest, stray files, held files (fails while any is `hold`; `--allow-hold` while deciding), excluded files left in `prepared/`, version paths (tracks, fonts, images).
