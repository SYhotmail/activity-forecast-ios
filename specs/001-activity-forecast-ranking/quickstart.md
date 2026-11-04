# Quickstart & Validation: Activity Forecast Ranking

## Prerequisites
- macOS with Xcode 16 or later (Swift 6). Developed on Xcode 27.2.
- An iOS 18+ simulator. Internet access for the live run (tests need none).
- Nothing else to install: the project is a native `.xcodeproj` with no third-party dependencies.

## Run the app
```bash
open ActivityForecast.xcodeproj        # pick the ActivityForecast scheme and an iPhone simulator, then ⌘R
# or from the command line:
xcodebuild -project ActivityForecast.xcodeproj -scheme ActivityForecast \
  -destination 'generic/platform=iOS Simulator' build
```

## Run the tests (no simulator needed)
```bash
swift test --package-path Packages/ForecastKit
```
Expected: all suites pass. These include:
- **Scoring**: every factor ramp at its thresholds, the caps, and the indoor floor at 30 and ceiling at 90.
- **Ranking**: the four reference weeks from SC-003 give Skiing, Indoor, Outdoor, and Surfing above Skiing. Also tie-breaks, best day, and that "No data" days are left out of the average.
- **Client decoding**: recorded fixtures for Paris search, a no-results search, the Chamonix forecast, and a forecast with nulls.
- **Models**: loading → loaded/empty/failed, retry, and that a stale search result is never applied.

TDD loop during development: `swift test --package-path Packages/ForecastKit --filter <SuiteName>` for one suite, then run the full suite before every commit.

## Manual end-to-end checks (simulator)

| # | Steps | Expected | Covers |
|---|---|---|---|
| 1 | Launch the app | Search screen with the "Type at least 2 letters" hint | FR-001 |
| 2 | Type `Paris` | Results include "Île-de-France Region, France" and "Texas, United States" | FR-002, US3 |
| 3 | Tap the Paris, France result | Within ~3 s: 4 ranked activity sections, 7 day cells each, one ★ per activity | FR-003…007, SC-001/002 |
| 4 | Tap any day cell | Sheet with score, label, reason(s), all weather factors in metric units | FR-008, FR-016 |
| 5 | Look at Surfing | Weather-only footnote is visible | FR-010 |
| 6 | Search `zzqxw` | "No places found" | FR-011 |
| 7 | Quickly type `Lon` → `London` | Only London results remain | FR-012 |
| 8 | Turn on Network Link Conditioner "100% Loss" (or airplane mode on a device), then search or load a forecast | Offline message + Retry. Turn the network back on, tap Retry, and it loads | FR-011, SC-004 |
| 9 | Settings → Accessibility → Larger Text at max, reopen Forecast | No truncated text. VoiceOver reads "Skiing, Tuesday 4 November, Good, 61" | FR-015, SC-006 |
| 10 | Search `Zürich` and `東京` | `Zürich` lists Zurich, Switzerland. `東京` shows "No places found": Open-Meteo geocoding returns no results for non-Latin queries (checked live 2026-11-04), so search `Tokyo` instead | Edge cases |
