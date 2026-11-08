#!/bin/bash
# Installs what the skill needs for the full mode, outside the repo:
#   a Python venv with numpy and fonttools (audio analysis, font licence audit)
#   node modules jsdom and @napi-rs/canvas (player test, real text measurement, MP4 export)
# ffmpeg comes from Homebrew (brew install ffmpeg), if it is missing.
# The app's bash tool puts both locations first on PATH and NODE_PATH automatically.
set -e
ENVDIR="$HOME/Library/Application Support/ShowreelStudio/env"
mkdir -p "$ENVDIR/node"

echo "1/3 Python venv (numpy, fonttools, brotli)"
python3 -m venv "$ENVDIR/venv"
"$ENVDIR/venv/bin/pip" install --quiet --upgrade pip
"$ENVDIR/venv/bin/pip" install --quiet numpy fonttools brotli

echo "2/3 Node modules (jsdom, @napi-rs/canvas)"
( cd "$ENVDIR/node" && { [ -f package.json ] || npm init -y >/dev/null; } && npm install --silent jsdom @napi-rs/canvas )

echo "3/3 ffmpeg"
if command -v ffmpeg >/dev/null 2>&1; then echo "ffmpeg found: $(command -v ffmpeg)"
else echo "ffmpeg missing: run 'brew install ffmpeg' (needed for tracks and MP4 export)"; fi

echo "Done. Reopen the app (or start a new conversation) so the environment check runs again."
