#!/bin/bash
# The guards of the app rebuild: touching a file without changing it does not fail the build check, a real change that was not built does,
# and rebuild-app.sh closes the app only after the build was found valid.
cd "$(dirname "$0")/.." || exit 1
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
expect() { # expect CODE "what" cmd...
  local want="$1" what="$2"; shift 2
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then echo "  ok   $what"; else echo "  FAIL $what (exit $got, wanted $want)"; fail=1; fi
}
G="bash tools/build_fresh.sh $T/bin $T/Sources $T/stamp"
mkdir -p "$T/Sources"; echo "let a = 1" > "$T/Sources/a.swift"; touch -t 202001010000 "$T/Sources/a.swift"; echo bin > "$T/bin"; touch -t 202001010100 "$T/bin"
expect 0 "a fresh binary passes" $G
touch -t 202001010200 "$T/Sources/a.swift"
expect 0 "touching a source without changing it passes (the script does not fail)" $G
echo "let a = 2" > "$T/Sources/a.swift"; touch -t 202001010300 "$T/Sources/a.swift"
expect 1 "a changed source the binary was not built from is stale" $G
echo bin2 > "$T/bin"; touch -t 202001010400 "$T/bin"
expect 0 "after the rebuild it passes again" $G
expect 1 "no binary is refused" bash tools/build_fresh.sh "$T/none" "$T/Sources" "$T/stamp"
grep -q "build_fresh.sh" app-swift/make-app.sh && echo "  ok   make-app.sh uses the content guard" || { echo "  FAIL make-app.sh does not use the content guard"; fail=1; }
c=$(grep -n -- "--check-only" tools/rebuild-app.sh | head -1 | cut -d: -f1); k=$(grep -n "pkill" tools/rebuild-app.sh | head -1 | cut -d: -f1)
if [ -n "$c" ] && [ -n "$k" ] && [ "$c" -lt "$k" ]; then echo "  ok   rebuild-app.sh checks the build before it closes the app"; else echo "  FAIL rebuild-app.sh closes the app before the build is checked"; fail=1; fi
exit $fail
