# Showreel Studio v2: a workspace with a copilot

Status: VALIDATED (revision 1 of 2026-11-09 awaiting validation: sections 5 and 10, source of truth in 5.1) by the owner on 2026-11-08 with the recommended choice for every point of section 11 (showreel.json plus markdown; copilot edits as proposals; one window per project; skill fully usable alone in Cowork; phases A to D in order). Build phase A first.

## 1. Idea

Today the chat is the centre: the assistant follows `SKILL.md`, asks questions, opens HTML pages for the user to pick things, and writes the files. In v2 the app is the centre and the assistant is a copilot inside it.

- The project folder is the source of truth. The user sees and edits every file (brief, style sheet, storyboard, assets, build) from the app. The assistant edits the same files, when asked.
- Pickers, the look board, scene cards and decision sheets are screens of the app that write their choices into the project. No "copy your picks and paste them in the chat".
- The app holds several projects.
- The skill stays usable on its own in a chat (Cowork): nothing in the skill is removed. The app is a second way to drive the same method.

## 2. What stays and what changes

| Stays | Changes |
|---|---|
| `showreel-director/` (method, engine, scripts, references) | Who drives: the app shows the steps and gates; the assistant proposes, drafts and builds on request |
| Reel output (HTML player, MP4, cuts) built by the existing scripts | Pickers and boards become native screens (SwiftUI) instead of generated HTML files |
| JavaScript effects and backgrounds engine as the renderer | The assistant's role in the system prompt: copilot, not interviewer |
| Agent loop, tools, Keychain, setup screen, self-test | Project model: several projects, structured decisions, per-project chat history |

## 3. Project model

```
<project>/
  showreel.json            structured state (section 3.1)
  brief.md  style-sheet.md  storyboard.md        prose, readable by humans and by the skill
  assets/  analysis/  v1/ v2/ ...  qa/  archive/  unchanged (see SKILL.md, Project layout)
  .studio/                 app-private: chat/<session>.jsonl, history/<file>/<timestamp>, ui.json
```

### 3.1 showreel.json (schema version 1)

```json
{
  "schema": 1,
  "name": "...",
  "created": "2026-11-08",
  "conversationLanguage": "fr",
  "reelLanguages": ["en", "fr"],
  "step": "style",
  "decisions": {
    "palette": ["#101820", "#F2AA4C", "#FFFFFF"],
    "fonts": { "titles": "Anton", "text": "Inter" },
    "background": { "id": "aurora", "mood": "cinematic" },
    "moods": ["Kinetic punch"],
    "effectsPack": "Kinetic punch",
    "formats": ["16:9", "9:16"],
    "duration": 45,
    "track": { "file": "assets/prepared/audio-01-theme.mp3", "bpm": 120 }
  },
  "gates": { "interview": "passed", "assets": "open", "release": "open" },
  "scenes": { "S01": { "status": "ok", "note": "" }, "S02": { "status": "modify", "note": "shorter" } }
}
```

Rules:

- `showreel.json` is canonical for structured decisions (palette, fonts, background, formats, gate states, scene review state). Prose files stay canonical for prose and for the storyboard table.
- The app writes a generated "Decisions" section into `brief.md` whenever `decisions` change, so the skill, in a chat, sees the same facts.
- Opening a project that has only markdown (made in Cowork) imports what it can (hex colours in the Look and motion section, fonts, languages) and asks the user to confirm. A project made in the app opens fine in Cowork.
- Scene IDs follow the skill's rule: stable, never renumbered, a ditched scene stays marked.

## 4. Process contract

`app-swift/shared/process.json` lists the steps and gates the app implements, in the order of the `Gates` table of `SKILL.md`:

```json
{ "steps": [
  { "id": "start",     "name": "Start",        "gate": "Round 0",       "produces": ["showreel.json"],        "screen": "NewProject" },
  { "id": "interview", "name": "Brief",        "gate": "Interview",     "produces": ["brief.md"],              "screen": "Brief" },
  { "id": "assets",    "name": "Assets",       "gate": "Assets",        "produces": ["assets/MANIFEST.csv"],   "screen": "Assets" },
  { "id": "style",     "name": "Look",         "gate": "Style sheet",   "produces": ["style-sheet.md"],        "screen": "Look" },
  { "id": "storyboard","name": "Storyboard",   "gate": "Storyboard",    "produces": ["storyboard.md"],         "screen": "Storyboard" },
  { "id": "review",    "name": "Scene review", "gate": "Scene review",  "produces": [],                        "screen": "SceneReview" },
  { "id": "build",     "name": "Build",        "gate": "Build",         "produces": ["vN/dist"],               "screen": "Build" },
  { "id": "verify",    "name": "Verify",       "gate": "Verify",        "produces": ["qa/"],                   "screen": "Verify" },
  { "id": "publish",   "name": "Deliver",      "gate": "Publish or share", "produces": ["exports"],            "screen": "Deliver" }
] }
```

`tools/check.py` fails when a gate named in the `Gates` table of `SKILL.md` has no step here, or the reverse, the same way it checks `capabilities.json`. A new capability, "The app drives the process with native screens", is added to `portability.md` and `capabilities.json`, so the skill knows that "pages the user operates" are screens in this mode.

## 5. Screens (revision 1: functional blocks, no files)

Principle: the user works with the film, never with files. Markdown, JSON and CSV are the assistant's working material. They stay in the project folder but are not shown in the interface, except in an "Advanced" panel (off by default) for debugging, and "Show in Finder".

Window per project. Left sidebar = the functional blocks, in the order of the process, each with a status (to do, in progress, validated):

| Block | What the user does | Stored in |
|---|---|---|
| **Project** | Name, audience, message, languages, formats, duration, tone, sound choice, constraints. Form with the interview's questions as help text, feasibility result shown inline. | `showreel.json` (`parameters`) |
| **Look and technique** | Palette (colour wells, contrast check), fonts (real specimens), background, motion mood, effects pack, music and beat grid. Native pickers with live thumbnails from the engine. | `showreel.json` (`decisions`) |
| **Resources** | All attached assets as a grid or list: drag and drop files in, status (approved, excluded, hold + note), licence note, which scenes use it, replace, remove. | `assets/` + `MANIFEST.csv` |
| **Storyboard** | The film as a timeline of scenes: add, reorder, split, ditch; text, timing, feeling; gate "Storyboard validated". | `showreel.json` (`scenes`) |
| **Scene editor** | One scene at a time: on-screen text, image/asset, motion, effects, timing, live preview, OK / MODIFY / DITCH with note. | `showreel.json` (`scenes`) |
| **Build and preview** | Build, issues from the checks, play the reel, stills. | `vN/` |
| **Deliver** | HTML, MP4, cuts, languages; release gate with resolve or waive and a note. | `exports/` |

The copilot is a panel on the right in every block. It sees the block in the foreground and the selection.

Library window unchanged: list of projects, new, open folder, duplicate as new version, archive.

### 5.1 Source of truth (revises decision 1)

Everything the user can edit in a block is stored as structured data in `showreel.json` (parameters, decisions, scenes with stable IDs, gate states). The app regenerates `brief.md`, `style-sheet.md` and `storyboard.md` from it after each change, so the skill, in a chat or when the copilot reads files, sees the same facts. Resources keep `MANIFEST.csv` (the skill's format).

- A project made in Cowork (markdown only) is imported once into `showreel.json`; the user confirms what was found.
- If the markdown files were changed outside the app (Cowork session), the app detects it (hash in `.studio/`) and offers to re-import; it never overwrites silently.
- Scene IDs are stable and never renumbered; the storyboard is archived to `archive/` before a new version.

### 5.1b Export from the skill

The skill can export a chat-made project to the app: `scripts/export_studio.py <project> [--facts facts.json]` writes `showreel.json` from `brief.md`, `style-sheet.md`, the storyboard table and the manifest, with `origin.tool = "skill"` (see `references/studio-export.md`). The app owns the file once it saves it (`origin.tool = "studio"`) and the script then refuses to overwrite it. Schema contract shared by both sides (phase A2 implements it in `ShowreelFile`; `check.py` must verify that the script's output decodes):

- `parameters`: `{audience, message, tone}` (free text, all optional).
- `scenes`: an ordered array of `{id, start, end, text, texts{column: text}, visual, feeling, handoff, inCuts, extra{}, status (open|ok|modify|ditched), note}`. This replaces the phase A dictionary of review states; the app reads the old form too.
- `gates` keys: `interview, assets, style, storyboard, review, build, verify, publish`, values `passed` or `open`.
- `origin`: `{tool, exportedAt, files}`. Unknown keys must survive a load and save by the app (keep them in a catch-all), so a newer skill never loses data.

### 5.2 Copilot changes are readable

Changes are typed operations shown as plain cards, not file diffs: "Set palette accent to #F2AA4C", "Rewrite text of S03: before / after", "Add scene S07 after S06", "Mark asset logo.svg approved". Each card has Accept and Refuse (and "apply directly" per project). Tools: `get_state`, `update_parameter`, `update_decision`, `update_scene`, `add_scene`, `update_asset`, `open_block`. `propose_edit(file, content)` remains for files the app does not model, shown as a diff only in Advanced.

## 6. Embedded engine

The effects (248), backgrounds and the player are JavaScript in `showreel-director/engine/`. They are not rewritten in Swift. A reusable `EnginePreview` view (a `WKWebView` loading a small bundled host page that includes `core.js`, `kit.js`, `backgrounds.js` and the effect code) offers:

- `renderEffect(name, palette, font, t)` and `renderBackground(id, params, palette, t)` for animated thumbnails in the pickers;
- `renderScene(sceneId, t)` for scene cards and the look test;
- the reel player for Build and Verify.

Thumbnails are cached under `.studio/`. Native screens own lists, filters, selection and state; the engine only draws. The HTML picker generators (`build_*_picker.py`) stay in the skill for chat-only use.

## 7. The copilot

- The system prompt is still `SKILL.md` plus the addendum, with a new addendum section: "The user drives. The screens collect the interview answers, so do not ask what a screen already holds. On request: draft the storyboard or a style line, explain a choice, write `main.js`, fix issues from the harness, translate. Read `showreel.json` first."
- New tools: `get_state` (decisions, gates, step), `update_decision(key, value)`, `open_screen(step)`, `propose_edit(file, change)` and the existing file tools. A write to a file the user is editing, or to a prose file, becomes a proposal shown as a diff in the copilot panel (accept or refuse) unless the user switched on "apply directly" for the project.
- The copilot gets a short context message with every turn: current step, open gates, the file in the foreground.
- A selection can be sent to the copilot ("make this scene shorter", "write the file for this palette").

## 8. Editing at the same time

- A file watcher refreshes open editors. Every save, by the user or by the copilot, snapshots the previous content in `.studio/history/<file>/` (last 50), with diff and restore.
- A proposal records the file version it was based on; if the file changed since, the copilot regenerates it.
- The skill's own rules stay: the storyboard is archived before being rewritten, scene IDs never change, the explicit Go before the build.

## 9. Multi-project

Library file with paths, last opened, pinned. One agent and one chat history per project (`.studio/chat/`); switching projects never mixes histories. No App Sandbox, so plain paths are enough.

## 10. Phases (revision 1)

| Phase | Content | Done when |
|---|---|---|
| A (built) | ShowreelKit library, project model, library window, file editors, history, copilot panel with diffs | done; file tree and editors move to Advanced in A2 |
| A2 | App shell with the sidebar of blocks and statuses; Project block (parameters form); Resources block (drag and drop, statuses, MANIFEST.csv); file tree and editors hidden behind Advanced; typed copilot operations (`get_state`, `update_parameter`, `update_asset`, `open_block`) with readable cards; markdown regenerated from `showreel.json`; `process.json` and its check | A project can be created, parameterised and fed with resources without seeing a file |
| B | Look and technique block: palette, fonts, look board, background and effects pickers (engine preview spike first) | A validated look without a chat message |
| C | Storyboard timeline and Scene editor with live preview, scene review and the explicit Go | Storyboard validated and Go given from the app |
| D | Build and preview, Deliver, release gate | A full reel built, checked and exported from the app |

Tests per phase: round trips of `showreel.json`, golden files for the generated markdown, import of markdown-only projects, typed operations against a scripted agent, `process.json` against `SKILL.md` in `check.py`, extended `--selftest`.

## 11. Decisions to validate

1. **Canonical store:** `showreel.json` for structured decisions plus markdown for prose (recommended), or markdown only with the app parsing it.
2. **Copilot edits:** proposals with accept or refuse by default (recommended), or direct writes.
3. **Windows:** one window per project (recommended), or one window with a project switcher.
4. **Skill in chat:** keep it fully usable alone in Cowork (recommended), which is why `process.json` and the capability contract exist.
5. **Order:** phases A to D as above, or start with the pickers (phase B and C items) before the library.

## 12. Risks

- Skill and app drift: reduced by `capabilities.json`, `process.json` and `check.py`, but the method text itself is still written for a chat.
- The engine bridge (`EnginePreview`) is the least known part; it gets a spike at the start of phase C.
- The Swift code is written without a compiler on the Cowork side; Claude Code builds and runs it, as for the current app.
- Distribution constraints are unchanged (see `ROADMAP.md`).
