---
name: verify
description: Verify a change in the showreel-director repo before calling it done. Use after any edit to the skill, the engine, the scripts, the Electron app or the Swift app, and whenever asked to check, test or package.
allowed-tools: Bash(tools/verify.sh*) Bash(python3 tools/*) Bash(swift build*) Read
---

# Verify

A change is done when all of these hold:

1. `tools/verify.sh` ends with `VERIFY OK`.
2. If `showreel-director/` changed: `python3 tools/package.py` was run and `check.py` reports the `.skill` identical to the folder.
3. If a script, page or engine file changed: the matching check or sample ran (the build self-test, the picker pages through jsdom, the harness on the demo reel). `check.py` runs them.
4. If `app-swift/` changed: every tool in `app-swift/shared/tools.json` is implemented in `Sources/ShowreelStudio/Tools.swift` (`check.py` fails otherwise).
5. Nothing is claimed that was not run. Say what ran, what failed, and what could not run here (for example Electron windows, the Swift app on Linux).

Fix the first failure first. Do not weaken a check to make it pass.

Report in French in two or three lines: what changed, what was verified, what was not. Remind the owner to commit and push with GitHub Desktop and, if the skill changed, to click "Save skill" on the packaged `.skill`.
