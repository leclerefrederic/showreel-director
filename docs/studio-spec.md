# Showreel Studio v2: a workspace with a copilot

Status: VALIDATED (revision 1 validated; revision 2 validated; revision 3, section 5.4; revision 4 validated on 2026-11-09: section 5.5 editing workspace with the film reel, phases W1 to W5, W1 next) by the owner on 2026-11-08 with the recommended choice for every point of section 11 (showreel.json plus markdown; copilot edits as proposals; one window per project; skill fully usable alone in Cowork; phases A to D in order). Build phase A first.

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

- `parameters`: `{audience, message, tone, constraints}` (free text, all optional; `constraints` was added by the app in A2).
- `scenes`: an ordered array of `{id, start, end, text, texts{column: text}, visual, feeling, handoff, inCuts, extra{}, status (open|ok|modify|ditched), note}`. This replaces the phase A dictionary of review states; the app reads the old form too.
- `decisions.palette` is ordered by role: background, text, accent, accent 2 (the app names them in the generated files). The skill export currently lists colours in the order found in the files, so a palette exported from a chat can be mislabelled: to fix by exporting roles explicitly.
- `gates` keys: `interview, assets, style, storyboard, review, build, verify, publish`, values `passed` or `open`.
- `origin`: `{tool, exportedAt, files}`. Unknown keys must survive a load and save by the app (keep them in a catch-all), so a newer skill never loses data.

### 5.2 Copilot changes are readable

Changes are typed operations shown as plain cards, not file diffs: "Set palette accent to #F2AA4C", "Rewrite text of S03: before / after", "Add scene S07 after S06", "Mark asset logo.svg approved". Each card has Accept and Refuse (and "apply directly" per project). Tools: `get_state`, `update_parameter`, `update_decision`, `update_scene`, `add_scene`, `update_asset`, `open_block`. `propose_edit(file, content)` remains for files the app does not model, shown as a diff only in Advanced.

### 5.3 Modes, and the role of the AI (revision 2)

Principle: a project can be made from start to finish by hand, without a key and without any AI call. The AI has two jobs that need it, and one optional helper job:

| Role | AI needed | Examples |
|---|---|---|
| **Generation** | yes | write `main.js` from the storyboard and decisions, translate lines, draft a storyboard or a style line on request |
| **Judgement** (verification) | optional, explicit button | consistency review, claims against sources, brand rules, "does this storyboard match the brief" |
| **Copilot** | optional | answer questions, suggest values, change things on request |

Everything deterministic runs natively with no AI: feasibility numbers, the readability budget per scene, `organize_assets.py --check`-style asset rules, the release gate list, gate status, the harness, the player smoke test, contact sheets. These are the "checks" the user sees as green or red in every block.

**Two modes per project** (a switch in the toolbar, stored in `.studio/ui.json`, new projects start in Beginner):

- **Beginner (wizard).** A guided path through the same blocks in the order of the process: one question or choice per screen, the interview's question as the title, short help, a "Next" button, "Decide later" on every step, a progress bar and a summary at the end of each block. Choices are offered as options with a recommended one, never recorded unless the user picks (the skill's rule: nothing pre-accepted). Each step has an optional "Suggest with AI" button; without a key the button explains how to connect one and the wizard continues by hand. The wizard writes the same data as the blocks: no separate model.
- **Expert.** The sidebar of blocks with free navigation, all fields at once, the copilot panel open, Advanced files available.

Switching mode never loses data; the wizard resumes at the first undecided step.

**No forced AI between steps.** No block waits for an AI answer to continue. The app starts and works without a key (Settings is not shown at launch; the copilot panel offers "Connect AI"). The only step that needs generation is Build: until a key is present, the Build block explains that and keeps everything else usable (a project can be built later, or on another machine).

`process.json` gets an `ai` field per block: `none`, `optional` or `required`; `check.py` verifies that every block has it and that only Build (generation) is `required`.

### 5.4 Hierarchy: libraries and montage (revision 3)

Problem found while testing phase T: Storyboard and Scene editor showed the same list. The elements need a hierarchy. Two libraries hold things, one block assembles them:

| Block | Role | Verbs |
|---|---|---|
| **Resources** (library) | every file the film can use | add, replace, approve, exclude, archive |
| **Scenes** (library) | every scene of the project, with its content: text, visual, feeling, handoff, own duration, linked resources, review state | create, edit (editor with preview), review (OK / MODIFY / DITCH), duplicate, archive |
| **Storyboard** (montage, the editing window) | the order of the scenes in a film, on a timeline | reorder, switch a scene on or off, see timing against the music, run the film-level checks (feasibility, total duration, reading budget in context), validate, give the Go |
| **Build and preview** | produce and play the film | build, checks, play |

Rules:

- The Storyboard never creates or deletes a scene. A scene switched off stays in the library and in the file. Deleting is done in the Scenes library and is an **archive**: the scene disappears from the lists but its ID stays reserved (tombstone), as the skill requires (an ID is never reused or renumbered; a ditched scene stays marked).
- The review state belongs to the scene (open, ok, modify, ditched); the Go belongs to the Storyboard (it validates the montage). DITCH archives the scene and switches it off in every montage.
- Timing belongs to the montage: a scene has its own `duration`; start and end are computed from the order, with an optional manual or beat-snapped override per montage.
- A project can hold several montages (a "cut": master, short, vertical) built from the same scene library: this replaces the skill's "in cuts" column. The first version of the screen shows one montage; the data allows several.

Contract change (supersedes the `scenes` shape of 5.1b): `scenes` stays an array and becomes the library `{id, text, texts, visual, feeling, handoff, duration, resources[], status, note, archived, extra}`; a new `storyboards` array holds `{id, name, format, items: [{scene, enabled, start?, end?}]}`. The app reads the phase T shape (start and end inside each scene) and converts it into one montage on first save; the skill export writes the new shape (scene table rows become the library and the one montage, a ditched row becomes archived and disabled; `inCuts` becomes extra montages when present). Sidebar order: Project, Look, Resources, Scenes, Storyboard, Build, Deliver. `process.json` gains the Scenes block; the gates keep the order of `SKILL.md` (the Scenes block carries the scene-review gate, the Storyboard block the storyboard gate and the Go).

### 5.5 Editing workspace (revision 4, supersedes the sidebar layout)

Showreel Studio is an editing application: a film is cut into scenes with durations, and a scene is an assembly of resources. The window is a workspace like a video editor, not a list of blocks:

```
+--------------------------------------------------------------------------------+
| project | Beginner/Expert | Checks | [Play] | Go / Build                          |
+---------------+------------------------------------------+---------------------+
| LIBRARY       |   VIEWER                                 |  INSPECTOR          |
| tabs:         |   the selected scene, or the film at     |  what is selected:  |
| Resources     |   the playhead, rendered by the engine   |  project, look,     |
| Scenes        |   with transport controls                |  scene, layer,      |
| Look elements |                                          |  resource, check    |
| (fonts,       |                                          |  + Copilot tab      |
|  palettes,    |                                          |                     |
|  backgrounds, |                                          |                     |
|  effects)     |                                          |                     |
+---------------+------------------------------------------+---------------------+
| STORYBOARD (timeline): scene clips in order with their durations, on/off,       |
| the music track with beat markers, the playhead, the film-level checks         |
+--------------------------------------------------------------------------------+
```

- **Library (left):** Resources (files, drag and drop in), Scenes (every scene, create, duplicate, archive; section 5.4), Look elements (fonts, palettes, backgrounds, effects, scene transitions, looks). Items are dragged from here onto a scene or the timeline.
- **Viewer (centre):** renders the selected scene or the film at the playhead with the embedded engine; play, pause, scrub.
- **Inspector (right):** properties of the selection: nothing selected shows the project parameters and global look (palette, fonts, formats, languages, constraints); a scene shows duration, review state (OK / MODIFY / DITCH), notes, feeling and handoff, and its layers; a layer shows its parameters and timing inside the scene. The copilot is a tab here, always available, never required.
- **Storyboard (bottom), the film reel:** a strip of frames, one frame per scene, in order. Each frame shows a thumbnail rendered by the engine, the scene ID and its duration; its parameters are linked to it (duration, on or off, review state, the transition to the next scene). Between two frames sits the transition marker: type (from the catalogue's scene transitions: cut on beat, flash cut, push, whip pan, iris, morph, and so on; default cut on beat), duration and parameters, editable in the inspector, and a transition can be dragged from the library onto the marker. Drag a frame to reorder, drag its edge to change the duration, toggle it on or off, add scenes from the library. The music track attached to the project sits under the strip: its waveform and its analysis (beats, bars, bar energy, drops, breakdowns, from the skill's `analyze_audio.py` output `analysis/beats.json`; the waveform is drawn natively from the audio file) are aligned with the scenes. **Snap to grid:** stretching a scene by its left or right edge snaps to the grid, at a level the user picks (beat, bar, section, drop or off, a modifier key bypasses it); moving or resizing a scene shifts the following scenes (ripple) unless the user turns that off, and the cut stays on the grid. The strongest drop and the breakdowns are marked, and the native checks apply the storyboard rules that depend on music: scene starts on bars or beats, the strongest moment on the strongest drop, a calmer bar before it. If the detected tempo is wrong, the user corrects the BPM or the first beat in the inspector and the grid is recomputed (the skill's `--bpm` and `--first-beat`), and the analysis is flagged as constant-tempo. Without a track, the grid is a plain time ruler. Film-level checks (feasibility, total duration, reading budget, flashes per second across transitions) show on the strip. The Go and the storyboard validation are given here. The storyboard never creates or deletes a scene.
- **Scene tree (Scenes tab):** each scene in the library expands into the tree of what composes it, so the composition is readable at a glance: **Raw** (images, video, sound, any resource used), **Texts**, **Effects**, **Background** (inherited from the project unless overridden), **Look** (palette and fonts, inherited from the project unless overridden). Inherited groups show the project value with an "inherited" mark; overriding it in the scene shows an "overridden" mark and a "Revert to project" action. Each node shows a status (approved, to approve, missing, over budget) and selecting a node drives the viewer and the inspector. The tree is also the drop target for library items (phase W5). The scene inspector (right) is organised in tabs, one per group of the tree, instead of one long form: **Settings** (in the film, duration, review OK / MODIFY / DITCH with note, feeling, passage to the next scene, duplicate, archive), **Content** (the texts), **Effects**, **Resources** (linked resources with their status), **Look** (background and look, inherited or overridden). Selecting a node of the tree opens the matching tab. The tabs of the inspector as a whole stay: Inspector, Copilot, Files (Advanced). Leftovers go: the duplicate "Review" heading, the redundant status label, and fields with no use yet ("In cuts" becomes a montage property, shown only where it matters). The collapsed row keeps the checkbox (on or off in the montage), the review state, the ID, the text and the duration.
- **Scene content = a map of what the scene contains, and the instructions for the AI (revision 5):** the Content tab of a scene is an ordered list of content items. Item types: text, image or logo (a resource), sound or voice (a resource), and later shapes. Each item has:
  - its subject: the words, or the linked resource;
  - a **colour** (text and shapes): `auto` (the AI decides within the style sheet), a **palette role** (background, text, accent, accent 2) or a custom hex;
  - an **animation**: `auto` (the AI decides) or a named effect from the library (fly in, and so on) with its parameters;
  - an optional free **instruction** for the AI, in the user's words.
  Every attribute is either *fixed* (the user chose it) or *auto* (left to the AI). The user decides how much control they want: a **control level** at project or scene level sets the default for new items (Auto: only the words; Guided: the user fixes what matters; Precise: everything is fixed) and any attribute can be overridden item by item. The generation honours fixed values strictly and decides the rest from the style sheet, the effect packs and the brief; the native checks verify fixed values (a palette role exists, an effect exists, a resource is approved).
  **The order of the items is their processing priority:** the AI treats items from the first to the last, and the earlier items win conflicts of time, space and emphasis; if the feasibility or reading checks fail, the later items are simplified or dropped first, and the app says so. (Priority is not the stacking order on screen; the stacking order is decided by the AI unless an instruction fixes it.)
  The tree groups follow from the content: Texts and Raw list the items by type, Effects lists the effects they use plus the scene-wide ones; the scene-wide effects (background effects, whole-scene moves) live in the Effects tab, while an item's own animation lives on the item.
- **Beginner mode:** the wizard stays as the guided way to fill the project, the look, the resources and the first scenes (it asks the interview's questions and writes the same data); it ends in the workspace. Expert mode opens the workspace directly. The sidebar of blocks goes away; the process bar shows the gates (Checks menu).
- **AI:** unchanged (5.3). Generation writes the build files from the content items and decisions; judgement and copilot stay optional. A later option, outside this phase: build without the AI when every attribute of the content is fixed.

Data: `scenes[*].content` is an ordered array of `{id, type (text|image|audio|shape), text | resource, color: {mode: auto|role|custom, role?, hex?}, animation: {mode: auto|effect, effect?, params?}, instruction?, in?, out?}` (in and out, the timing inside the scene, come with W4); `scenes[*].controlLevel` is `auto|guided|precise` (default from `parameters`); unknown keys survive, as for everything else. The skill export puts each scene's text in one text item (all attributes `auto`) and the rest in notes, so a chat-made project opens with its words on the timeline.

## 6. Embedded engine

The effects (248), backgrounds and the player are JavaScript in `showreel-director/engine/`. They are not rewritten in Swift. A reusable `EnginePreview` view (a `WKWebView` loading a small bundled host page that includes `core.js`, `kit.js`, `backgrounds.js` and the effect code) offers:

- `renderEffect(name, palette, font, t)` and `renderBackground(id, params, palette, t)` for animated thumbnails in the pickers;
- `renderScene(sceneId, t)` for scene cards and the look test;
- the reel player for Build and Verify.

Thumbnails are cached under `.studio/`. Native screens own lists, filters, selection and state; the engine only draws. The HTML picker generators (`build_*_picker.py`) stay in the skill for chat-only use.

### 6.1 Build architecture: scene modules (proposal, to validate before W3)

The reel is one canvas drawn by a pure function of time (`render(g, t, ctx)` in `main.js`), with the audio as master clock; scenes are time windows (`SR.setScenes`, `sceneAt`, `ctx.lt` local time). So the assembly unit is a scene **render module**, not an HTML snippet: separate HTML pages per scene would break the single canvas, the shared audio clock, the shared fonts and images, the test harness and the MP4 export.

Proposal: the AI generates one module per scene (a function `render(g, lt, ctx)` in its own scope, from the scene's content items in priority order, the style sheet, the brief and a short summary of the previous and next scenes); a reel-level layer, written once, assembles them into `main.js` and owns everything that crosses scenes: the background sequence, persistent characters, music reaction, and transitions. Transitions are the reason for the reel-level layer: a push, a whip pan, an iris or a morph needs the outgoing and the incoming scene drawn at the same moment, so the layer renders both modules (each at its own local time) and mixes them; this needs a small engine addition (a transition compositor driven by the montage's `transition` field), to be spiked first.

Benefits: only changed scenes are regenerated (cache keyed by the scene's content, look and neighbouring transitions), a scene can be previewed alone in the viewer, a harness issue is attributed to a scene, MODIFY on one scene regenerates that scene, scenes can be generated in parallel when they do not depend on each other, prompts stay small. Risks and mitigations: style drift between scenes (every module gets the same context and tokens, a final whole-film review and the harness run on the assembled reel), continuity (persistent identities and background continuity are reel-level, not per scene), name collisions (one function scope per module), cost of regenerating all scenes after a global change (a change of palette, fonts or background invalidates every module, as it should).

**Transitions are not scenes, they are a relation between two scenes.** A transition belongs to the pair (outgoing scene, incoming scene) in a montage (`transition` on the montage item, 5.5), never to a scene: the same scene can have another successor in another montage. It carries a type, a duration, parameters, and an optional instruction for the AI like a content item does (for a match cut: which element of the outgoing scene becomes which element of the incoming one); the generation gives both scene modules that instruction so they cooperate. Open points for the spike: whether a transition overlaps the end of the outgoing scene and the start of the incoming one (scene durations stay as set and the film length does not change; proposed) or adds time; the native checks that follow from it (a transition is not longer than either scene, no essential text is on screen mid-transition, flashes per second across transitions stay under 3).

Spike W3a (built, 2026-11-10): `engine/film.js` (scene modules assembled by a film layer, `SRF.film`) and `engine/transitions.js` (the 42 scene transitions of the effects lab as a compositor, generated by `scripts/export_transitions.py`) work in the player, the harness, the player test and the MP4 export; the old single `main.js` stays the default. Findings: see the W3a report in the session notes and `references/engine.md` (36 of 42 transitions run between two real scenes, 19 show both together; the six others are lab demonstrations). Recommendation: adopt the compositor and the film assembly as the runtime contract, keep generation as one `main.js` that declares its scene modules, and decide per-scene generation (one AI call per scene) only after a style-drift experiment on real scenes.

Decision to take at the start of W3 or of the Build rework, after the transition-compositor spike. Until then Build keeps generating one `main.js`.

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
| A3 | Mode switch (Beginner wizard, Expert), wizard framework with Project and Resources steps (later blocks plug in as they are built), "Decide later", progress; the app runs without a key (no Settings at launch, copilot shows "Connect AI"); native deterministic checks per block (feasibility, readability budget, asset rules, gate status) with green/red display; `ai` field in `process.json` and its check | A project can be parameterised and fed with resources through the wizard with no key configured |
| B | Look and technique block: palette, fonts, look board, background and effects pickers (engine preview spike first) | A validated look without a chat message |
| T (thin slice, before C and D) | Library window opens at launch by default. Storyboard block: list of scenes (add, edit, reorder, ditch; stable IDs; start/end, text, visual, feeling, handoff, linked resources) with native readability and feasibility checks; storyboard.md generated. Scene editor (minimal): one scene form plus OK / MODIFY / DITCH with note, the explicit Go. Build and preview (minimal): the AI generates the version folder from storyboard and decisions through the existing agent loop, the app runs build.py, harness and smoke test, shows red/green issues, and plays the reel in the app. "Rédiger avec l'IA" optional on the storyboard | A user can create a project, drop a logo, write scenes by hand, press Go and watch the generated reel play in the app |
| W1 (built, workspace shell) | The four-zone workspace replaces the sidebar of blocks: Library tabs (Resources, Scenes, Look elements) on the left, Viewer in the centre, Inspector with Copilot tab on the right, Storyboard timeline at the bottom; selection drives the inspector; project parameters and global look live in the inspector when nothing is selected; existing editors (palette, fonts, pickers) are moved into the library and inspector; Beginner wizard kept and ending in the workspace; data migration of 5.4 (scene library plus `storyboards`, archive with tombstone) | The same data as before is edited in the new layout, and nothing is lost |
| W1b (scene tree) | The scene tree in the Scenes tab with the five groups; Raw from the resources linked to the scene, Texts from the scene's text, Background and Look inherited from the project with the inherited/overridden marks and "Revert to project" (scene-level background and look overrides added to the data), Effects empty until W4 unless the scene already carries some; node statuses; selecting a node drives the viewer and the inspector | The composition of a scene is readable in one tree, with what is inherited clearly shown |
| W1c (scene content) | Content tab: ordered content items (text, image, sound) with colour (auto, palette role, custom), animation (auto or a library effect) and optional instruction; fixed or auto per attribute; control level (project default and per scene); reorder = priority; the tree groups follow the items; native checks of fixed values; the generation message for Build lists the items in priority order with fixed and auto marked; typed operations for add, update, remove and reorder items (cards, apply directly); skill export writes one text item per scene (skill bump) | A scene's content is mapped by hand, with the AI left to decide only what the user left open |
| W2 (film reel and music) | Frames with thumbnails in order with durations, transition markers between frames (type, duration, drag from the library), drag to reorder, drag edges to change the duration, on/off, add from the library, playhead; the project's music under the strip with its waveform and analysis (run `analyze_audio.py` from the app when a track is attached, read `analysis/beats.json`), snap to grid with a level picker (beat, bar, section, drop, off) and ripple, BPM and first-beat correction, music-dependent checks on the timeline, validation and Go | A film can be cut and timed on the timeline against the music, with scenes snapping to the grid |
| W3a (spike: scene modules and transition compositor) | Prototype in `showreel-director/engine/`: a scene is a module `render(g, lt, ctx)`; a reel-level layer assembles modules, keeps the background sequence and persistent elements, and a compositor mixes the outgoing and the incoming scene during a transition using the engine's transition effects; works in the player, `harness.js`, `smoke_player.js` and `export_mp4.js`; a two-scene test reel with a transition proves it; written report on feasibility, effort, risks and a recommendation on section 6.1. No change to Build yet | The owner decides on section 6.1 from the report |
| W3b (viewer and film integration) | Decision of 6.1 (2026-11-10, validated): adopt the compositor only (`SRF.film` and `SRT` as the runtime contract), keep one `main.js` that declares its scene modules; scene-by-scene generation is decided later after a style-drift experiment. Build: the build message asks for scene modules and one `SRF.film` call, with the montage (starts, durations, transitions) and the music grid supplied by the app; the harness can filter by scene. Viewer: follows the playhead and plays the built reel (transport: play, pause, scrub), and before a build shows a transition between two scene thumbnails; the six transitions that do not work between real scenes (Morph, Match cut, Ink/paper inversion, Curtain, Mirror split, Star reveal) are marked preview only and cannot be chosen for a montage | The user sees the scene and the film while editing, and a built reel uses the transitions of the montage |
| W4 (timing and viewer content) | Timing of each content item inside the scene (in and out), scene-wide effects in the Effects tab, thumbnails and viewer drawn from the content items (colour, animation), `storyboard.md` visual column generated from the content; skill export updated if needed (skill bump) | A scene is assembled and timed by hand and the viewer shows it |
| W5 (drag and drop) | Drag resources, backgrounds and effects from the library onto a scene, a content item or a tree node; Build reads the content items | A reel is assembled by hand and built |
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
