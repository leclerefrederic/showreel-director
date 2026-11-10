---
type: phase-report
status: current
phase: PL1
date: 2026-11-10
summary: "Report of PL1: each contrast check of the Palette card sits under the swatch it judges, from a pure column model in Kit; app 0.23.1."
app_version: 0.23.1
skill_version: 0.18.2
prompt:
  - "[[phases/PL1/prompt]]"
tags:
  - report
---

# PL1: the palette's contrast checks sit under their swatches

## Step 0

- a) The card is the design board (`DesignBoardView`, shown in the centre while the Look tab is open): a row of equal swatches (role, hex) then a row of the checks. Two other places show a palette with checks but not as swatch columns: the palette editor (a list of colour rows with the checks listed below) and the Catalogue's palette preview (a compact `Swatches` strip with the checks listed below). They are different cards and were left alone.
- b) `DesignBoard.make` builds `contrasts` from `Contrast.checks` (text, accent, accent 2, each against the background, 4.5 and 3 thresholds); check n judges swatch n+1. Tested in `ErgonomicsTests` (titles, ratios, levels), untouched.

## Built

1. `DesignBoard.ContrastLine.swatch` (the index of the swatch it judges, nil for a check that spans colours), `DesignBoard.columns` (one per swatch, with its check or none) and `DesignBoard.spanning` (the checks with no swatch): the mapping lives once, in Kit. The Background column has no check and stays empty (no "reference" line, to add no wording).
2. The view draws the checks in equal columns identical to the swatches' (padding 10, the same as the swatch label), so the alignment holds at any width; a long text wraps in its column (`fixedSize` vertical), and a tooltip gives title and detail whole. A spanning check goes in a row below.
3. Ratios, thresholds, marks and wording are as before.

## Deviations

- No check spans two colours today, so the extra row is exercised by a test only.
- A fifth colour ("Extra") has a swatch and no check, as `Contrast.checks` never judged it.

## Tests

`PL1Tests` (7). No existing test changed (`ErgonomicsTests` and the contrast tests pass untouched).

## Verified, not verified

Verified: build, tests, `verify.sh`. Not verified (no screen): the layout, the alignment, the wrapping.

## To check by hand

The Palette card at the default width and dragged wider and narrower (each check under its swatch, wrapping without overlap); a palette with a failing contrast (the warning stays in its own column); the palette editor and the Catalogue preview, which were not changed.
