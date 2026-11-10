---
type: phase-report
status: current
phase: R
date: 2026-11-10
summary: "Phase R: release notes for the skill and the app, one section per version, plus the app's short changelog."
aliases:
  - "R"
phases: [R]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# R

phase R is built (release notes: `RELEASE-NOTES-SKILL.md` and `RELEASE-NOTES-APP.md`, one section per version, and the app's own short register `CHANGELOG-APP.md`; the app's version has one source, `app-swift/shared/app-version.json`, written into the bundle by `make-app.sh` and shown with the skill's version in About Showreel Studio, `AppInfo`; `tools/bump_app.py` ships an app version and, like `tools/bump.py`, refuses without the section of the new version; `tools/check.py` fails when versions, registers, records and notes disagree)

Rules in ShowreelKit: `AppInfo.swift` (the rest is repository tooling: `tools/bump_app.py`, `tools/app_hash.py`, `tools/check.py`)
