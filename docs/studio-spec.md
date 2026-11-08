# Showreel Studio v2: a workspace with a copilot

Status: VALIDATED by the owner on 2026-11-08 with the recommended choice for every point of section 11 (showreel.json plus markdown; copilot edits as proposals; one window per project; skill fully usable alone in Cowork; phases A to D in order). Build phase A first.

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

## 5. Screens

One window per project (`WindowGroup(for: ProjectID)`), plus the project library window.

```
+-----------------------------------------------------------------------------+
| Library | name of the project                          [Run checks] [Deliver] |
+-----------+-----------------------------------------------+-----------------+
| STEPS     |                                               |  COPILOT        |
| o Start   |   screen of the selected step, or a file      |  chat           |
| o Brief   |   editor in a tab                             |  proposals      |
| o Assets  |                                               |  (accept /      |
| > Look    |   (palette, fonts, backgrounds, effects,      |   refuse)       |
| o Story   |    storyboard cards, preview, player)         |                 |
| FILES     |                                               |  [ message... ] |
| tree...   |                                               |                 |
+-----------+-----------------------------------------------+-----------------+
```

- **Library:** list of projects with last opened date and step; New project (name, folder, languages), Open folder, Duplicate as new version, Archive. Stored in `~/Library/Application Support/ShowreelStudio/projects.json`.
- **Brief:** a form per brief section (mission, message, emotion, story, look, sound, delivery); each field has the interview's question as its help text; an inline feasibility result from `scripts/feasibility.py`.
- **Assets:** table of `MANIFEST.csv` (status, licence note, scene), approve, exclude, hold with a required note, drop files in; replaces the organiser's decision sheet.
- **Look:** look board (three design packages), palette editor (colour wells, contrast check), font picker (native, `fonts-free.json`, bundled previews registered with CoreText so samples are real `Text`), background picker and effects picker (use the embedded engine, section 6). Every choice writes to `showreel.json`.
- **Storyboard:** the table from `storyboard.md` as editable scene cards (text, timing, feeling, effects); reordering changes time order, never an ID; "Next version" archives the file to `archive/`.
- **Scene review:** OK / MODIFY / DITCH on each card, notes, the global pass, an explicit Go button (the skill's rule: its own explicit step).
- **Build and Verify:** buttons that run `build.py`, `harness.js`, `smoke_player.js`, show issues and contact sheets, play the reel in the embedded player, take stills.
- **Deliver:** HTML, MP4, cuts, languages; the release gate list with Resolve or Waive and a required note.
- **Files:** a tree of the whole project folder; text files open in an editor tab (markdown with preview, JSON, CSV as a table); binary files open with the system viewer.

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

## 10. Phases

| Phase | Content | Done when |
|---|---|---|
| A | Library and project model (`showreel.json`, importer), file tree and editors (markdown, JSON, CSV), chat moved to the copilot panel with history per project, `get_state`/`propose_edit`, library split (`ShowreelKit` target) and `swift test` in CI | A project can be created, closed, reopened; files edit by hand and by the copilot with diffs; `swift test` green |
| B | Step navigator with gates and `process.json` check, Brief form, Assets table, native palette editor, font picker, look board | A project goes from start to a validated style sheet without a chat message |
| C | `EnginePreview`, native effects and background pickers, storyboard cards and scene review | Storyboard validated and the Go given from the app |
| D | Build, Verify and Deliver screens, release gate | A full reel is built, checked and exported from the app |

Tests per phase: golden files for the markdown table parser and writer, `showreel.json` load, save and import round trips, `process.json` against `SKILL.md` in `check.py`, extended `--selftest`. Each phase is committed and usable on its own.

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
