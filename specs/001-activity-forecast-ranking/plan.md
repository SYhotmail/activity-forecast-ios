# Implementation Plan: Activity Forecast Ranking

**Branch**: `001-activity-forecast-ranking` | **Date**: 2026-11-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-activity-forecast-ranking/spec.md`

## Summary

A native iOS app: the user searches for a city or town, picks it, and sees Skiing, Surfing, Outdoor sightseeing and Indoor sightseeing ranked for the next 7 days. Each activity has a 0–100 rating per day, a best day, and a plain-language reason for every rating.

The app has a thin SwiftUI layer over one local Swift package, `ForecastKit`, which holds:
- the Open-Meteo client (Geocoding + Forecast, `URLSession`, no third-party dependencies),
- a deterministic weighted-factor scoring engine,
- two `@Observable` screen models.

Development is **test-driven** (red → green → refactor). All logic is driven by Swift Testing tests run via `swift test`. The scoring weights were checked against reference weeks; see [research.md](./research.md) R9.

## Technical Context

**Language/Version**: Swift 6 (language mode 6, strict concurrency). Built with Xcode 16 or later; developed on Xcode 27.2 / Swift 6.4.

**Primary Dependencies**: SwiftUI, Observation, Foundation (`URLSession`, `Codable`). No third-party packages.

**Storage**: none. In-memory only for the session (FR-014).

**Testing**: TDD with Swift Testing in the `ForecastKit` package tests, using `URLProtocol` stubs and recorded JSON fixtures. Views are checked with SwiftUI previews and manual simulator checks per [quickstart.md](./quickstart.md). See [Development workflow](#development-workflow-tdd).

**Target Platform**: iOS 18.0+ (iPhone; iPad runs in compatibility layout).

**Project Type**: mobile app (iOS), no backend.

**Performance Goals**: ranked results within 3 s of selecting a place (SC-002). One forecast request per selection. Scoring is O(7 × 4) and effectively instant.

**Constraints**: Open-Meteo Geocoding + Forecast only. No API key. Online-only. Metric units. English.

**Scale/Scope**: 3 screens, about 15 source files, a single user.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the **unfilled template**, so there are no ratified principles to gate on. In its place, the plan applies the brief's stated values and the project's simplicity defaults:

| Gate | Status |
|---|---|
| Focused scope (brief: "not looking for feature volume") — nothing beyond the spec's FRs | ✅ No favourites, cache, settings or user-tunable weights |
| No speculative abstractions or dependencies | ✅ Zero third-party packages. One protocol (`WeatherService`) with two real implementations (live and test stub). One package |
| Verification over trust (brief: "poor verification is not [allowed]") | ✅ API shapes verified live. Scoring checked against the SC-003 weeks (the first draft failed and was corrected). Reference weeks become tests |
| Reasoning is visible (brief: "How you worked") | ✅ intent.md → spec.md → research.md decisions log. README will summarise assumptions |
| Test-driven development (clarified 2026-11-03) | ✅ Every `ForecastKit` behaviour starts as a failing test. Tasks are ordered test → implementation. See Development workflow |
| Native Xcode project, no generator (clarified 2026-11-03) | ✅ `ActivityForecast.xcodeproj` maintained in Xcode. Nothing to install |
| Trust boundary: decode defensively | ✅ All API values are optional. Missing data → "No data", never a fake score |

**Post-design re-check (after Phase 1)**: still passes. The design adds no further dependencies or layers. Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-activity-forecast-ranking/
├── plan.md              # This file
├── research.md          # Phase 0: decisions, scoring model, verification notes
├── data-model.md        # Phase 1: entities, states
├── quickstart.md        # Phase 1: run, test, manual validation
├── contracts/
│   ├── open-meteo.md    # consumed API contract (verified live)
│   └── ui.md            # screens and states exposed to the user
└── tasks.md             # Phase 2 (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
ActivityForecast.xcodeproj/         # native Xcode project (source of truth), file-system synchronised groups
App/                                # iOS app target: views only
├── ActivityForecastApp.swift       # composition root: builds OpenMeteoClient, injects models
├── Search/SearchView.swift
├── Forecast/ForecastView.swift
├── Forecast/ActivitySection.swift
├── Forecast/DayCell.swift
├── Forecast/DayDetailView.swift
├── Shared/LoadStateView.swift      # loading / empty / error + Retry, reused by both screens
└── Resources/Assets.xcassets
Packages/ForecastKit/
├── Package.swift                   # platforms: iOS 18, macOS 15; swift-tools 6.0
├── Sources/ForecastKit/
│   ├── Models/                     # Place, DailyWeather, Activity, SuitabilityLabel, Reason,
│   │                               # DaySuitability, ActivityRanking, WeeklyRanking
│   ├── Scoring/
│   │   ├── Ramp.swift              # piecewise-linear normalisation helper
│   │   ├── ActivityScorer.swift    # per-activity factors, weights, caps, reasons
│   │   └── WeeklyRanker.swift      # weekly mean, best day, ordering, tie-breaks
│   ├── Service/
│   │   ├── WeatherService.swift    # protocol
│   │   ├── OpenMeteoClient.swift   # URLs, requests, error mapping
│   │   └── OpenMeteoDTOs.swift     # Codable response types and mapping to models
│   └── Features/
│       ├── LoadState.swift
│       ├── SearchModel.swift       # @MainActor @Observable
│       └── ForecastModel.swift     # @MainActor @Observable
└── Tests/ForecastKitTests/
    ├── ActivityScorerTests.swift
    ├── WeeklyRankerTests.swift     # SC-003 reference weeks
    ├── OpenMeteoClientTests.swift  # URLProtocol stub + fixtures
    ├── SearchModelTests.swift
    ├── ForecastModelTests.swift
    ├── Support/StubWeatherService.swift, StubURLProtocol.swift
    └── Fixtures/geocoding-paris.json, geocoding-empty.json,
                 forecast-chamonix.json, forecast-nulls.json
README.md                           # what, how to run, assumptions, trade-offs
```

**Structure Decision**: an iOS app target plus one local Swift package (see research.md R2/R3). The project file is a native `.xcodeproj` created in Xcode. The app target holds only SwiftUI views and the composition root. Everything with logic lives in `ForecastKit`, so it is testable without a simulator. Dependencies point one way: `App → ForecastKit → Foundation`.

## Architecture

**Pattern: layered MVVM** (decided in spec Clarifications 2026-11-03; alternatives in [research.md](./research.md) R13).

```text
View (App target, SwiftUI)          renders state, forwards user actions; no logic, no networking
  │ observes / calls intents
ViewModel (ForecastKit/Features)    @MainActor @Observable SearchModel, ForecastModel
  │                                 own LoadState, debounce/cancellation, retry, error mapping to UI
  ├──▶ Domain (ForecastKit/Models + Scoring)   pure, synchronous, deterministic value types:
  │                                            ActivityScorer, WeeklyRanker, Place, DailyWeather…
  └──▶ Data (ForecastKit/Service)              WeatherService protocol ← OpenMeteoClient (URLSession, DTO → Domain mapping)
```

Rules:
- Dependencies point downward only. Domain imports nothing but Foundation and knows nothing about the network or the UI. DTOs never leave the Data layer.
- View models get a `WeatherService` through their initialiser. `ActivityForecastApp` is the single composition root and creates the live `OpenMeteoClient`. Tests and SwiftUI previews pass `StubWeatherService`.
- Each screen has one view model. There is no app-wide store or coordinator: navigation is a value-based `NavigationStack` driven by the selected `Place`.
- Test mapping: Domain → pure unit tests (scoring, ranking). Data → `URLProtocol` + fixtures. ViewModel → state-transition tests with the stub service. View → previews + manual quickstart checks.

## Development workflow (TDD)

Clarified 2026-11-03: test-driven development applies to all of `ForecastKit`.

1. **Red**: write one Swift Testing test for the next behaviour (an acceptance scenario, edge case or scoring threshold from the spec). Run `swift test --package-path Packages/ForecastKit` and confirm it fails *for the expected reason* (an assertion, not a typo).
2. **Green**: write the least production code that makes it pass. Run the full suite.
3. **Refactor**: clean up with the suite green. Then repeat.

Order of work (inside-out, following the layers):
1. Domain: `Ramp`, then `SuitabilityLabel`, then `ActivityScorer` (one activity at a time, thresholds then caps then reasons), then `WeeklyRanker` (the SC-003 reference weeks are written as tests **first**; weights are only tuned until they pass).
2. Data: `OpenMeteoClient` against the recorded fixtures (search, no results, forecast, nulls, error statuses) before any request-building code.
3. ViewModel: `SearchModel` and `ForecastModel` state transitions, retry and stale-result cancellation against `StubWeatherService`.
4. Views last. They have no logic, so no unit tests: SwiftUI previews for every `LoadState`, plus the manual checks in quickstart.md.

Evidence for reviewers ("how you worked"): commit pairs `test: …` (red) → `feat: …` (green), with `refactor: …` where useful. `tasks.md` lists each test task before its implementation task.

Exempt from test-first: SwiftUI view bodies, the composition root, and the Xcode project setup. These are verified by building and by quickstart.md.

## Key flows

1. **Search**: `SearchView` binds `.searchable` to `SearchModel.query`. Then `.task(id: query)` runs a 300 ms debounce, calls `model.search()`, and moves the state through `idle/loading/loaded/empty/failed`. A superseded task is cancelled by SwiftUI and its result is discarded (FR-012).
2. **Forecast**: tapping a place pushes `ForecastView(model: ForecastModel(place:service:))`. `.task { await model.load() }` fetches daily data plus hourly snow depth, maps it to `[DailyWeather]`, runs `WeeklyRanker.rank(...)` and publishes `.loaded(WeeklyRanking)`. `retry()` re-runs `load()`.
3. **Detail**: tapping a day cell presents `DayDetailView(day: DaySuitability)`. It is pure rendering of the reasons and weather already computed.

## Complexity Tracking

No violations. Nothing to justify.
