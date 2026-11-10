---
type: phase-report
status: current
phase: F2
date: 2026-11-10
summary: "Phase F2: fonts downloaded from Google Fonts without the GitHub API, using the file lists of engine/fonts-free.json."
aliases:
  - "F2"
phases: [F2]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# F2

phase F2 is built (fonts downloaded from Google Fonts without the GitHub API: `engine/fonts-free.json` lists for each font the files to take (name, weight, size, `list` name in Google Fonts' download list), the licence file, the licence and the repository folder, made by the maintainer script `tools/refresh_font_manifest.py` (no key); the cards "Add font files" and the one before a Build are built from it with no network; the download goes to the open repository by path (raw.githubusercontent.com), falls back to Google Fonts' download list (fonts.google.com, fonts.gstatic.com), checks every file (present, not empty, a font, the size of the list from the repository) and writes nothing unless all arrived, undoing a half write; a family with a single weight serves the weights the Look asks for; the 403, 404, 429 and network errors have their messages and Try again; skill 0.17.0)

Rules in ShowreelKit: `FontFiles.swift` (`FontFiles.offer/fetch`, `GoogleFontsSource`, `FontsAtBuild`), `Look.swift` (`Look.Font.files`)
