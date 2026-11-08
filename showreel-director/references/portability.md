# Portability: when the session has different tools

The skill is written for an environment with file tools, a shell, a multiple-choice question tool, a way to ask for a working folder and a way to show files to the user (Claude Cowork has all of them). Other environments (Claude Code, another agent platform, a plain chat) lack some. The method does not change; only the way each step is carried out does. Map each step to what the session actually offers, and say once, in plain words, what is different.

| Step needs | Cowork-style tool | If it is missing |
|---|---|---|
| Ask the user questions in rounds | multiple-choice question tool | Ask in plain text: number the options (1-4), put the recommended one first and mark it, accept a number or free text. Keep the same limit of 4 questions per round. |
| A working folder that persists | directory-request tool | Ask for a folder path and work there. If the session is a plain chat with no files, work in a temporary folder or deliver everything inline and say that nothing persists. |
| Show a file (reel, lab, cards, MP4) | present-files tool | Print the file path and tell the user how to open it (double-click, `open <path>`, `xdg-open <path>`, or drag into a browser). For small text files, show the content inline. |
| Fill in the project questions and decide on assets on screens | project and resources screens (desktop app) | Ask the questions in rounds and put the asset decisions on a decision sheet, as the steps say. |
| Let the user read and edit the project files next to the assistant | an advanced file panel with editors, history and diffs for proposed changes (desktop app) | Write the file, give its path and say what changed; ask the user to open and edit it, to say when they are done, and read it again before relying on it. Never overwrite a prose file the user may be editing without showing what changes. |
| Look at the result (contact sheets) | screenshot tool | Use a headless browser if `check_env.py` found one; otherwise ask the user to open `qa/contact-<vN>.html` and describe or paste what they see. Never claim to have looked at frames you cannot see. |
| Persist or share a page | artifact tool | Deliver the HTML file only and explain how to share it. Do not promise a hosted link. |
| Run scripts | shell | Without a shell none of the scripts run: do the interview, brief and storyboard in conversation, write `main.js` and the HTML by hand from `engine/` without building, and tell the user what could not be verified (harness, audio analysis, MP4). The scene cards and effects lab sample are static files the user can open. |
| Read the track | numpy + ffmpeg | Ask for BPM, first beat and drop times, build the beat grid by hand, and say so in the brief (see `check_env.py` fallbacks). |
| Search the web | web search / fetch | Ask the user for the facts, figures or documents instead; never invent standards or figures. |

## Rules that never change
- The interview, feasibility gate, scene review and go still happen before any build.
- Brief, storyboard and release gate are still written as files when files exist, or shown in full in the chat when they do not.
- Say what could not be checked in the final report; a missing tool lowers the verification level, not the honesty of the report.
- Do not name a tool in front of the user: say what you are doing ("I'll ask you a few questions", "I need a folder to work in").

## Degraded-mode notice (first reply)
On invocation, list what the session lacks and what it costs, then carry on unless the user wants to fix things first. Example shape (adapt to the conversation language, no tool names): "Heads-up: some tools are missing here, so I will work in degraded mode. Without a way to run scripts I cannot run the automatic tests or export an MP4; without a question tool I will ask in numbered text. To get the full mode: enable script execution, or run me on a machine that has it. Shall I continue as is?" The final report repeats what stayed unverified.
