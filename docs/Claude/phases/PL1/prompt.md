---
type: phase-prompt
status: current
phase: PL1
date: 2026-11-10
summary: "Palette card: each contrast check sits under the swatch it judges, aligned with it, at any pane width."
tags:
  - prompt
---

# Phase PL1: the palette's contrast checks sit under their swatches

Read CLAUDE.md first and follow every rule (never run git, English interface, skill untouched, answer the owner in French and short, no screen so say what was not seen, no out-of-scope work: an idea goes in a note created with `python3 tools/docs_new.py idea`). Use `graphify query` before reading files. Views stay free of business logic. **Change only the layout of the checks**: the colours, the ratios, the thresholds (4.5:1 for text, 3:1 for accents) and the wording stay.

The owner's remark, on the Palette card of the Look editor (four swatches: Background, Text, Accent, Accent 2, then three checks below in a row): "OK with the checks, but they should be aligned under their respective colours."

## Step 0 (read-only, 5 lines at the top of the report)

a) Where the Palette card is drawn (the Look editor and any other place that shows the same swatches and checks, such as the package views or the Wizard's look board) and how the swatches and the checks are laid out today.
b) The pure model behind the checks (which pair each one judges, its ratio and threshold) and its tests.

## What to build

1. **One column per swatch.** Each check sits directly under the swatch it judges, left-aligned with the swatch's label and centred on its width if the swatch is narrow: "Text on background" under Text, "Accent on background" under Accent, "Accent 2 on background" under Accent 2. The Background swatch has no check of its own: leave its column empty, or show a quiet "reference" line if that reads better (say which). The columns follow the swatches' widths at any pane width, so the alignment holds when the pane is dragged wider or narrower; when a column is too narrow for its text, the text wraps to two lines under its own swatch (never overlapping the next column, never truncated without a tooltip).
2. **The grouping is expressed once.** The mapping "check → the swatch it belongs to" lives in the pure model in ShowreelKit (with tests), not in the view, so a palette with more or fewer colours (a package, a skin) places its checks correctly. A check with no swatch (a pair that spans two colours) goes in a row below the columns with its two names.
3. Apply the same layout wherever step 0 a found the same card. Keep the ok and fail marks, the ratios and the thresholds exactly as they are; a failing check keeps its warning mark and its text, in its own column.
4. **Nothing else:** no change to the palette editing, the contrast rules, the Look packages or the skill.

## Tests (no screen)

Each check maps to the right swatch for the standard four-colour palette; the Background has no check; a palette with five colours and one with three place their checks correctly; a check spanning two colours lands in the extra row; ratios and thresholds are unchanged (the existing contrast tests still pass untouched). Say which tests changed.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE `python3 tools/bump_app.py patch "..."`; never edit a version by hand. Update docs/Claude/ux-notes.md ("Built in PL1 (date)"), CLAUDE.md "Open work", then `python3 tools/docs_index.py --write`.

## Verification

During the work: `tools/verify.sh --fast`. At the end: the complete `tools/verify.sh`, then `tools/rebuild-app.sh` (in the batch: once at the end).

## Final report (docs/Claude/phases/PL1/report.md)

Step 0 results, what was built, the version, what is verified and what is not (no screen: nothing drawn is verified, say so plainly), and "To check by hand": the Palette card at the default width and dragged wider and narrower (each check under its swatch, wrapping without overlap), a palette with a failing contrast (the warning stays in its own column), and the same card in the other places step 0 found. Stop after the phase.
