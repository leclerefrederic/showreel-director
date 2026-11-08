#!/bin/bash
# Checks that the built app is standalone: everything it reads at run time is inside the bundle.
# Usage: tools/verify-bundle.sh [path/to/ShowreelStudio.app]
APP="${1:-$(cd "$(dirname "$0")/.." && pwd)/app-swift/build/ShowreelStudio.app}"
R="$APP/Contents/Resources"
fail=0
[ -d "$APP" ] || { echo "no app at $APP"; exit 1; }
for f in skill/SKILL.md skill/engine skill/scripts skill/references shared/tools.json shared/addendum.md \
         shared/capabilities.json setup-env.sh AppIcon.icns skill.hash; do
  [ -e "$R/$f" ] || { echo "MISSING in the bundle: $f"; fail=1; }
done
# only system libraries: nothing may point back to a build folder
bad=$(otool -L "$APP/Contents/MacOS/ShowreelStudio" | tail -n +2 | awk '{print $1}' | grep -v -E '^(/usr/lib/|/System/)' || true)
[ -z "$bad" ] || { echo "non-system libraries: $bad"; fail=1; }
# the seal must still hold (nothing inside the bundle changed after signing)
codesign --verify --deep --strict "$APP" 2>&1 || { echo "signature invalid"; fail=1; }
# run the self-test from a copy in another place, with another working directory
TMP=$(mktemp -d)
cp -R "$APP" "$TMP/"
( cd / && "$TMP/ShowreelStudio.app/Contents/MacOS/ShowreelStudio" --selftest ) || fail=1
codesign --verify --deep --strict "$TMP/ShowreelStudio.app" 2>&1 || { echo "signature invalid after running"; fail=1; }
rm -rf "$TMP"
if [ $fail -eq 0 ]; then echo "BUNDLE OK (standalone)"; else echo "BUNDLE NOT STANDALONE"; exit 1; fi
