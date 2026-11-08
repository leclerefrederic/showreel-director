#!/bin/bash
# Builds ShowreelStudio.app (unsigned except for the ad-hoc signature macOS requires on Apple Silicon).
set -e
cd "$(dirname "$0")"
swift build -c release
APP="build/ShowreelStudio.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/ShowreelStudio" "$APP/Contents/MacOS/"
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
cp -R ../app/src-ui "$APP/Contents/Resources/ui"
cp -R ../app/shared "$APP/Contents/Resources/shared"
cp -R ../showreel-director "$APP/Contents/Resources/skill"
find "$APP" -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
find "$APP" -name .DS_Store -delete 2>/dev/null || true
codesign --force --deep -s - "$APP"
echo "Built $APP. Open it with: open $APP"
