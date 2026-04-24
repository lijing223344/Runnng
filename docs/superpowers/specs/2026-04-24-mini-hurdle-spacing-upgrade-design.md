# Mini Hurdle Spacing Upgrade Design

Date: 2026-04-24

## Goal

Upgrade the mini hurdle spacing module from a long explanatory page into a field-ready spacing workbench. The module must keep the Excel-derived calculation chain intact while making the primary training workflow faster and clearer on iPhone.

The upgraded module must support three use cases:

- Field setup: quickly lay out mini hurdles during training.
- Athlete management: save and switch athlete-specific GT and strategy settings.
- Education: explain GT measurement, Clark/Mann selection, progression, and quality checks.

Field setup is the default and highest-priority use case.

## Current Context

The current implementation has a stable pure calculator in `Running/Utilities/MiniHurdleSpacing.swift` and a large SwiftUI page in `Running/Views/MiniHurdle/MiniHurdleSpacingView.swift`.

The calculator already matches the workbook formula chain for the default 0.86 m GT examples and produces:

- 7 acceleration reference marks.
- 21 hurdle spacing rows.
- Continuous worksheet coordinates from start zero.
- Hurdle placement coordinates relative to the first hurdle.

The main usability issue is information hierarchy. Setup, athlete profile controls, results, progression advice, measurement teaching, research copy, and quality notes are all in one long scroll. This makes the module accurate but slow to use when a coach is standing on the track and needs the next mark.

## Product Design

### Top-Level Structure

Replace the single long page with a four-section workbench:

1. Field Setup
2. Athletes
3. Measurement
4. Method

These can be implemented as a segmented control, tabs inside the page, or a compact section switcher that fits the existing app style. The default selection is Field Setup.

### Field Setup

The Field Setup section is the first screen and must contain the complete workflow needed to place hurdles.

It includes:

- Current athlete selector: temporary input or saved athlete.
- Profile selector: women or men.
- GT input: centimeters or meters.
- Strategy selector: Mann default or Clark range.
- Clark ratio slider when Clark range is selected.
- Live calculated summary.
- Complete Excel-derived tables.

The top of this section should be compact. It should not push the first useful output far down the screen.

### Key Placement Summary

Show the most important field numbers immediately after setup:

- Hurdle 1 point from start.
- Hurdle 12 point from start.
- Hurdle 16 point from start.
- Hurdle 21 point from start.
- Span from hurdle 1 to hurdle 21.
- Recommended run-out distance after the last hurdle.

These values are derived from the same `MiniHurdleSpacingResult`; they are not separate formulas.

### Complete Excel Display

The user explicitly requires the mini hurdle placement points to be displayed like the Excel workbook. This is a hard requirement.

The UI should present two table modes:

#### Excel Original Chain

This table preserves the workbook mental model and auditability.

Rows:

- Start
- acc mark 1-7
- hurdle 1-21

Columns:

- Mark
- Step #
- Spacing
- Total
- % of drill SL

This table must show all rows from the workbook chain. It should include the start row and all 28 subsequent marks, for 29 rows total.

#### Field Placement Table

This table translates the Excel output into coaching language for the track.

Rows:

- hurdle 1-21 only

Columns:

- Hurdle number
- Spacing from previous hurdle
- Point from start
- Distance from hurdle 1
- Progression phase

The progression phase should identify the main field checkpoints:

- First 11-12 hurdles
- Extend to 16 hurdles
- Full 21 hurdles

Rows for hurdles 12, 16, and 21 should be lightly highlighted because they are the progression checkpoints.

### Athletes

Move athlete management out of the main result flow.

This section should provide:

- Saved athlete list.
- Current selected athlete.
- Create athlete from current setup.
- Edit name, profile, GT, unit, and strategy.
- Delete athlete.
- Clear selection and return to temporary input.

When a saved athlete is selected, edits on the setup controls may continue to auto-save to that athlete, matching the current behavior. The UI must make this clear enough that users do not accidentally overwrite an athlete profile without realizing it.

### Measurement

Keep the GT measurement education, but move it behind the Measurement section.

The section should preserve:

- GT definition.
- Three measurement illustrations.
- Palpation and rotation cues.
- Vertical measurement instructions.
- Repeat-measurement guidance.
- Common mistake warnings.

The default Field Setup screen should link to Measurement when the GT input is empty or invalid.

### Method

Move Clark/Mann research, progression guidance, and coaching quality checks into Method.

The section should include:

- Clark range explanation for the selected profile.
- Mann default explanation for the selected profile.
- How to choose a conservative, default, or advanced setup.
- Progression from 11-12 hurdles to 16 hurdles to 21 hurdles.
- Quality checks: overstriding, reaching, posture loss, high-knee behavior, and timing confirmation.

This content remains available but should not interrupt field placement.

## Data Model Design

The calculator should remain the source of truth. Formula results must not be duplicated in the view.

Recommended additions:

- A row model for the Excel original chain.
- A row model for field placement.
- A small phase enum for hurdle 12, hurdle 16, full 21, and normal rows.

Example conceptual models:

```swift
struct MiniHurdleExcelChainRow {
    let mark: String
    let stepNumber: Int
    let spacing: Double
    let total: Double
    let drillStrideLengthRatio: Double
}

struct MiniHurdleFieldPlacementRow {
    let hurdleNumber: Int
    let spacingFromPrevious: Double
    let pointFromStart: Double
    let distanceFromFirstHurdle: Double
    let phase: MiniHurdlePlacementPhase
}
```

These models can be computed from `MiniHurdleSpacingResult`. They do not need persistence.

## UI Architecture

The current `MiniHurdleSpacingView.swift` is too large for this upgrade. Split it into focused SwiftUI files:

- `MiniHurdleSpacingView.swift`: state owner and top-level section switcher.
- `MiniHurdleFieldSetupView.swift`: setup controls and key placement summary.
- `MiniHurdleExcelChainTable.swift`: Excel original chain table.
- `MiniHurdleFieldPlacementTable.swift`: 21-hurdle field placement table.
- `MiniHurdleAthleteViews.swift`: athlete selector, list, and editor sheet.
- `MiniHurdleEducationViews.swift`: measurement, method, progression, and quality sections.

This split keeps the calculation surface separate from presentation and makes UI tests easier to maintain.

## Interaction Requirements

- Default to Field Setup.
- Update all values live when GT, unit, profile, or strategy changes.
- Keep numeric formatting consistent with current behavior.
- Use monospaced digits for spacing and point values.
- Preserve existing accessibility identifiers where tests already depend on them.
- Add identifiers for new critical values:
  - `mini_hurdle_summary_point_1`
  - `mini_hurdle_summary_point_12`
  - `mini_hurdle_summary_point_16`
  - `mini_hurdle_summary_point_21`
  - `mini_hurdle_excel_chain_table`
  - `mini_hurdle_field_placement_table`
- Keep touch targets at least 44 points high for interactive controls.
- Avoid horizontal clipping on small iPhones. If the Excel table cannot fit all columns comfortably, use compact headers and proportional numeric columns before introducing horizontal scrolling.

## Non-Goals

- Do not change the Excel-derived formula chain unless a workbook mismatch is found.
- Do not add networking or cloud features.
- Do not change the stored athlete profile schema unless required for compatibility.
- Do not remove the measurement or method education content.
- Do not replace the Excel original chain with a simplified table.

## Test Plan

Unit tests:

- Existing workbook formula regression tests continue to pass.
- Excel original chain produces 29 rows: Start, 7 acceleration marks, and 21 hurdles.
- Start row has spacing 0 and total 0.
- Acc mark 7 total matches the workbook-derived value.
- Hurdle 1 spacing and total match the workbook-derived value.
- Hurdle 21 spacing and total match the workbook-derived value.
- Drill stride length ratio matches `spacing / maximumSpacing`.
- Field placement rows produce 21 hurdles.
- Hurdles 12, 16, and 21 have the expected phase labels.

UI tests:

- Opening the module defaults to Field Setup.
- The first screen shows the current setup and key points for hurdles 1, 12, 16, and 21.
- Switching to Excel Original Chain shows Start, acc mark rows, and hurdle rows.
- Switching to Field Placement Table shows 21 hurdle rows.
- Changing GT updates the summary values.
- Switching athlete updates the setup and placement values.
- Measurement and Method sections remain reachable.

## Acceptance Criteria

- A coach can open the module and see the main placement numbers without scrolling through educational content.
- The app still displays the full Excel-like chain with Mark, Step #, Spacing, Total, and % of drill SL.
- The app also provides a field-friendly 21-hurdle placement table.
- Athlete management remains available and does not dominate the Field Setup flow.
- Measurement and method guidance remain available in dedicated sections.
- Existing calculator results remain unchanged.
- Existing tests pass, and new tests cover the upgraded table outputs and section navigation.
