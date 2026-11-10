---
type: phase-prompt
status: current
phase: RF1
date: 2026-11-10
summary: "Cleans the compiler warnings of the app (about 17 distinct sites, the two CLAUDE.md ones included) without changing behaviour."
tags:
  - prompt
---

# Phase RF1: clean the compiler warnings (refactoring 1 of RF0)

Read CLAUDE.md first and follow every rule (never run git; English interface; answer the owner in French and short; no screen, so say what was not seen). Use `graphify query` before reading files. Run only after W4c is built. **No behaviour change, no feature, no other refactoring** (dead code, splitting `ProjectModel.swift` and the glue of RF2 are other phases).

## Source

`docs/Claude/phases/RF0/report.md`, section 2 "6. Concurrency and warnings" (the table of 12 rows) and section 3, item 1. Re-run a clean debug build first (`swift build --package-path app-swift --scratch-path ~/Library/Developer/ShowreelStudio/build` after a clean of that scratch path) and list the warnings as they are now: W4c may have moved lines. The table is a guide, the build is the truth.

## Work

1. Fix every warning of the clean build with the smallest change the table gives (for example `nonisolated static let frameSize`; `ChatModel` screenshot helper on the main actor; `EnvModel` `@MainActor` with a hop; `@discardableResult` or `_ =` for `store.transaction`; delete dead lines `current`, the redundant `public`, the dead `?? 0`; `Sendable` for `ShowreelFile.Scene` if it is a plain value type; the `AudioFileGetProperty` pointer restricted to trivial types).
2. A fix that would change what the code does (timing, ordering of main-queue hops, who owns a capture) is not allowed here: list it in the report with its reason and leave the warning, or suppress nothing.
3. Do not silence warnings with flags or pragmas. Do not turn on Swift 6 strict mode.
4. Update CLAUDE.md "Open work" item 2 (warnings left) to the real remaining list, or remove it if none remain.

## Verification

A clean debug build with zero warnings (or the exact list left and why). `tools/verify.sh --fast` during; at the end the full `tools/verify.sh`, then release notes in RELEASE-NOTES-APP.md, `python3 tools/bump_app.py patch "Compiler warnings cleaned"`, then `tools/rebuild-app.sh`. Report in `docs/Claude/phases/RF1/report.md` with the warning count before and after, each site fixed, and what was not seen on screen. Then `python3 tools/docs_index.py --write` and `python3 tools/check_docs.py`. Stop after the phase.
