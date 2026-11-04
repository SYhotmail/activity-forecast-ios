# Quickstart & Validation: View Models Live in the App

## Gates (constitution v2.0.0, before the PR)
```bash
swiftlint lint --strict                                         # 1. 0 violations
swift test --package-path Packages/ForecastKit                  # 2. domain/scoring/data tests pass (no simulator)
xcodebuild test -project ActivityForecast.xcodeproj -scheme ActivityForecast \
  -destination 'platform=iOS Simulator,name=iPhone 16'          # 3. ForecastKitTests (69) + ActivityForecastTests (39) pass
xcodebuild -project ActivityForecast.xcodeproj -scheme ActivityForecast \
  -destination 'generic/platform=iOS Simulator' build           # 4. clean build, no project warnings
```

## Feature checks
| # | Check | Expected | Covers |
|---|---|---|---|
| 5 | Build Release (`-configuration Release`), then `nm <App>.app/ActivityForecast \| grep -cE 'StubWeatherService\|4Gate\|8Recorder\|PreviewData'`; `ls <App>.app/Frameworks` | 0 matches; no Frameworks folder | FR-004, SC-001 |
| 6 | Compare test-function names of the Search/Forecast/BrowseModel suites before (package) and after (`ActivityForecastTests`) | Identical set of 39 names; expectations unchanged in diff (imports only) | FR-006, SC-002 |
| 7 | `grep -rn "public" App/Features App/Shared/StubWeatherService.swift`; `grep -rn "SearchModel\|ForecastModel\|BrowseModel\|LoadState\|StubWeatherService" Packages/ForecastKit/Sources` | No matches | FR-001, FR-002, SC-001 |
| 8 | Total tests (package + app) | ≥ 108, all pass | SC-003 |
| 9 | SwiftUI previews (Search, Forecast, Root, DayDetail) | Render in Xcode canvas | FR-005 |
| 10 | Smoke run: 001 quickstart #1–#6 and 003 quickstart #1–#4 on iPhone 16, iPhone Duo, iPad | Unchanged behaviour | FR-008, SC-004 |
