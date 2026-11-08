# Showreel Studio (macOS, experimental)

Desktop app around the `showreel-director` skill: chat on the left, preview pane on the right (look board, pickers, effects lab, scene cards, the reel). The app runs the skill itself: `SKILL.md` is the system prompt, the skill's scripts are run through a `bash` tool, decisions go through question cards.

## Run it (from this folder)

```
cd app
npm install
npm start
```

Then: **API key…** (stored encrypted with the macOS keychain), **Project folder…**, and describe the reel. Needs `python3`, `node` and `ffmpeg` on the PATH (the skill's environment check reports what is missing). Model: `claude-sonnet-5-5` by default.

Unsigned build: `npm run dist` (copies the skill into `resources/`, then builds a `.dmg` for Apple Silicon). Open it with right-click, Open.

## Design

- `src-main/skill.js` finds the skill (dev: `../showreel-director`, packaged: `resources/skill`) and builds the prompt.
- `src-main/agent.js` is the loop (Messages API, streaming, prompt caching on the system prompt).
- `src-main/tools.js`: `bash`, `read_file`, `write_file` (project only), `list_dir`, `ask_user`, `show_page`.
- `src-ui/`: chat, question cards, preview iframe, "Send my picks to the chat" (reads the clipboard, since the pickers copy their result).
- `npm test` runs the loop against a scripted fake client (no network, no Electron).

## Known limits

Not yet tested in a real Electron window; `bash` is not sandboxed (it runs as you, starting in the project folder); no screenshot tool for the model yet; ffmpeg and node are not bundled; no cost display.
