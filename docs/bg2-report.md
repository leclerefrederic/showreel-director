# BG2: rate-limit retries, then scenes written in parallel (app 0.11.0, skill unchanged 0.18.2)

Part A was finished, tested and checked with `tools/verify.sh --fast` before part B was started.

## Part A: retry on 429 and 529

1. `APIBusy` (BuildStop.swift) is raised by the transport for a 429, a 529, a 502/503/504, and a 5xx with `x-should-retry: true`; it carries the API's text and its `retry-after`. `SceneWriter.answer` waits `AgentLimits.busyDelay` (the header, else 5 s doubled at each attempt, never more than 120 s; named constants, `busyRetries` = 5) and asks again. The panel line is "Waiting for the API, retry in 20 s (2 of 5)" and counts down each second; the journal has one line per attempt ("Waiting for the API on S04, retry in 20 s (2 of 5)", note with the status, the kind and the retry-after).
2. Any other 4xx (and a 5xx without the mark) is never retried and keeps the API's text ("API 400: ...").
3. One counter per scene for both kinds: connection cuts are allowed while it is under 2, busy answers while it is under 5; the journal note of each attempt says which kind ("the request was cut" or "the API is busy (429, rate limit)"). The final error says "(tried N times)".
4. The wait is a sliced `Task.sleep` outside every request: Cancel ends it at once, and the three time rules of a request (silence, no content, longest) belong to the request and do not run during a wait.

## Part B: scenes written at the same time

5. Settings > Advanced "Scenes written at the same time" (1 to 4, default `AgentLimits.defaultSceneWidth` = 3), with the sentence asked for. A Build started from code with no width stays at 1.
6. The frame is written first and alone; then a `TaskGroup` runs the scenes in a sliding window (`BuildJob.runSteps`). Files are saved whole and recorded per scene (build.json changes are now behind one lock, `SceneModules.bookLock`, because two scenes finishing together would lose each other's record otherwise). The assembly reads the storyboard, never the arrival order (tested: the same `main.js` at 1, 2, 3, 4 with the slowest scenes first).
7. Every scene request carries "The whole storyboard, one line per scene": id, words, length, mood (feeling), passage into the next scene, computed from the storyboard. The summary of the scenes already finished still exists.
8. A 429 or 529 lowers the width by one for the rest of that Build and says "Lowered to 2 scenes at once: the API is limiting requests" (journal and panel); never below 1; the scenes in flight all meet the same limit, so a lowering is not repeated for 15 s (`WidthGate`).
9. A scene that fails with an error does not stop the ones in flight; no new scene starts after it; the Build ends on "Continue vN". A scene whose test fails twice does not stop the others either (as before). Test, one repair, bounds, retries and the journal are per scene.
10. The panel: all the scenes that are writing show as active rows, "Clap is writing 3 scenes at once", "4 of 15 scenes done" with the bar moving at each file, "real time 5 min" and "writing time added up 12 min". Phase and notice are now per scene (`SceneRun.clapPhase`, `notice`).
11. Cancel cancels the group: every request in flight stops, files are written whole in one step (never half), the scenes saved and tested stay, a scene saved but not yet tested is tested again at the next Build with no request. The journal says who cancelled (BA2) and "Build vN ended: cancelled".
12. The card has a "Time" line: "about 6 min at 3 scenes at once (125 output tokens a second, the default until a Build measures it)". The figures come from the project's last Build ("Build measured" journal line: tokens a second, tokens a scene, width, real time, time added up), defaults `defaultTokensPerSecond` = 125 and `defaultSceneTokens` = 7 000. The frame counts as one scene, alone. After each Build that wrote scenes the measure is recorded.

A bug found on the way and fixed: the transport kept the output-token callback and the last request's figures in shared fields, so two requests at the same time would have mixed their counters and their log lines. `MessagesTransport.stream` now has a variant that takes its own callbacks (`onOutput`, `onStats`); the old shared one stays for the chat.

## Verified, not verified

- Verified: `tools/verify.sh --fast` at the end of part A and of part B, the complete `tools/verify.sh` (VERIFY OK), `tools/rebuild-app.sh` (SELFTEST OK, BUNDLE OK, running, pid 4156).
- New tests, agent and API simulated, no paid call:
  - **BG2ATests (9):** the wait from `retry-after` or exponential with its ceiling; what is retryable; the transport reads the header and raises the busy error for 429, 529, 503 and a marked 500; a 400 is not retried and keeps its text; a 429 waits what it was told, shows the countdown and journals the kind; 529 and 5xx retried without a header, one journal line each; one shared counter (2 cuts + 3 busy works, a sixth retry is refused, a third cut is refused); Cancel ends a 30 s wait at once; 1 s time rules do not trip over a 2 s wait.
  - **BG2BTests (11):** never more than the chosen number in flight at 1 to 4, and the window really fills; every record survives; no two requests for the same file; the same film at 1 to 4 with the files arriving in another order; one scene failing among three (the others finish, none starts after, Continue writes only the missing ones); a failed test does not stop the others; one 429 among three lowers by one only, never below 1; Cancel with three in flight, then Continue writes only what is missing; every request carries the storyboard lines; one journal line per request and per attempt; the estimate uses the measured speed or the default; a Build records its speed, real time and time added up.
- Not verified: any real call (no paid call), so a real 429 and the real gain of parallel writing are not seen; the look of the panel and the Settings field (no screen); the real behaviour of the model when it writes without seeing its neighbours (the quality of the film at 3 at once is for you to judge); the estimate against a real Build.

## To check by hand

1. A full Build of the trailer at 1 scene at a time, then at 3 at once: note the total time, the "Build measured" line of the journal (tokens a second, tokens a scene, real time, time added up) and the cost of each. Compare the two films.
2. At 3 at once, press Cancel in the middle with three scenes writing, then Continue: only the missing scenes are written.
3. Read `~/Library/Logs/ShowreelStudio/build.log`: one line per request and per attempt, "Lowered to 2 scenes at once" if the API limited you.
4. If the API limits requests, the panel shows "Waiting for the API, retry in N s (k of 5)".
