#!/bin/bash
# Clean install of the app's dependencies on macOS (Apple Silicon).
# Electron's own extraction can leave an incomplete app (missing framework, no path.txt);
# this script downloads through npm as usual, then extracts the cached zip with ditto.
# It never changes certificate settings.
set -e
cd "$(dirname "$0")/.."

echo "1/5 certificates: NODE_EXTRA_CA_CERTS=${NODE_EXTRA_CA_CERTS:-<not set>}"
if [ -n "$NODE_EXTRA_CA_CERTS" ] && [ ! -f "$NODE_EXTRA_CA_CERTS" ]; then
  echo "The certificate file above does not exist. Fix it first (see the Zscaler TLSi FAQ)."; exit 1
fi

echo "2/5 clean node_modules and install (install scripts skipped)"
rm -rf node_modules
npm install --ignore-scripts

echo "3/5 download Electron into the cache"
rm -rf node_modules/electron/dist node_modules/electron/path.txt
node node_modules/electron/install.js || true
ZIP=$(find "$HOME/Library/Caches/electron" -name "electron-v*-darwin-arm64.zip" -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1)
if [ -z "$ZIP" ]; then echo "No Electron zip in the cache: the download failed (see messages above)."; exit 1; fi
echo "    using $ZIP"

echo "4/5 extract with ditto"
rm -rf node_modules/electron/dist
mkdir -p node_modules/electron/dist
ditto -x -k "$ZIP" node_modules/electron/dist
printf "Electron.app/Contents/MacOS/Electron" > node_modules/electron/path.txt

echo "5/5 check"
if [ -d "node_modules/electron/dist/Electron.app/Contents/Frameworks/Electron Framework.framework" ]; then
  echo "OK. Start the app with: npm start"
else
  echo "Extraction incomplete: Electron Framework.framework is missing."; exit 1
fi
