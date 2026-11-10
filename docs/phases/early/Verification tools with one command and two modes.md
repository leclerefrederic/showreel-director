---
type: phase-report
status: current
phase: X
date: 2026-11-10
summary: "Phase X: the verification tools, one command with two modes, fast during a phase and complete at the end."
aliases:
  - "X"
phases: [X]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# X

phase X is built (the verification tools: `tools/verify.sh` is one command with two modes. `--fast` runs, inside a phase, the app and shared checks, the debug build and the tests without the four slow classes (BuildTests, FilmTests, InteractionTests, ChecksTests), skips the app self-test, and runs the skill's own checks and the slow classes only when their content changed since the last complete pass, a fingerprint kept outside the repository by `tools/verify_state.py`; it ends with "VERIFY FAST OK (pas un contrôle de fin de phase)". The complete mode, for the end of a phase, runs every repo check in parallel with the build, every test with `--parallel` and the app self-test, and saves the fingerprints after a pass. The stale-binary guard is decided by content, not by date: `tools/build_fresh.sh` compares the fingerprint of the Swift sources with the stamp of the last good build, so touching a file without changing it does not fail and a real change that was not built does; `make-app.sh` and `tools/rebuild-app.sh` use it, the app is closed only after the build was found valid, and `tools/test_build_guard.sh` tests these guards)

Rules in ShowreelKit: none (repository tooling: `tools/verify.sh`, `tools/verify_state.py`, `tools/build_fresh.sh`, `tools/test_build_guard.sh`)
