# Mini Hurdle Measurement Diagram Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current GT leg-length measurement illustration with a more direct field-facing diagram.

**Architecture:** Keep the existing measurement section and explanatory copy, but replace the three anatomy-image panels with one self-contained SwiftUI diagram. The new diagram shows the correct vertical measurement from the greater trochanter to the floor plus two compact wrong-way examples.

**Tech Stack:** SwiftUI, XCTest UI tests, localized `.strings` files, existing `DS` design tokens.

---

### Task 1: Add UI Coverage For The New Diagram

**Files:**
- Modify: `RunningUITests/RunningUITests.swift`

- [ ] **Step 1: Write a failing UI test**

Add a test that direct-launches the mini hurdle measurement section in Chinese and expects:

- `mini_hurdle_gt_measurement_diagram`
- `mini_hurdle_gt_marker`
- `mini_hurdle_vertical_measure_line`
- `mini_hurdle_wrong_iliac`
- `mini_hurdle_wrong_diagonal`

- [ ] **Step 2: Run the focused UI test and verify it fails**

Run a focused `xcodebuild test` for the new UI test. Expected failure: new accessibility identifiers do not exist yet.

### Task 2: Implement The Direct Diagram

**Files:**
- Modify: `Running/Views/MiniHurdle/MiniHurdleSpacingView.swift`
- Modify: `Running/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Running/Resources/en.lproj/Localizable.strings`

- [ ] **Step 1: Replace `MiniHurdleIllustration` content**

Render one new `MiniGTMeasurementDiagram` instead of the three existing anatomy panels.

- [ ] **Step 2: Draw the correct measurement**

Use SwiftUI shapes to draw:

- Side-view athlete silhouette.
- Highlighted greater-trochanter point on lateral hip.
- Thick vertical measurement line from GT point to floor.
- Ground baseline.
- Labels for GT point, vertical ruler, and natural standing.

- [ ] **Step 3: Add wrong-way examples**

Add two small comparison tiles:

- Wrong: iliac crest is too high and should not be used as GT.
- Wrong: diagonal leg measurement should not be used.

- [ ] **Step 4: Add localized labels**

Add short Chinese and English labels for correct measurement, wrong iliac point, wrong diagonal measurement, and vertical-to-floor instruction.

### Task 3: Verify

**Files:**
- Test: `RunningUITests/RunningUITests.swift`

- [ ] **Step 1: Run focused UI test**

Expected: the new diagram identifiers exist.

- [ ] **Step 2: Run focused build or relevant tests**

Expected: SwiftUI compiles and existing mini hurdle tests still pass.
