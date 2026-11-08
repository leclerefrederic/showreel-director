# Showreel Studio (native macOS app)

A chat plus a preview pane that run the `showreel-director` skill with its own agent loop, so the look board, the pickers, the effects lab and the scene cards open next to the conversation.

Pieces: the package has two targets. `ShowreelKit` (a library, no window) holds the agent loop (`Agent.swift`, a `MessagesTransport` protocol so tests can script the model), the tools (`Tools.swift`: `bash`, `read_file`, `write_file`, `list_dir`, `ask_user`, `show_page`, `screenshot_preview`, `get_state`, `propose_edit`), the `AgentUI` protocol, the project model (`ProjectStore`, `ShowreelFile` for `showreel.json` schema 1, `ProjectImporter` for markdown-only projects, history in `.studio/history`, chat history in `.studio/chat`, `ProjectLibrary`, `FileWatcher`) and the parsers (markdown tables, CSV, line diff). `ShowreelStudio` (the executable) is the SwiftUI shell: a library window, one window per project (a sidebar of blocks with statuses on the left, the selected block in the middle, the copilot chat on the right), settings, setup screen. Blocks come from `shared/process.json` (Project and Resources are built; the others show "coming soon"); the file tree and editors live in an Advanced panel that is off by default. The preview pane is a `WKWebView` because the pickers and boards are HTML. The API key lives in the Keychain. The system prompt is the skill's `SKILL.md` plus `shared/addendum.md`; the tools are defined in `shared/tools.json`. HTTPS uses the macOS trust store.

`showreel.json` (schema 1, the contract of `docs/studio-spec.md` 5.1b, unknown keys kept) is the source of truth; `brief.md`, `style-sheet.md` and `storyboard.md` are generated from it, with their hashes in `.studio/generated.json`, and a file changed outside the app is never overwritten (the app offers a re-import). The copilot changes project data through typed operations (`update_parameter`, `update_asset`) that the user reads as plain cards and accepts or refuses; other prose and text files go through `propose_edit` as a diff. A project can switch on "Apply directly". The Resources block writes `assets/MANIFEST.csv` in the format of `scripts/organize_assets.py` (a test runs the script's `--check` on it). Every save, by the user or the copilot, keeps the previous version in `.studio/history/<file>/` (last 50), with diff and restore.

```
cd app-swift
swift build                 # compile
swift run                   # run from the source tree (resources found by walking up)
swift test                  # ShowreelKit tests: parsers, project model, history, tools, agent loop
./make-app.sh               # build/ShowreelStudio.app, ad-hoc signed
```

In the app: the library window lists the projects (New project, Open folder, pin, archive); each project opens in its own window; the gear opens Settings (API key in the Keychain, gateway base URL and Bearer or x-api-key, model; `ANTHROPIC_BASE_URL` is also read); then describe the reel. `python3`, `node` and `ffmpeg` must be on the PATH (`bash` runs in a login zsh that also sources `~/.zshrc`).

Environment: at launch the app runs `setup-env.sh --check` (bundled in the app) and shows a setup screen until Python 3, the Python packages (numpy, fonttools), Node.js, npm, jsdom, canvas and ffmpeg are present; **Install missing** runs `setup-env.sh --install` (a Python venv and the node modules under `~/Library/Application Support/ShowreelStudio/env`, node and ffmpeg through Homebrew when it is installed, never Homebrew itself). Python 3 comes from the Command Line Tools (`xcode-select --install`). A link lets the user continue without, in reduced mode. The script also runs from a terminal: `bash tools/setup-env.sh --check` or `--install`.

Icon: `Icon/AppIcon.png` is the 1024 px master, drawn by `python3 tools/make_icon.py` (an original design: a film reel with a play triangle). `Icon/AppIcon.icns` is the finished macOS icon (sizes 16 to 1024 px, retina included), committed with the master; `make-app.sh` copies it into the app.

Signing: the build looks for a code-signing certificate named `Showreel Studio Local` (create it once in Keychain Access, Certificate Assistant, type Code Signing, self signed), then an Apple Development identity, else it signs ad hoc. A stable identity keeps the Keychain's "Always Allow" for the API key across rebuilds.

Status: written without a Swift compiler at hand, so expect compile fixes; the GitHub workflow `swift.yml` builds it on a macOS runner.
