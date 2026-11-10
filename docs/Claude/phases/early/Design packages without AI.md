---
type: phase-report
status: current
phase: PK1
date: 2026-11-10
summary: "Phase PK1: design packages without AI, in the .studiopack format, to save a design and start a project from it."
aliases:
  - "PK1"
phases: [PK1]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# PK1

phase PK1 is built (design packages, with no AI: the `.studiopack` format, a zip with `package.json` first, then `design.json`, `resources.json` and `assets/`, read and written by the app itself with no other tool and checked entirely before any entry is read (names, symbolic links, sizes, number of entries, expected file types, nested archives refused); the manifest, the canonical SHA-256 hash that leaves the dates out and ignores the order of keys, and the integrity result (matches, modified, damaged); the author as a display name, never an e-mail, never taken from the system account; the library in Application Support, one folder per id and version with the rights confirmation of that version; "Save design as package" in the project settings (what goes in, name, author, note, a new version of the same id with a mandatory note, export and Show in Finder, not an undoable change of the project); "Start from a package" at project creation in the Wizard and in Manual, the Wizard asking only what the package leaves open; the import card with the rights box, "Not signed" and the integrity decision, opened by double-click, drop or Open a .studiopack; the origin recorded in showreel.json under `package`, and the journal line with the version, the hash and the confirmation; the document type registered in Info.plist by make-app.sh and checked by `--selftest` and `tools/verify-bundle.sh`)

Rules in ShowreelKit: `PackageZip.swift`, `DesignPackage.swift`, `PackageLibrary.swift`, `PackageProject.swift` (`PackageSave`, `PackageStart`, `Availability.savePackage`), `Wizard.swift` (`WizardInterview.questions(for:)`), `Assets.swift` (`holdReason`), `ShowreelFile.swift` (`PackageOrigin`)
