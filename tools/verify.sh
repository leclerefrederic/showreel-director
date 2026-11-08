#!/bin/bash
# One command to verify the repo. Runs what can run on this machine and says what it skipped.
cd "$(dirname "$0")/.." || exit 1
status=0
step() { printf '\n== %s\n' "$1"; }

step "repo checks (python3 tools/check.py)"
python3 tools/check.py || status=1

if [ "$(uname)" = "Darwin" ] && [ -d app-swift ]; then
  step "swift build (app-swift)"
  ( cd app-swift && swift build ) || status=1
  if grep -rq -- "--selftest" app-swift/Sources 2>/dev/null; then
    step "swift app self-test"
    bin=$(cd app-swift && swift build --show-bin-path 2>/dev/null)/ShowreelStudio
    APP_STORE=/tmp/showreel-selftest "$bin" --selftest || status=1
  else
    echo "(no --selftest in the Swift app yet: skipped)"
  fi
else
  echo "(not macOS or no app-swift: Swift build skipped)"
fi

find . -name __pycache__ -not -path "./.git/*" -exec rm -rf {} + 2>/dev/null
find . -name .DS_Store -not -path "./.git/*" -delete 2>/dev/null
if [ $status -eq 0 ]; then printf '\nVERIFY OK\n'; else printf '\nVERIFY FAILED\n'; fi
exit $status
