# BF1: "Clap did not write v2" at Build

## Step 0 (read only)

**a) Where the agent stops, and why.**
- Proved by the project's files: the chat of the trailer holds two app requests ("Build requested", 14:38 and 14:45 UTC), no assistant text after either, and no error line. `v1/` and `v2/` hold only `film.json`: Clap wrote nothing. The agent therefore ended its turn normally from the app's point of view, without an exception.
- Proved by the code (`Agent.swift`, before BF1): the loop returned silently on any stop reason other than `tool_use`, including `max_tokens`. The cap was a fixed 8000 tokens (`MessagesTransport.swift`) and the loop a fixed 60 steps. A tool call cut by the cap was neither shown, nor run, but was kept in the history. Nothing logged the stop reason (`~/Library/Logs/ShowreelStudio` only holds `drag.log`; the API's stop reason was never written anywhere).
- Hypothesis, not proven: the answer after the five reads hit the 8000-token cap while writing the 15 scene files (and `project.json`, `reel.js`) as tool calls. It fits everything seen (a silent stop right where the writing starts, no error, no file), but no record of the stop reason exists to confirm it. A refusal or an empty reply would look the same; BF1 now tells them apart.
- Not the cause: the 60-step limit (five commands were run), a timeout (no error was raised), an API error (it would have printed "Error: ...").

**b) Size of the system prompt.** SKILL.md + addendum (with its capabilities table, `{{capabilities}}` expanded at run time), in characters of the source files: skill 0.14.2 14 771 + 14 768 (+ capabilities 7 511); 0.16.0 14 863 + 18 565 (+ 11 090); now (0.18.1) 14 920 + 18 960 (+ 11 357). Roughly +4 000 characters (about 1 000 tokens) since 0.16.0, on a prompt of about 9 000 tokens. The 0.17.0 skill itself is not in the backups; the 0.16.0 and 0.18.1 files frame it. This does not explain the stop: the cap is on the output, not on the prompt. The Build message itself (15 scenes with their contents) is larger than that growth.

**c) "Build requested" twice.** Two real requests, seven minutes apart: the user pressed the button again after the first alert ("try again"). No automatic retry exists (the only callers of `startBuild` are the button and the fonts card's answer), and the chat does not draw a record twice. Nothing to change besides the silence of the first failure.

**d) A 2-scene Build.** Not testable without a key: it needs the real model. By the numbers, two scenes plus `project.json` and `reel.js` fit much more easily in one answer, so it would likely pass, but that is an inference.

## What changed (app 0.9.2, the skill is untouched)

- `BuildStop.swift` (new): `AgentStop` (finished, token limit, step limit, refusal, empty reply, cancelled, other), `AgentBudget`, `BuildStop.conclude` (the message, the journal line, nothing frozen, the empty stub folder removed, what Clap wrote kept and named).
- `Agent.send` returns how the turn ended. A tool call cut by the cap is not run and not kept. `AnthropicTransport` takes its cap per request and puts the usual one back.
- Build budget: `8000 + 1600 x scenes` tokens and `40 + 4 x scenes` steps, ceilings 32 000 and 120 (15 scenes: 32 000 and 100). A plain question keeps 8000 and 60.
- The alert says the cause and offers "Try again" and, for a limit, "Generate the scenes one by one" (a retry asking for one file per answer). The chat gets the same message. The journal gets one line per stopped Build ("Build v2 stopped: token-limit").
- The doubled "Build requested": nothing to fix (c). The one-by-one retry says so in its status line.

## Verified, not verified

- Verified: `tools/verify.sh --fast` during the work; 9 new tests (`BF1Tests`): each stop reason, the cut tool call, the cap asked and put back, the budget and its ceiling, each message and way, nothing partial and nothing frozen, the next Build reusing the name, files written by Clap kept, the one-by-one prompt.
- Not verified: any real model call (no paid call was made), whether 32 000 tokens is enough for the trailer, and the alert's look (no screen).

## To check by hand

1. Run "Build a new version" on the trailer. Either `v1` is written and built, or the alert names the cause.
2. If it says the output limit, press "Generate the scenes one by one" and tell me whether `v1` is written.
3. Open the project's history: a stopped Build shows one line with its cause.
