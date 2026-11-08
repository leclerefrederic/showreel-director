#!/bin/bash
# Rebuild the native app and relaunch it. One command, so an agent needs one permission.
# Usage: tools/rebuild-app.sh [--no-open]
set -e
cd "$(dirname "$0")/../app-swift"
pkill -x ShowreelStudio 2>/dev/null || true
./make-app.sh
# the skill inside the app must be the skill in the repository
WANT="$(python3 ../tools/skill_hash.py)"; HAVE="$(cat build/ShowreelStudio.app/Contents/Resources/skill.hash)"
if [ "$WANT" != "$HAVE" ]; then echo "SKILL MISMATCH: repo $WANT, app $HAVE"; exit 1; fi
echo "skill fingerprint $WANT"
if [ "$1" = "--no-open" ]; then echo "REBUILT (not opened)"; exit 0; fi
open build/ShowreelStudio.app
sleep 2
if pgrep -x ShowreelStudio >/dev/null; then echo "REBUILT AND RUNNING (pid $(pgrep -x ShowreelStudio))"
else echo "REBUILT BUT NOT RUNNING"; exit 1; fi
