#!/bin/bash
# One command to verify the repo. Runs what can run on this machine and says what it ran and what it skipped.
#   tools/verify.sh           the complete verification, for the end of a phase: every repo check (in parallel with the build and the tests),
#                             the debug build, every test, the app self-test. Follow it with tools/rebuild-app.sh.
#   tools/verify.sh --fast    for the work inside a phase: the app and shared checks, the debug build, the tests without the four slow classes,
#                             no self-test. The skill's own checks and the slow classes run when their content changed since the last
#                             complete pass (a content fingerprint kept outside the repository: tools/verify_state.py).
cd "$(dirname "$0")/.." || exit 1
mode=full
case "$1" in --fast) mode=fast ;; ""|--full) ;; *) echo "usage: tools/verify.sh [--fast|--full]"; exit 2 ;; esac
status=0
SCRATCH="$HOME/Library/Developer/ShowreelStudio/build"
step() { printf '\n== %s\n' "$1"; }
skip() { printf '   skipped: %s\n' "$1"; }
swift_ok=0; [ "$(uname)" = "Darwin" ] && [ -d app-swift ] && swift_ok=1
SLOW=(--skip BuildTests --skip FilmTests --skip InteractionTests --skip ChecksTests)

step "build guards (tools/test_build_guard.sh)"
bash tools/test_build_guard.sh || status=1

if [ "$mode" = fast ]; then
  state="$(python3 tools/verify_state.py check)"
  skill_changed=1; slow_changed=1
  echo "$state" | grep -q 'skill=same' && skill_changed=0
  echo "$state" | grep -q 'slow=same' && slow_changed=0
  if [ $skill_changed = 1 ]; then
    step "repo checks, all of them (the skill changed since the last complete pass): python3 tools/check.py"
    python3 tools/check.py || status=1
  else
    step "repo checks, app and shared files only: python3 tools/check.py --app"
    python3 tools/check.py --app || status=1
    skip "the skill's own checks (the skill is the one of the last complete pass)"
  fi
  if [ $swift_ok = 1 ]; then
    step "swift build (debug)"
    swift build --package-path app-swift --scratch-path "$SCRATCH" || status=1
    if [ $slow_changed = 1 ]; then
      step "swift test --parallel, every class (the skill, Build, Film, Checks or Drops changed since the last complete pass)"
      swift test --parallel --package-path app-swift --scratch-path "$SCRATCH" || status=1
    else
      step "swift test --parallel, without BuildTests, FilmTests, InteractionTests and ChecksTests"
      swift test --parallel --package-path app-swift --scratch-path "$SCRATCH" "${SLOW[@]}" || status=1
      skip "those four classes (nothing behind them changed since the last complete pass)"
    fi
    skip "the app self-test (the complete verification runs it)"
  else
    skip "the Swift build and tests (not macOS, or no app-swift)"
  fi
else
  step "repo checks (python3 tools/check.py), started now and running while the app builds and tests; its result is below"
  chk="$(mktemp)"
  python3 tools/check.py > "$chk" 2>&1 &
  cpid=$!
  if [ $swift_ok = 1 ]; then
    step "swift build (debug)"
    swift build --package-path app-swift --scratch-path "$SCRATCH" || status=1
    step "swift test --parallel (every class)"
    swift test --parallel --package-path app-swift --scratch-path "$SCRATCH" || status=1
    if grep -rq -- "--selftest" app-swift/Sources 2>/dev/null; then
      step "swift app self-test"
      bin=$(swift build --package-path app-swift --scratch-path "$SCRATCH" --show-bin-path 2>/dev/null)/ShowreelStudio
      APP_STORE=/tmp/showreel-selftest "$bin" --selftest || status=1
    else
      echo "(no --selftest in the Swift app yet: skipped)"
    fi
  else
    echo "(not macOS or no app-swift: Swift build skipped)"
  fi
  wait $cpid || status=1
  step "repo checks: result"
  cat "$chk"; rm -f "$chk"
fi

find . -name __pycache__ -not -path "./.git/*" -exec rm -rf {} + 2>/dev/null
find . -name .DS_Store -not -path "./.git/*" -delete 2>/dev/null
if [ "$mode" = fast ]; then
  if [ $status -eq 0 ]; then printf '\nVERIFY FAST OK (pas un contrôle de fin de phase)\n'; else printf '\nVERIFY FAST FAILED\n'; fi
else
  if [ $status -eq 0 ]; then python3 tools/verify_state.py save; printf '\nVERIFY OK\n'; else printf '\nVERIFY FAILED\n'; fi
fi
exit $status
