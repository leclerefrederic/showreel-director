---
type: phase-prompt
status: current
phase: BG2
date: 2026-11-09
summary: "Asks for retries on rate-limit errors, then scenes written in parallel."
report:
  - "[[phases/BG2/report]]"
tags:
  - prompt
---
# Phase BG2: rate-limit retries, then scenes written in parallel

Read CLAUDE.md, then docs/Claude/phases/BA1/report.md, docs/Claude/phases/BA2/report.md, docs/Claude/phases/BG1/report.md, docs/Claude/phases/BG1c/report.md, docs/Claude/phases/BG1d/report.md, and the code they describe: the per-scene Build (BuildJob.run), the transport (MessagesTransport.swift), the request bounds and retries added by BA2, SceneModules.swift, Availability.swift (SceneRun.State), BuildViews.swift and the build log. Follow every rule of CLAUDE.md (never run git, English interface, English skill, no out-of-scope work: an idea goes in docs/Claude/ideas.md in one line). Build only what is listed below.

## Context (measured by the owner)

- One scene costs about 7 000 to 8 000 output tokens and takes about one minute (about 125 tokens per second). The trailer (15 scenes) takes about 15 minutes written one at a time.
- The Build writes one scene per request, tests each scene right after writing it (no AI), repairs it once if its code fails, reuses scenes whose own record says "tested", and assembles with no AI. BA2 added a journal line per request, a 120 s "no content" rule that pings do not reset, an 8 min maximum per request, and up to 2 automatic retries after a lost connection.
- BA2 left one thing out on purpose: an API answer such as 429 (rate limit) or 529 (overloaded) is not retried. Writing scenes in parallel will hit it, so it must be handled first.

## Part A: retry on 429 and 529 (a phase of its own, delivered and tested before part B)

1. A 429 or 529 answer (and a 5xx that the API marks as retryable) is retried with a wait: use the `retry-after` header when present, otherwise an exponential delay with a ceiling (named constants). Maximum number of attempts is a named constant (5 by default). Each wait shows in the Build panel as "Waiting for the API, retry in 20 s (2 of 5)", and one journal line per attempt with the status code.
2. A 400-class answer other than 429 is never retried (it will not change). The message keeps the API's own text.
3. The attempts of part A and the lost-connection retries of BA2 share one counter per scene so that a scene never costs more than a few requests. Say in the journal which kind each attempt was.
4. Cancel stops a wait at once. The 120 s no-content rule and the 8 min bound do not run while the app is waiting between attempts.

## Part B: scenes written at the same time

5. Setting "Scenes written at the same time": 1 to 4, default 3 for this prototype (named constant), in Settings, Advanced. Sentence under it: "More at once is faster and costs a little more (each call repeats the scene contract), and scenes written together cannot see each other's result."
6. Scheduling: the skeleton (project.json, reel.js) is written first, alone. Then scenes run in a sliding window: as soon as one finishes, the next starts, never more than the chosen number. The assembly depends only on the order of the storyboard, never on the order in which files arrive.
7. Consistency without seeing neighbours still being written: each request gets, in addition to what BG1 already gives, one line per scene of the whole storyboard (id, words, duration, intended mood, neighbouring transition), computed by the app from the storyboard and not from written files. The summary of scenes already finished when the request starts still exists.
8. Rate limits during a parallel Build: when part A's retries hit a 429 or 529, lower the number of scenes written at once by one for the rest of this Build and say so ("Lowered to 2 scenes at once: the API is limiting requests"). Never go below 1.
9. A scene that fails does not stop the ones in flight. The Build ends after them and offers "Continue vN". The BA2 rules still hold per scene: tested record, one repair, bounds, retries, journal.
10. The panel shows several scenes "writing" at once, the bar advances at each file, and two durations: real elapsed time and cumulated generation time, so the gain is visible.
11. Cancel stops every request in flight, kills nothing that is writing a file halfway, keeps what is already written and tested, and journals who cancelled.
12. Confirmation card: add "about N minutes at M scenes at once", computed from the tokens per second measured on the project's last Build (recorded in the journal), 125 tokens per second by default (named constant), and from the average size of scenes already written, 7 000 tokens by default. Always worded as an estimate, never as a promise. After each Build, record the measured speed and the real duration.

## Tests (simulated agent and API, no paid call)

- Part A: 429 with and without `retry-after`, 529, a retryable 5xx, a 400 that is not retried, the wait shown, attempt counts shared with connection retries, Cancel during a wait, bounds suspended while waiting.
- Part B: never more than the chosen number in flight; identical assembly at 1, 2, 3 and 4 at once; one scene failing among three in flight; a 429 that lowers the concurrency; Cancel with three requests in flight; Continue after a stop; no two requests writing the same file; every request carries the one-line-per-scene storyboard; the estimate uses the measured speed when it exists and the default otherwise; the journal has one line per request and per attempt.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE tools/bump_app.py; never edit a version by hand. Update ROADMAP.md with what remains (the idea of more compact scenes that reuse the kit's helpers stays a known limit).

## Verification

During the work: tools/verify.sh --fast. At the end: the complete tools/verify.sh, then tools/rebuild-app.sh.

## Final report (docs/Claude/phases/BG2/report.md)

What was done point by point, the version, what is verified and what is not (no paid call, no screen), and "To check by hand": a full Build at 1 then at 3 scenes at once on the trailer with the total time, the measured speed and the cost of each; cancel in the middle with three requests in flight, then Continue; read build.log to see one line per request and per attempt. Stop after the phase. If part A cannot be finished cleanly, say so and stop before part B.
