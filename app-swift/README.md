# Showreel Studio (native macOS app)

A chat plus a preview pane that run the `showreel-director` skill with its own agent loop, so the look board, the pickers, the effects lab and the scene cards open next to the conversation.

Pieces: a native SwiftUI window (chat with question cards, a composer, settings, a toolbar to pick the project folder); the preview pane is a `WKWebView` because the pickers and boards are HTML. `Agent.swift` streams the Messages API over `URLSession`; `Tools.swift` runs the tools (`bash`, `read_file`, `write_file`, `list_dir`, `ask_user`, `show_page`); `ChatModel.swift` connects them to the interface through the `AgentUI` protocol; the API key lives in the Keychain. The system prompt is the skill's `SKILL.md` plus `shared/addendum.md`; the tools are defined in `shared/tools.json`. HTTPS uses the macOS trust store.

```
cd app-swift
swift build                 # compile
swift run                   # run from the source tree (resources found by walking up)
./make-app.sh               # build/ShowreelStudio.app, ad-hoc signed
```

In the app: the folder button (top left) picks the project; the gear opens Settings (API key in the Keychain, gateway base URL and Bearer or x-api-key, model; `ANTHROPIC_BASE_URL` is also read); then describe the reel. `python3`, `node` and `ffmpeg` must be on the PATH (`bash` runs in a login zsh that also sources `~/.zshrc`).

Environment: at launch the app runs `setup-env.sh --check` (bundled in the app) and shows a setup screen until Python 3, the Python packages (numpy, fonttools), Node.js, npm, jsdom, canvas and ffmpeg are present; **Install missing** runs `setup-env.sh --install` (a Python venv and the node modules under `~/Library/Application Support/ShowreelStudio/env`, node and ffmpeg through Homebrew when it is installed, never Homebrew itself). Python 3 comes from the Command Line Tools (`xcode-select --install`). A link lets the user continue without, in reduced mode. The script also runs from a terminal: `bash tools/setup-env.sh --check` or `--install`.

Signing: the build looks for a code-signing certificate named `Showreel Studio Local` (create it once in Keychain Access, Certificate Assistant, type Code Signing, self signed), then an Apple Development identity, else it signs ad hoc. A stable identity keeps the Keychain's "Always Allow" for the API key across rebuilds.

Status: written without a Swift compiler at hand, so expect compile fixes; the GitHub workflow `swift.yml` builds it on a macOS runner.
