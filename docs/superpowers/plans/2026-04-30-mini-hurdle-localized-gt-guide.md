# Mini Hurdle Localized GT Guide Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the GT length measurement guide image in Chinese or English according to the app's active language, including when language is set to follow system.

**Architecture:** Keep the existing Chinese asset as the default image and add a parallel English image asset with the provided PNG. Add a tiny language-aware asset selection point near `MiniGTMeasurementDiagram`, reusing `LocalizationPreferenceResolver.resolveBundleLanguage` so explicit and system language choices behave the same as localized strings. Avoid changing mini hurdle spacing math or unrelated UI.

**Tech Stack:** SwiftUI, Xcode asset catalogs, existing `LocalizationManager` and `LocalizationPreferenceResolver`, XCTest/UI smoke where practical.

---

## File Structure

- Modify: `Running/Views/MiniHurdle/MiniHurdleSpacingView.swift`
  - Add an asset-name parameter or computed helper for `MiniHurdleIllustration` / `MiniGTMeasurementDiagram`.
  - Select English asset when the resolved bundle language is `en`; otherwise use the existing Chinese asset.
- Create: `Running/Assets.xcassets/MiniHurdleGTLengthGuideEN.imageset/Contents.json`
  - Register the English PNG as an original-rendering image asset.
- Copy asset: `/Users/lgh/Downloads/ChatGPT Image 2026年4月30日 23_30_41.png` to `Running/Assets.xcassets/MiniHurdleGTLengthGuideEN.imageset/MiniHurdleGTLengthGuideEN.png`
  - Preserve the provided 941x1672 dimensions.
- Optional Test: Add focused coverage only if a small pure helper is introduced outside the view. Do not widen scope.

## Task 1: Add English GT Guide Asset

**Files:**
- Create: `Running/Assets.xcassets/MiniHurdleGTLengthGuideEN.imageset/Contents.json`
- Copy: `Running/Assets.xcassets/MiniHurdleGTLengthGuideEN.imageset/MiniHurdleGTLengthGuideEN.png`

- [ ] **Step 1: Create the imageset directory**

Run:
```bash
mkdir -p Running/Assets.xcassets/MiniHurdleGTLengthGuideEN.imageset
```

- [ ] **Step 2: Copy the provided English image**

Run:
```bash
cp "/Users/lgh/Downloads/ChatGPT Image 2026年4月30日 23_30_41.png" Running/Assets.xcassets/MiniHurdleGTLengthGuideEN.imageset/MiniHurdleGTLengthGuideEN.png
```

- [ ] **Step 3: Write the asset catalog contents**

Create `Contents.json`:
```json
{
  "images" : [
    {
      "filename" : "MiniHurdleGTLengthGuideEN.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "original"
  }
}
```

- [ ] **Step 4: Verify dimensions**

Run:
```bash
sips -g pixelWidth -g pixelHeight Running/Assets.xcassets/MiniHurdleGTLengthGuideEN.imageset/MiniHurdleGTLengthGuideEN.png
```

Expected: `pixelWidth: 941`, `pixelHeight: 1672`.

## Task 2: Select GT Guide Asset by Active Language

**Files:**
- Modify: `Running/Views/MiniHurdle/MiniHurdleSpacingView.swift`

- [ ] **Step 1: Add a localized image asset resolver**

Near the view-private helpers, add a computed property similar to:
```swift
private var measurementGuideAssetName: String {
    LocalizationPreferenceResolver.resolveBundleLanguage(for: localization.currentLanguage) == "en"
        ? "MiniHurdleGTLengthGuideEN"
        : "MiniHurdleGTLengthGuide"
}
```

This intentionally resolves `system` the same way localized strings do.

- [ ] **Step 2: Pass the asset name into the illustration**

Change the measurement guide usage from:
```swift
MiniHurdleIllustration(accent: DS.Colors.miniHurdle)
```

to:
```swift
MiniHurdleIllustration(
    assetName: measurementGuideAssetName,
    accent: DS.Colors.miniHurdle
)
```

- [ ] **Step 3: Thread the asset name through the image component**

Update `MiniHurdleIllustration` and `MiniGTMeasurementDiagram` to accept `assetName: String`, and replace:
```swift
Image("MiniHurdleGTLengthGuide")
```

with:
```swift
Image(assetName)
```

Keep existing accessibility identifiers and labels unchanged so tests and VoiceOver remain stable.

- [ ] **Step 4: Check for compiler issues**

Run:
```bash
xcodebuild test -scheme Running -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RunningTests/LocalizationPreferenceResolverTests
```

If that simulator is unavailable, list available destinations and use the closest installed iPhone simulator.

## Task 3: Verify Mini Hurdle Module Still Builds

**Files:**
- No additional files expected.

- [ ] **Step 1: Run focused tests**

Run:
```bash
xcodebuild test -scheme Running -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RunningTests/MiniHurdleSpacingTests -only-testing:RunningTests/LocalizationPreferenceResolverTests
```

- [ ] **Step 2: Inspect final diff**

Run:
```bash
git diff -- Running/Views/MiniHurdle/MiniHurdleSpacingView.swift Running/Assets.xcassets/MiniHurdleGTLengthGuideEN.imageset
```

Expected: Only the new English image asset and a localized asset-name selection change.
