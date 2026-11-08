# Showreel Studio (native macOS app)

A chat plus a preview pane that run the `showreel-director` skill with its own agent loop, so the look board, the pickers, the effects lab and the scene cards open next to the conversation.

Pieces: a `WKWebView` shows `ui/` (chat, question cards, preview iframe); `Agent.swift` streams the Messages API over `URLSession`; `Tools.swift` runs the tools (`bash`, `read_file`, `write_file`, `list_dir`, `ask_user`, `show_page`); `Studio.swift` bridges the page and the native side and keeps the API key in the Keychain. The system prompt is the skill's `SKILL.md` plus `shared/addendum.md`; the tools are defined in `shared/tools.json`. HTTPS uses the macOS trust store.

```
cd app-swift
swift build                 # compile
swift run                   # run from the source tree (resources found by walking up)
./make-app.sh               # build/ShowreelStudio.app, ad-hoc signed
```

In the app: **API key...** (Keychain), **Endpoint...** (gateway base URL and Bearer or x-api-key; `ANTHROPIC_BASE_URL` is also read), **Project folder...**, then describe the reel. `python3`, `node` and `ffmpeg` must be on the PATH (`bash` runs in a login zsh that also sources `~/.zshrc`).

Status: written without a Swift compiler at hand, so expect compile fixes; the GitHub workflow `swift.yml` builds it on a macOS runner.
