---
name: swift-app
description: Rules for working on app-swift, the native macOS shell of Showreel Studio (SwiftPM, WKWebView, Swift agent loop). Use when editing or compiling anything under app-swift/.
---

# Swift app (`app-swift/`)

## Shape

`WKWebView` shows `app/src-ui`. `Studio.swift` injects `window.studio` and answers its calls. `Agent.swift` streams the Messages API over `URLSession`. `Tools.swift` runs the tools. `UIBridge.swift` sends events to the page and waits for question-card answers. Tool definitions and the prompt addendum come from `app/shared/`; the system prompt is `SKILL.md` without frontmatter plus that addendum.

## Compile and run

```
cd app-swift
swift build            # fix the first error first
./make-app.sh          # build/ShowreelStudio.app
open build/ShowreelStudio.app
```

Run from the source tree with `swift run`: resources are found by walking up from the current directory.

## Rules

- The package stays in Swift 5 language mode (tools version 5.9) until it builds clean; moving to Swift 6 is a separate step done type by type.
- Do not set main-actor default isolation. `Tools`, `Agent` and `OutputBuffer` run off the main thread on purpose.
- A closure handed to an API without a `Sendable` parameter (`readabilityHandler`, `terminationHandler`, `DispatchQueue.asyncAfter`) must not touch main-actor state. Reach the page only through `UIBridge.emit`, which hops to the main queue.
- Fix a concurrency error at its type. No `@unchecked Sendable` or `nonisolated(unsafe)` without a comment saying why.
- `WKScriptMessageHandlerWithReply`: call `replyHandler` exactly once on every path.
- Never name a type `Task`, `View`, `Color`, `Image`, `Text`, `Menu`, `Group`.
- The API key lives in the Keychain only. Never log it, never write it to a file, never put it in a command line.
- `bash` runs a login `zsh` that also sources `~/.zshrc`, so the PATH and the corporate trust settings match the user's terminal. Do not add environment overrides that weaken TLS.
- A new tool is added in `app/shared/tools.json` first, then in `tools.js` and `Tools.swift`; `tools/check.py` fails if one side lacks it.

## Done when

`swift build` has zero errors, `tools/verify.sh` ends with `VERIFY OK`, and the app was opened and the checks listed in `CLAUDE.md` "Open work" item 1 were walked through, or the ones that could not run are named.
