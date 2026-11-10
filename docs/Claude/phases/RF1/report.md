---
type: phase-report
status: current
phase: RF1
date: 2026-11-10
summary: "Report of RF1: compiler warnings of the app cleaned from 21 distinct sites to 4 that need an ownership or isolation change; no behaviour change; app 0.21.2."
app_version: 0.21.2
skill_version: 0.18.2
prompt:
  - "[[phases/RF1/prompt]]"
tags:
  - report
---

# RF1: clean the compiler warnings

## Before and after

A clean debug build (a new scratch path, after W4c) gave **33 warning lines, 21 distinct sites**. The build after the work gives **4**. No flag, pragma or Swift 6 mode was used.

## Fixed (17 sites)

| Site | Fix |
|---|---|
| `FilmState.swift:123` redundant `public` | removed |
| `FontFiles.swift:131` dead `?? 0` | removed |
| `ResourceDetails.swift:153` pointer to a generic `T` | the property read goes through `withUnsafeMutablePointer(to:)` (same call) |
| `SceneStatus.swift:37` non-Sendable `Scene` | `Sendable` added to `ShowreelFile.Scene` and to the plain value types it holds: `Decisions`, `Background`, `Track`, `ContentItem`, `ContentColor`, `ContentAnimation` |
| `EngineService.swift:81,89,98,131` `frameSize` | `nonisolated static let` (a `CGSize` constant) |
| `ChatModel.swift:460,464` `isLoading`, `evaluateJavaScript` (the CLAUDE.md warning) | `onMain` takes a `@MainActor @Sendable` closure and runs it with `MainActor.assumeIsolated` inside the same `DispatchQueue.main.async` hop as before |
| `EnvModel.swift:71,80,83` (the other CLAUDE.md warning) | `EnvModel` is `@MainActor`; the three existing `DispatchQueue.main.async` hops stay, with `MainActor.assumeIsolated` inside, so the order of the hops is unchanged |
| `ProjectModel.swift:1233` unused result | `_ =` |
| `ReactionViews.swift:280` unused `current` | line deleted |
| `SceneAutosave.swift:10` | `SceneFields` is `Sendable` and the validator is passed as `{ SceneFields.invalid($0, $1) }` |

## Left (4), and why

- `ChatModel.swift:137` and `:158`: `project` (a `ProjectModel`) is captured by a detached task that hops to the main queue to call `reloadHistory()`. The real fix is to isolate `ProjectModel` to the main actor (about 150 methods, 89 published properties) or to capture `self`, which changes who keeps the model alive. Both change isolation or ownership; not allowed here. It belongs with the split of `ProjectModel.swift` (RF0 item 3).
- `ChatModel.swift:350` (`finish`) and `ProjectModel.swift:1537` (`answerFonts`): an inner `[weak self]` sits inside a closure that already holds `self` strongly. Making the outer capture weak would skip the work if the model is gone (a behaviour change); making the inner one strong in `answerFonts` would create a cycle through the stored retry closure.

## What was not seen

No screen. Nothing drawn or animated changed, but `EnvModel` (the setup screen's checks and install log) and the screenshot helper of `ChatModel` now carry main-actor annotations: open the setup screen with a missing item (or press Check again) and watch the log stream; and ask Clap for a screenshot of a page. The hop order is the same as before by construction, not by observation.

## Version

App **0.21.2** (patch). Skill **0.18.2**, unchanged.

## Verification

`tools/verify.sh --fast` during; at the end `python3 tools/check.py`, the complete `tools/verify.sh` and `tools/rebuild-app.sh` (results in the closing message).
