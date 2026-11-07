# Storyboard review (run before showing the storyboard to the user)

Re-read the storyboard against the brief and fix what fails; report only what you could not fix. These checks come from real rounds where the same mistakes cost a feedback cycle each.

1. **Feasibility.** Run `python3 scripts/feasibility.py` with the storyboard's duration, scene count, text-scene count, words and track; resolve every NOT FEASIBLE and justify every TIGHT (see `references/feasibility.md`).
1b. **Readability budget.** For each scene compute `duration = end - start` and compare with its text: an essential line needs about 3 s stable, a line carrying a gag 2 s or more, a long legal or source line 4 s or more (about 15 characters per second is a comfortable ceiling for a full line, less on mobile). A scene shorter than its text needs more time, fewer words, or a merge.
2. **One idea per scene, no repeated sentence,** no explanation of what the image already shows.
3. **Timing on the music.** Every scene start is a bar or beat taken from `beats.json` (never counted by hand); the strongest moment sits on the strongest drop; a calm bar precedes it; flashes stay under 3 per second. Without music, scene lengths follow the reading budget.
4. **Image fits the words.** Each screenshot, visual or demo shown is the one that illustrates that scene's claim (an "offline" sentence needs the offline state, not a "synced" screen).
5. **Claims vs sources.** Every figure on screen has source, date and label; nothing from the excluded list appears; the legal line covers every source and date actually used; an illustrative example (invented time, name) is marked as such in the brief.
6. **Brand rules.** Colours per scene, banned words, logo behaviour, effects forbidden by the charter.
7. **Formats.** For each format chosen, state how every visual translates (a landscape screenshot in 9:16: crop, device frame or redraw), and that text fits.
8. **Languages.** Every line has a version in each language, adapted rather than literal; lengths checked (German and French run longer than English).
9. **Controls and ending.** Start screen, replay or loop as decided, last frame holds long enough to read the closing line; placeholders listed in the release gate.
10. **Weight.** Assets embedded fit the budget.
12. **Emotional arc.** Each scene's feeling and tension level match the arc in the brief; there is a clear build and a clear release; the peak lands on the strongest beat or drop; the memorable moment exists and has room (a breath before it, a hold after); the first 3 seconds and the last 3 seconds carry the intended feeling; nothing contradicts the "must not feel like" list.
13. **Message and attributes.** The one-sentence message is present and lands in the strongest or last moment; each chosen attribute is demonstrated by at least one scene through what happens, not through the word itself.
11. **Accessibility.** Understandable muted if required, contrast, flashes under 3 per second, reduced-motion option if promised.

Output: the storyboard table plus a short "checks" block listing what was adjusted and what remains a question for the user.
