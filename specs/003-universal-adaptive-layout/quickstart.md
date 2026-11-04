# Quickstart & Validation: Universal App with Adaptive Layouts

## Prerequisites
- Xcode 27.2+ (Swift 6.4 toolchain), SwiftLint (`brew install swiftlint`).
- Simulators: iPhone 16, **iPhone Duo**, iPad Pro 11-inch (M5) (or any iPad running iPadOS 18+).

## Gates (constitution Quality Gates, before the PR)
```bash
swiftlint lint --strict                                  # expected: 0 violations
swift test --package-path Packages/ForecastKit           # expected: all pass (92 existing + new BrowseModel/ForecastModel cases)
xcodebuild -project ActivityForecast.xcodeproj -scheme ActivityForecast \
  -destination 'generic/platform=iOS Simulator' build    # expected: BUILD SUCCEEDED, no project warnings
```

## Manual matrix
Behaviour per [contracts/ui.md](./contracts/ui.md); state rules per [data-model.md](./data-model.md).

| # | Device / window | Steps | Expected | Covers |
|---|---|---|---|---|
| 1 | iPhone 16 | Search Paris → place → day | Narrow flow exactly as before | FR-005, SC-005 |
| 2 | iPhone Duo, outer display | Same as #1 | Narrow flow | FR-004, FR-005 |
| 3 | iPhone Duo, inner display | Search Paris → pick Paris, France → pick Paris, Texas | Two columns; forecast replaced in place, results stay | FR-006, SC-004 |
| 4 | iPhone Duo | With search results, a forecast and a day sheet open, fold and unfold 10× | Same results, place, forecast and sheet every time, no spinner and no new request | FR-007, SC-003 |
| 5 | iPad, portrait and landscape | Launch, rotate with a forecast open | Native full screen, two columns, no reload on rotate | FR-001, FR-002 |
| 6 | iPad, no selection | Launch, look at the right column | "Pick a place" placeholder | FR-006 |
| 7 | iPad Split View ⅓, ½, ⅔ and Slide Over | Run #1/#3 in each | ⅓ and Slide Over narrow; ½ and ⅔ per width class; no truncation | FR-003, SC-001, SC-002 |
| 8 | iPad Stage Manager | Drag the window through 3 sizes with a sheet open | Layout switches by width; state kept | FR-003, FR-007 |
| 9 | iPad + keyboard and pointer | Focus search, arrow through results, Return, Esc on sheet | All reachable without touch | FR-008 |
| 10 | Any, Larger Text at max | Repeat #1 and #3 | No truncation or overlap; on wide windows the sidebar may collapse behind its toggle | FR-009, SC-002 |
| 11 | Any, VoiceOver | Focus a result, a section header, a day cell | Wording identical to feature 001/002 | FR-009, SC-005 |
| 12 | Wide window | Load a place offline → Retry online; search `zzqxw` | Error + Retry and "No places found" render in the columns | FR-010 |
| 13 | iPhone vs iPad vs Duo | Compare Paris scores | Identical numbers and best days | FR-011, SC-006 |
