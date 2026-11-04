# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

iOS take-home (SwiftUI, Swift 6, iOS 18+): search a place, see 0–100 suitability scores for skiing, surfing, outdoor and indoor sightseeing over the next 7 days, using Open-Meteo Geocoding + Forecast APIs directly (no backend, no API key, no third-party dependencies).

## Commands

```bash
# All logic tests (Swift Testing, runs on macOS, no simulator, ~0.02 s)
swift test --package-path Packages/ForecastKit

# One suite or test (filter is a regex over "Target.Suite/test")
swift test --package-path Packages/ForecastKit --filter WeeklyRankerTests
swift test --package-path Packages/ForecastKit --filter "ActivityScorerTests/<testName>"

# App view-model tests (hosted ActivityForecastTests) plus the package tests, on a simulator
xcodebuild test -project ActivityForecast.xcodeproj -scheme ActivityForecast \
  -destination 'platform=iOS Simulator,name=iPhone 16'
# One app suite
xcodebuild test -project ActivityForecast.xcodeproj -scheme ActivityForecast \
  -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ActivityForecastTests/SearchModelTests

# Lint (PR gate: zero violations; config in .swiftlint.yml)
swiftlint lint --strict

# Build the app
xcodebuild -project ActivityForecast.xcodeproj -scheme ActivityForecast \
  -destination 'generic/platform=iOS Simulator' build
```

Before any PR, `swiftlint lint --strict`, `swift test`, `xcodebuild test` and a clean simulator build must all pass (`.specify/memory/constitution.md` › Quality Gates). There is no UI test target; screens are covered by SwiftUI previews (`App/Shared/PreviewData.swift`) and the manual checklists in `specs/001-activity-forecast-ranking/quickstart.md` and `specs/003-universal-adaptive-layout/quickstart.md` (iPhone, iPhone Duo, iPad window sizes).

## Architecture

Layered MVVM, one-way dependencies `App → ForecastKit → Foundation`. `App/` holds the SwiftUI views and their view models (`App/Features/`). The local package `Packages/ForecastKit` (one product) holds only domain, scoring and data, tested with `swift test`. View models are tested in the hosted `ActivityForecastTests` target (`AppTests/`), which links no package products: `ForecastKit` resolves from the host app, so there is one copy at runtime.

- **Layout**: `App/RootView.swift` is a `NavigationSplitView` (search sidebar, forecast detail) pinned to `.balanced`/all columns. Compact width collapses it into the push flow, so the layout depends on width class only. `BrowseModel` holds the search, selected place, forecast and open day (`ForecastModel.selectedDay`); views call `loadIfNeeded()` / idempotent `search()` because a fold or resize can rebuild them.
- **`App/Features/`** (internal): `SearchModel`, `ForecastModel`, `BrowseModel` are `@Observable` (main-actor isolated by the app target's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; value fixtures and the stub service opt out with `nonisolated`) and expose a single `LoadState<Value>` (idle / loading / loaded / empty / failed). Failures are surfaced only as `UserFacingError` (offline / serviceUnavailable / unexpected) with retry. Search is debounced (300 ms, driven from the view via `.task(id:)`); superseded requests are cancelled and stale results must never overwrite newer ones — this is tested.
- **`Scoring/`**: `ActivityScorer` (per-day score + plain-language reason) and `WeeklyRanker` (weekly mean over days with data, ranking, best-day star) are pure and deterministic. Factors are normalised with piecewise-linear ramps (`Ramp`) plus hard caps. The authoritative weight table is `research.md` R9; `WeeklyRankerTests` pins four reference weeks (snowy alpine, rainy city, sunny coast, hot/dry) — changing weights must keep those passing. Indoor = `30 + 0.6 × (100 − outdoor)`; best day is starred only at ≥ 25 (Fair); "No data" days are excluded, never counted as 0.
- **`Service/`**: `WeatherService` protocol is the data boundary; `OpenMeteoClient` (URLSession + Codable DTOs in `OpenMeteoDTOs.swift`) is the live impl (it throws `UserFacingError`, also in `Service/`); the fake for previews and tests is the app's internal `StubWeatherService`. `ActivityForecastApp` is the composition root and the only place that chooses the live service.
- **`Models/`**: `LocalDate` keeps forecast days as calendar components in the *place's* time zone, so the device time zone never shifts a day. "7 days" = today + 6 in that zone.

Open-Meteo quirks already encoded in the client (verified live): a geocoding search with no matches omits `results`; snow depth is hourly-only and in metres. Fixtures in `Tests/ForecastKitTests/Fixtures/` are recorded live responses.

Test support: `StubURLProtocol` (package tests) holds a process-wide handler, so any suite using it must be `@Suite(..., .serialized)`. `StubWeatherService` lives in `App/Shared/` as an `internal` type shared by previews and app tests (`@testable import ActivityForecast`); it must never be public or used by production code. In app tests, `AppTests/Support/Gate` scripts when an async stub returns, and `Recorder` captures the arguments stubs received. Previews need no `#if DEBUG`: their `internal` fixtures are removed from Release by whole-module optimisation. After touching previews or fixtures, check the Release binary with `nm` (no `StubWeatherService`/`PreviewData` symbols).

## Workflow conventions

- Spec-driven ([Spec Kit](https://github.com/github/spec-kit), `.specify/`, `speckit-*` skills). Each feature has `specs/<NNN-feature>/` (001 activity ranking, 002 app icons, 003 universal adaptive layout): `spec.md` (FR-xxx requirements, clarifications), `plan.md`, `research.md` (decisions), `data-model.md`, `contracts/`, `tasks.md` (Txxx). IDs restart per feature; code comments cite them (e.g. `specs/003 FR-007`), so keep them in sync when behaviour changes.
- Strict TDD in history: a `test: … (Txxx, red)` commit followed by `feat:`/`fix: … (Txxx, green)`. Each phase is a stacked PR.
- Deliberate constraints (see README "Trade-offs"): no third-party packages, one package (not multiple modules), iOS 18 minimum, Xcode 27 / Swift 6.4 toolchain (`swift-tools-version: 6.4`, Swift 6 language mode); APIs newer than iOS 18 need `if #available`. Project rules live in `.specify/memory/constitution.md`.
- `intent.md` captures the brief and non-goals (no persistence, no accounts, no marine/swell API — surfing is weather-only and the UI says so).
