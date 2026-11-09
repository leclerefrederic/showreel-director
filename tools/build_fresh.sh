#!/bin/bash
# Is the binary the build of the sources as they are now? Decided by content, not by date.
# Usage: tools/build_fresh.sh BINARY SOURCES_DIR STAMP_FILE
# A source newer than the binary is only a problem when its content differs from what was last known to be built (the stamp): touching a file
# without changing it is not. After a pass the stamp is the content fingerprint of the sources.
BIN="$1"; SRC="$2"; STAMP="$3"
[ -f "$BIN" ] || { echo "build is missing: no binary at $BIN"; exit 1; }
HAVE="$(python3 "$(dirname "$0")/skill_hash.py" "$SRC")"
NEWER="$(find "$SRC" -name '*.swift' -newer "$BIN" | head -1)"
if [ -n "$NEWER" ] && [ "$(cat "$STAMP" 2>/dev/null)" != "$HAVE" ]; then
  echo "build is stale: $NEWER has changed since the binary was built"
  exit 1
fi
mkdir -p "$(dirname "$STAMP")"
echo "$HAVE" > "$STAMP"
exit 0
