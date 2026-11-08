# Showreel Studio, native macOS version (SwiftPM + WKWebView)

Same agent and same UI as `../app`, without Electron or Node for the model calls. The chat UI (`../app/src-ui`) is shown in a `WKWebView`; the agent loop (Messages API streaming), the tools and the Keychain storage of the API key are Swift. The macOS trust store is used for HTTPS, so the corporate TLS inspection certificate is already trusted.

Shared with the Electron app: `../app/shared/tools.json` (tool definitions) and `../app/shared/addendum.md` (system prompt addendum), plus the skill itself.

```
cd app-swift
swift build                 # compile
swift run                   # run from the source tree (resources are found by walking up)
./make-app.sh               # build/ShowreelStudio.app, ad-hoc signed
```

Needs `python3`, `node` and `ffmpeg` on the PATH for the skill's scripts (`bash` runs in a login zsh that also sources `~/.zshrc`).

Status: written without a Swift compiler at hand; expect a first round of compile fixes. The GitHub workflow `swift.yml` builds it on a macOS runner.
