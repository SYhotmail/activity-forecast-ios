---
description: "Task list for Activity Forecast Ranking"
---

# Tasks: Activity Forecast Ranking

**Input**: Design documents from `/specs/001-activity-forecast-ranking/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: REQUIRED. TDD was clarified on 2026-11-03: every test task is written first and must **fail** before its paired implementation task starts. Run with `swift test --package-path Packages/ForecastKit`.

**Delivery**: each phase (or sub-phase) is one GitHub issue and one pull request. PRs are stacked in the order below.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on unfinished tasks)
- **[Story]**: US1 / US2 / US3 from spec.md
- Paths are relative to the repository root (see plan.md › Project Structure)

---

## Phase 1: Setup (PR 1)

- [ ] T001 Create `.gitignore` (Xcode/Swift: `DerivedData/`, `.build/`, `.swiftpm/`, `xcuserdata/`, `*.xcuserstate`, `.DS_Store`)
- [ ] T002 Create the Swift package `Packages/ForecastKit/Package.swift` (swift-tools 6.0, Swift 6 language mode, platforms iOS 18 / macOS 15, library `ForecastKit`, test target `ForecastKitTests`)
- [ ] T003 Create the native Xcode project `ActivityForecast.xcodeproj`: iOS 18 app target `ActivityForecast` with the `App/` synchronised group, a local package reference to `Packages/ForecastKit`, and a shared scheme
- [ ] T004 Add `App/ActivityForecastApp.swift` (placeholder root view) and `App/Resources/Assets.xcassets`. Verify `xcodebuild … build` succeeds for the simulator

## Phase 2: Foundational (PR 1)

**⚠️ Blocks all user stories**

- [ ] T005 [P] Write `Tests/ForecastKitTests/ModelsTests.swift` (failing): `Place.displayName` combinations (FR-002), `SuitabilityLabel(score:)` band edges 0/24/25/49/50/74/75/100 (FR-005)
- [ ] T006 Implement the domain models in `Sources/ForecastKit/Models/` (Place, DailyWeather, Activity, SuitabilityLabel, Reason, DaySuitability, ActivityRanking, WeeklyRanking) per data-model.md, so that T005 passes
- [ ] T007 [P] Add `Sources/ForecastKit/Features/LoadState.swift`, `UserFacingError`, and the `Sources/ForecastKit/Service/WeatherService.swift` protocol
- [ ] T008 [P] Add `Tests/ForecastKitTests/Support/StubWeatherService.swift` (scripted results and errors, call recording, optional delay)

**Checkpoint**: the package builds, T005 is green, and the app builds.

---

## Phase 3: User Story 1 — Search a place and see the week ranked (P1) 🎯 MVP

### 3a. Domain: scoring & ranking (PR 2)

- [ ] T009 [P] [US1] Write `ScoringTests/RampTests.swift` (failing): piecewise-linear ramp at and between breakpoints, clamping
- [ ] T010 [US1] Implement `Sources/ForecastKit/Scoring/Ramp.swift`
- [ ] T011 [US1] Write `ActivityScorerTests.swift` (failing), parameterised per activity: factor thresholds, weights, caps (skiing no-snow-above-freezing ≤10; surfing thunderstorm ≤10; outdoor thunderstorm/snow ≤20), indoor 30…90 band, missing factor → `.noData`, determinism (FR-004, FR-009, FR-010, FR-013)
- [ ] T012 [US1] Implement `Sources/ForecastKit/Scoring/ActivityScorer.swift` per research.md R9, so that T011 passes
- [ ] T013 [US1] Write `WeeklyRankerTests.swift` (failing): the **SC-003 reference weeks** (snowy alpine → Skiing; rainy city → Indoor; sunny 20 °C → Outdoor; mild breezy coast → Surfing above Skiing), weekly mean excluding No data, tie-breaks, best day earliest-if-tied and only if ≥25 (FR-006, FR-007, FR-013)
- [ ] T014 [US1] Implement `Sources/ForecastKit/Scoring/WeeklyRanker.swift`. Tune weights only until T013 passes, and record any weight change in research.md R9

### 3b. Data: Open-Meteo client (PR 3; can run in parallel with 3a)

- [ ] T015 [P] [US1] Record fixtures in `Tests/ForecastKitTests/Fixtures/`: `geocoding-paris.json`, `geocoding-empty.json`, `forecast-chamonix.json`, `forecast-nulls.json` (per contracts/open-meteo.md)
- [ ] T016 [US1] Write `OpenMeteoClientTests.swift` with `Support/StubURLProtocol.swift` (failing): request URLs and query items, decoding search results, absent `results` → `[]`, forecast to `[DailyWeather]` (unit conversions: snow depth m→cm daily max, sunshine s→h), nulls → nil, HTTP error → `.serviceUnavailable`, offline → `.offline`, cancellation is not an error
- [ ] T017 [US1] Implement `Sources/ForecastKit/Service/OpenMeteoDTOs.swift` and `OpenMeteoClient.swift`, so that T016 passes

### 3c. Presentation (PR 4, depends on 3a + 3b)

- [ ] T018 [US1] Write `SearchModelTests.swift` (failing): query < 2 chars → idle, ≥ 2 → loading → loaded, results carry displayName
- [ ] T019 [US1] Implement `Sources/ForecastKit/Features/SearchModel.swift` (`@MainActor @Observable`)
- [ ] T020 [US1] Write `ForecastModelTests.swift` (failing): load → `.loaded(WeeklyRanking)` ranked per WeeklyRanker
- [ ] T021 [US1] Implement `Sources/ForecastKit/Features/ForecastModel.swift`
- [ ] T022 [P] [US1] Build `App/Shared/LoadStateView.swift`
- [ ] T023 [US1] Build `App/Search/SearchView.swift` (`.searchable`, `.task(id:)` 300 ms debounce, navigation to Forecast)
- [ ] T024 [US1] Build `App/Forecast/ForecastView.swift`, `ActivitySection.swift`, `DayCell.swift` (rank order, 7 cells, ★ best day / "No suitable day this week"). Wire the composition root in `ActivityForecastApp.swift`. Add previews with the stub service

**Checkpoint**: quickstart manual checks 1–3 pass.

---

## Phase 4: User Story 2 — Understand why a day scored as it did (P2) (PR 5)

- [ ] T025 [US2] Write tests in `ActivityScorerTests.swift` (failing): reasons. A cap reason comes first; the biggest negative contributor appears when its factor is < 0.4, the biggest positive when ≥ 0.8; at most 2 reasons; heavy rain mentions rain (US2 scenario 2)
- [ ] T026 [US2] Implement reason generation in `ActivityScorer.swift`, so that T025 passes
- [ ] T027 [US2] Build `App/Forecast/DayDetailView.swift` (sheet: label, score, reasons, all weather factors in metric with "—" for missing) and the surfing weather-only footnote in `ActivitySection.swift` (FR-008, FR-010, FR-016)

## Phase 5: User Story 3 — Find the right place and recover (P3) (PR 5)

- [ ] T028 [US3] Write tests in `SearchModelTests.swift` / `ForecastModelTests.swift` (failing): empty results → `.empty`; offline → `.failed(.offline)`; `retry()` recovers; a stale (superseded) search result is never applied (FR-011, FR-012)
- [ ] T029 [US3] Implement the empty, error, retry and cancellation handling in `SearchModel.swift` / `ForecastModel.swift`
- [ ] T030 [US3] Wire the empty, error and Retry UI in `SearchView.swift` / `ForecastView.swift` via `LoadStateView`. Add accessibility labels to the day cells (FR-015)

---

## Phase 6: Polish (PR 6)

- [ ] T031 [P] Write `README.md`: what was built, how to run and test, architecture, scoring model, assumptions and limitations (surfing has no wave data, model elevation), trade-offs, how AI was used and verified
- [ ] T032 Run the full test suite and the `xcodebuild` simulator build. Walk through quickstart.md checks 1–10 and record the results in the PR
- [ ] T033 Final pass: remove dead code and check that no file outside the plan's structure was added

---

## Dependencies & Execution Order

- Phase 1 → Phase 2 → {3a ∥ 3b} → 3c → Phase 4 → Phase 5 → Phase 6
- Within each block: the test task comes before its implementation task (TDD). Tasks marked [P] touch different files.
- PR stack: PR1 (Setup + Foundational) ← PR2 (3a) ← PR3 (3b, rebased onto PR2) ← PR4 (3c) ← PR5 (US2 + US3) ← PR6 (Polish)

## Parallel opportunities

- 3a (scoring) and 3b (client) touch disjoint files and are developed concurrently.
- T005, T007 and T008 can run in parallel.
