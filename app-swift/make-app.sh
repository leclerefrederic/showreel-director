#!/bin/bash
# Builds ShowreelStudio.app (unsigned except for the ad-hoc signature macOS requires on Apple Silicon).
set -e
cd "$(dirname "$0")"
# Build products live outside the repo (and outside any synced folder).
SCRATCH="$HOME/Library/Developer/ShowreelStudio/build"
swift build -c release --scratch-path "$SCRATCH"
BIN="$(swift build -c release --scratch-path "$SCRATCH" --show-bin-path)/ShowreelStudio"
# swift build can report success while an edited file failed to compile: refuse a binary older than the sources.
STALE=$(find Sources -name '*.swift' -newer "$BIN" | head -1)
if [ -n "$STALE" ]; then echo "build is stale: $STALE is newer than the binary"; exit 1; fi
APP="build/ShowreelStudio.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<'P'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Showreel Studio</string>
<key>CFBundleIdentifier</key><string>local.showreel.studio.swift</string>
<key>CFBundleExecutable</key><string>ShowreelStudio</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
P
cp -R shared "$APP/Contents/Resources/shared"
cp -R ../showreel-director "$APP/Contents/Resources/skill"
python3 ../tools/skill_hash.py > "$APP/Contents/Resources/skill.hash"
cp ../tools/setup-env.sh "$APP/Contents/Resources/setup-env.sh"
find "$APP" -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
find "$APP" -name .DS_Store -delete 2>/dev/null || true
# A stable signing identity keeps the Keychain's "Always Allow" across rebuilds; ad hoc ("-") changes it every build.
IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  # first choice: a free local certificate named "Showreel Studio Local"; then an Apple Development identity
  IDENTITY=$(security find-identity -p codesigning 2>/dev/null | grep -m1 -o -E '"Showreel Studio Local"|"Apple Development: [^"]*"' | tr -d '"' || true)
fi
[ -n "$IDENTITY" ] || IDENTITY=-
codesign --force --deep -s "$IDENTITY" "$APP"
echo "Signed with: $IDENTITY"
echo "Built $APP. Open it with: open $APP"
