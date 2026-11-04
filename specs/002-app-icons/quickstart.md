# Quickstart & Validation: App Icons

## Prerequisites
As in [001 quickstart](../001-activity-forecast-ranking/quickstart.md): macOS, Xcode 16+, an iOS 18+ simulator.

## Regenerate the icon (only when the artwork changes)
```bash
swift scripts/make-app-icon.swift      # writes the 3 PNGs into App/Resources/Assets.xcassets/AppIcon.appiconset/
```

## Build and test
```bash
swift test --package-path Packages/ForecastKit           # expected: unchanged, all 92 tests pass
xcodebuild -project ActivityForecast.xcodeproj -scheme ActivityForecast \
  -destination 'generic/platform=iOS Simulator' build    # expected: BUILD SUCCEEDED, no asset catalog warnings
```

## Manual checks (simulator)

| # | Steps | Expected | Covers |
|---|---|---|---|
| 1 | Install and go to the Home Screen | Custom icon (sun, snowy peak, wave), not the blank placeholder | FR-001, SC-001 |
| 2 | `xcrun simctl ui booted appearance dark`, view Home Screen | Dark variant, motif legible | FR-002, SC-002 |
| 3 | Home Screen → long-press → Edit → Customize → Tinted | Single-tone motif still recognisable | FR-002, SC-002 |
| 4 | Swipe down for Spotlight, type "Activity"; open Settings → apps list | Icon visible and recognisable at small size | FR-003, SC-001 |
| 5 | Open any forecast | Each section header has its own icon (skier, surfer, hiker, columns) | FR-005, SC-003 |
| 6 | Tap a day cell | Sheet title shows the same activity icon | FR-005 |
| 7 | VoiceOver on: focus a section header and a day cell | Spoken text identical to before (e.g. "Skiing, Tuesday 4 November, Good, 61") | FR-006, SC-004 |
| 8 | Larger Text at max, reopen forecast | Icons scale with text, no truncation or overlap | FR-007, SC-005 |
| 9 | Toggle Light/Dark app appearance | Activity icons keep contrast in both | FR-007 |
