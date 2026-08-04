# Mini Hurdle Measurement Upgrade Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the confusing hand-drawn GT leg-length measurement diagram with a source-traceable anatomy/anthropometry visual and tighten the track-training copy around how coaches should measure, choose, and progress mini-hurdle spacing.

**Architecture:** Keep the existing mini-hurdle calculator and athlete profile storage unchanged. Limit changes to the SwiftUI measurement/education surface, localized strings, image assets, asset attribution, and focused UI/build verification. Do not alter the spacing formula unless a separate reviewed requirement asks for it.

**Tech Stack:** SwiftUI, Xcode asset catalogs, localized `.strings`, XCTest/XCUITest, existing `DS` design tokens.

---

## Current Findings

- `Running/Views/MiniHurdle/MiniHurdleSpacingView.swift:2523` now routes the measurement section to `MiniGTMeasurementDiagram`, a SwiftUI-drawn side silhouette. This is the main user-facing problem: the body proportions and bone landmark relationship are too abstract for a coach to trust as a GT measurement guide.
- `Running/Views/MiniHurdle/MiniHurdleSpacingView.swift:2596` hard-codes landmark coordinates in a synthetic body drawing. Even if the labels are correct, the drawing cannot serve as a credible anatomical reference.
- `Running/Assets.xcassets/MiniHurdleMeasurementStep3.imageset/MiniHurdleMeasurementStep3.svg` is a generic standing-body vector. It should be replaced or removed from the primary measurement experience because it is not a real measurement reference.
- `Running/Resources/zh-Hans.lproj/Localizable.strings:256` and `Running/Resources/en.lproj/Localizable.strings:256` say all reference images are Wikimedia public-domain material. That is inaccurate if OpenStax/AnatomyTOOL material remains in use, because OpenStax is CC BY and requires attribution.
- Existing GT measurement copy is directionally correct but too clinical. It should be rewritten as field-facing track coaching guidance: why GT height controls max spacing, how to avoid bad measurement, how to start conservatively, and what movement quality tells the coach to adjust.

## Source And License Decisions

- Prefer a no-AI replacement. Do not generate a new anatomical image with an image model.
- Use source-traceable open materials:
  - OpenStax/AnatomyTOOL Hip Joint figure, CC BY. Source page: `https://anatomytool.org/content/openstax-anatphys-fig918-hip-joint-english-labels`. Attribution requirement shown on that page: credit OpenStax and CC BY.
  - Gray's Anatomy `Gray436.png`, public domain. Source page: `https://commons.wikimedia.org/wiki/File:Gray436.png`.
- If the executor finds a clearer public-domain trochanterion-height measurement image, it may replace the above candidate only if the source page clearly permits commercial redistribution and modification. Add the exact source URL and license to the attribution doc.
- Avoid ResearchGate, Scribd, textbook screenshots, proprietary anatomy apps, or unattributed web images. They are not acceptable app assets.

## Target UX

- The first visible measurement graphic should be a real/reference anatomy image or a composite based on open anatomy material, with clean app-drawn overlays for:
  - iliac crest/upper pelvis is only an orientation landmark;
  - superior greater trochanter/GT point is the measurement point;
  - measurement goes vertically from GT to floor/standing surface;
  - diagonal outside-leg or pants-seam measurements are invalid.
- The expanded guide may keep concise step rows and error warnings, but the top-level card must be readable without expansion.
- Use iOS-accessible layout: no overlapping labels, no color-only meaning, meaningful accessibility labels, and Dynamic Type-friendly text styles where the touched code allows it.

---

### Task 1: Add Or Update UI Coverage

**Files:**
- Modify: `RunningUITests/RunningUITests.swift`

- [ ] **Step 1: Add focused UI assertions for the upgraded measurement guide**

Require the mini-hurdle measurement section to expose stable identifiers:

- `mini_hurdle_gt_measurement_diagram`
- `mini_hurdle_gt_marker`
- `mini_hurdle_vertical_measure_line`
- `mini_hurdle_measurement_source_note`
- `mini_hurdle_wrong_iliac`
- `mini_hurdle_wrong_diagonal`

- [ ] **Step 2: Run the focused UI test before implementation**

Run:

```bash
xcodebuild test -project Running.xcodeproj -scheme Running -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RunningUITests/RunningUITests/testMiniHurdleMeasurementSection
```

Expected before implementation: fail if the new source-note identifier or replacement diagram semantics do not exist.

---

### Task 2: Replace The Primary Measurement Visual

**Files:**
- Modify: `Running/Views/MiniHurdle/MiniHurdleSpacingView.swift`
- Modify: `Running/Assets.xcassets/MiniHurdleMeasurementStep3.imageset/Contents.json`
- Replace or add image asset under: `Running/Assets.xcassets/MiniHurdleMeasurementStep3.imageset/`
- Optional add if cleaner: `Running/Assets.xcassets/MiniHurdleGTHeightMeasurement.imageset/`

- [ ] **Step 1: Replace the top hand-drawn SwiftUI silhouette**

The primary card should no longer depend on `MiniGTAthleteSideSilhouette` as the anatomical source. Use a real/open anatomy asset as the base and draw only measurement overlays in SwiftUI.

- [ ] **Step 2: Keep the interaction contract stable**

Preserve or reassign these identifiers on the new visual:

- `mini_hurdle_gt_measurement_diagram`
- `mini_hurdle_gt_marker`
- `mini_hurdle_vertical_measure_line`
- `mini_hurdle_wrong_iliac`
- `mini_hurdle_wrong_diagonal`

- [ ] **Step 3: Make the visual coach-readable**

The visual must show:

- GT point lower than iliac crest and lateral to proximal femur.
- A vertical measurement line dropping from the GT point to a floor/standing baseline.
- A clear warning that iliac crest and diagonal thigh line are not valid GT leg-length measurements.
- No ambiguous full-body proportions that imply a non-human shape.

- [ ] **Step 4: Remove unused diagram-only code if it becomes dead**

If `MiniGTAthleteSideSilhouette`, `MiniCoachPalpationHand`, or related synthetic-shape helpers are no longer used, remove them in the same task. Keep unrelated mini-hurdle table/layout components unchanged.

---

### Task 3: Rewrite Field-Facing Copy

**Files:**
- Modify: `Running/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Running/Resources/en.lproj/Localizable.strings`

- [ ] **Step 1: Upgrade the Chinese copy first**

Rewrite the measurement and training guidance keys around these points:

- Define `GT 下肢长` as `大转子上缘到站立地面的垂直高度`.
- Say why it matters for track training: it estimates the athlete's practical max stride spacing reference, not medical leg length.
- Coach workflow: stand square, palpate iliac crest, slide down to GT, confirm with gentle hip rotation, measure vertically, repeat both sides.
- Adjustment logic: start lower for first exposure/return/rebuild; use Mann as daily default only when rhythm and posture are stable; progress toward Clark upper only when the athlete runs through naturally without reaching.
- Quality stop signs: reaching, braking, hip drop, trunk lean-back, visible hurdling action, or speed decay.

- [ ] **Step 2: Keep English text aligned**

Update English strings to match the Chinese meaning, not as a literal word-for-word translation.

- [ ] **Step 3: Fix source-note wording**

If OpenStax remains in the asset set, source note must mention CC BY attribution. If only public-domain assets remain, it may say public-domain/modified public-domain.

---

### Task 4: Add Asset Attribution

**Files:**
- Create: `docs/asset-attribution/mini-hurdle-measurement.md`
- Modify: `Running/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Running/Resources/en.lproj/Localizable.strings`

- [ ] **Step 1: Document every source image**

For each retained source image, record:

- asset filename in the app;
- source page URL;
- creator/source;
- license;
- whether the app version is modified/cropped/overlaid.

- [ ] **Step 2: Add compact in-app attribution**

Keep the in-app source note short but accurate. Full detail belongs in `docs/asset-attribution/mini-hurdle-measurement.md`.

---

### Task 5: Verify

**Files:**
- Test: `RunningTests/MiniHurdleSpacingTests.swift`
- Test: `RunningUITests/RunningUITests.swift`

- [ ] **Step 1: Run calculator tests**

Run:

```bash
xcodebuild test -project Running.xcodeproj -scheme Running -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RunningTests/MiniHurdleSpacingTests
```

Expected: pass. Calculator behavior should be unchanged.

- [ ] **Step 2: Run focused UI test**

Run:

```bash
xcodebuild test -project Running.xcodeproj -scheme Running -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RunningUITests/RunningUITests/testMiniHurdleMeasurementSection
```

Expected: pass. The upgraded diagram and source note are reachable by accessibility identifiers.

- [ ] **Step 3: Run a simulator build**

Run:

```bash
xcodebuild build -project Running.xcodeproj -scheme Running -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: build succeeds without asset catalog or SwiftUI compile errors.

- [ ] **Step 4: Manual visual check**

Open the mini-hurdle measurement section in simulator and verify:

- the first measurement visual is understandable at a glance;
- labels do not overlap on iPhone width;
- dark-mode contrast remains readable;
- expanded guide text reads as track-coaching guidance rather than medical copy.
