# Quickstart: Validating the MVVM Refactor

## Prerequisites
- Xcode 27+, an iPhone 16 simulator, SwiftLint.
- Baseline: `specs/005-mvvm-refactor/baseline-vm-tests.txt`, recorded before Phase A (tasks T001).

## Automated checks (constitution Quality Gates)
1. `swiftlint lint --strict` → 0 violations.
2. `swift test --package-path Packages/ForecastKit` → all pass (package untouched).
3. `xcodebuild test -project ActivityForecast.xcodeproj -scheme ActivityForecast -destination 'platform=iOS Simulator,name=iPhone 16'` → all pass.
4. Clean simulator build, with 0 warnings from project code.

## Test-set proof (FR-010, SC-001, SC-002)
- After Phase A: list the app test functions, apply `s/ModelTests/ViewModelTests/` to the baseline, and diff. The two lists must be identical (same names, same count).
- After Phases B and C: the diff shows only additions (3 selection tests, 3 presentation tests) and the removal of `selectedDayRoundTrip`.
- `git log` shows `test: … (Txxx, red)` before `feat: … (Txxx, green)` for each.

## Structure checks (FR-001…FR-003, FR-005, FR-007, SC-003)
- `ls App/Features/*/ App/Views/LoadStateView/ App/Shared/` matches plan.md › Project Structure.
- `grep -rn "Binding(get" App/` → no matches.
- `grep -rnw -e DaySelection -e SearchModel -e ForecastModel -e BrowseModel -e RootView App AppTests | grep -v 'specs/'` → no matches (comments citing earlier specs by old name are allowed).

## Release binary (FR-009, SC-004)
Build Release for the simulator, then run `nm` on the app binary and grep for `StubWeatherService|PreviewData` → 0 symbols.

## Manual layout checks (SC-005)
Re-run the selection, sheet and Back items of `specs/003-universal-adaptive-layout/quickstart.md`:
- iPhone: search → tap place → forecast → tap day → sheet → Done → tap another day → sheet opens → Back.
- iPhone Duo inner ↔ outer: with a day sheet open, fold and unfold. The sheet, the selection and the loaded week stay, and there is no refetch.
- iPad, full screen and Split View: selecting a row updates the detail column. Re-selecting the same row does not reload. The sheet zooms from its cell.
- iPhone 18 Pro (FR-012, SC-006): open a city and let it load, then search `minsk` and open it. The forecast loads, with no endless spinner. Then go Back while a forecast is loading, and open another city: it loads.
