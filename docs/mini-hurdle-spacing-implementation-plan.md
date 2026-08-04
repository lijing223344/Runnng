# Mini Hurdle Spacing Implementation Plan

Goal: Add a home-entry feature that calculates mini hurdle spacing from greater trochanter length while teaching coaches how to select a spacing target.

Architecture: Implement a pure calculator in `Running/Utilities` and a SwiftUI page in `Running/Views/MiniHurdle`. The page follows the existing model-generator pattern: localized copy, dark cards, segmented choices, numeric input, summary metrics, and detailed placement rows.

Tasks:
- Add `MiniHurdleSpacingTests.swift` first, using the Excel sample values as regression coverage.
- Add `MiniHurdleSpacing.swift` with profile, strategy, mark, result, and calculator types.
- Add `MiniHurdleSpacingView.swift` with GT measurement guidance, inline schematic, strategy selection, and spacing table.
- Add a home card and design-system accent color.
- Add Chinese and English localization strings.
- Run targeted tests and a simulator build/test command.
