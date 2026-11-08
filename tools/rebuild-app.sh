#!/bin/bash
# Rebuild the native app and relaunch it. One command, so an agent needs one permission.
# Usage: tools/rebuild-app.sh [--no-open]
set -e
cd "$(dirname "$0")/../app-swift"
pkill -x ShowreelStudio 2>/dev/null || true
./make-app.sh
if [ "$1" = "--no-open" ]; then echo "REBUILT (not opened)"; exit 0; fi
open build/ShowreelStudio.app
sleep 2
if pgrep -x ShowreelStudio >/dev/null; then echo "REBUILT AND RUNNING (pid $(pgrep -x ShowreelStudio))"
else echo "REBUILT BUT NOT RUNNING"; exit 1; fi
