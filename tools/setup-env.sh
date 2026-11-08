#!/bin/bash
# Checks and installs what the skill needs for its full mode.
#   setup-env.sh --check      status, one "key=ok|missing" per line (what the app reads at launch)
#   setup-env.sh [--install]  installs what is missing: Python venv (numpy, fonttools), node modules
#                             (jsdom, @napi-rs/canvas) and, when Homebrew exists, node and ffmpeg.
# Nothing is installed outside ~/Library/Application Support/ShowreelStudio/env except Homebrew formulas,
# and Homebrew itself is never installed by this script.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
ENVDIR="$HOME/Library/Application Support/ShowreelStudio/env"
VENV="$ENVDIR/venv"
NODEDIR="$ENVDIR/node"
have() { command -v "$1" >/dev/null 2>&1; }

# On a Mac without the Command Line Tools, /usr/bin/python3 is a stub that opens an install dialog: do not call it.
python_usable() {
  if [ "$(uname)" = "Darwin" ] && ! xcode-select -p >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/python3 ] && [ ! -x /usr/local/bin/python3 ]; then return 1; fi
  have python3 && python3 -c "import venv" 2>/dev/null
}
node_has() { have node && NODE_PATH="$NODEDIR/node_modules" node -e "require('$1')" 2>/dev/null; }

status() {
  python_usable && echo python3=ok || echo python3=missing
  "$VENV/bin/python" -c "import numpy, fontTools" 2>/dev/null && echo pypackages=ok || echo pypackages=missing
  have node && echo node=ok || echo node=missing
  have npm && echo npm=ok || echo npm=missing
  node_has jsdom && echo jsdom=ok || echo jsdom=missing
  node_has @napi-rs/canvas && echo canvas=ok || echo canvas=missing
  have ffmpeg && have ffprobe && echo ffmpeg=ok || echo ffmpeg=missing
  have brew && echo brew=ok || echo brew=missing
}

install() {
  local brew_missing=()
  { have node && have npm; } || brew_missing+=(node)
  { have ffmpeg && have ffprobe; } || brew_missing+=(ffmpeg)
  if [ ${#brew_missing[@]} -gt 0 ]; then
    if have brew; then
      echo "== Homebrew: ${brew_missing[*]}"
      brew install "${brew_missing[@]}" || echo "!! brew install failed"
    else
      echo "!! Homebrew is not installed (https://brew.sh): needed for ${brew_missing[*]}"
    fi
  fi
  if python_usable; then
    echo "== Python packages (numpy, fonttools, brotli)"
    mkdir -p "$ENVDIR"
    [ -x "$VENV/bin/python" ] || python3 -m venv "$VENV" || echo "!! could not create the Python environment"
    [ -x "$VENV/bin/pip" ] && "$VENV/bin/pip" install --quiet numpy fonttools brotli || echo "!! pip install failed"
  else
    echo "!! Python 3 is missing: install the Command Line Tools with 'xcode-select --install', then check again"
  fi
  if have node && have npm; then
    echo "== Node modules (jsdom, @napi-rs/canvas)"
    mkdir -p "$NODEDIR"
    ( cd "$NODEDIR" && { [ -f package.json ] || npm init -y >/dev/null; } && npm install --silent jsdom @napi-rs/canvas ) || echo "!! npm install failed"
  fi
  echo "== Done"
}

case "${1:---install}" in
  --check) status ;;
  --install) install; echo "== Status"; status ;;
  *) echo "usage: setup-env.sh [--check|--install]"; exit 2 ;;
esac
