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

# Build the app
xcodebuild -project ActivityForecast.xcodeproj -scheme ActivityForecast \
  -destination 'generic/platform=iOS Simulator' build
```

No linter is configured. There is no UI test target; screens are covered by SwiftUI previews (`App/Shared/PreviewData.swift`) and the manual checklist in `specs/001-activity-forecast-ranking/quickstart.md`.

## Architecture

Layered MVVM, one-way dependencies `App → ForecastKit → Foundation`. All logic lives in the local package `Packages/ForecastKit` (referenced by the `.xcodeproj` as a local package) so it is testable with `swift test`; `App/` contains SwiftUI views only.

- **`Features/`**: `SearchModel`, `ForecastModel` are `@MainActor @Observable` and expose a single `LoadState<Value>` (idle / loading / loaded / empty / failed). Failures are surfaced only as `UserFacingError` (offline / serviceUnavailable / unexpected) with retry. Search is debounced (300 ms, driven from the view via `.task(id:)`); superseded requests are cancelled and stale results must never overwrite newer ones — this is tested.
- **`Scoring/`**: `ActivityScorer` (per-day score + plain-language reason) and `WeeklyRanker` (weekly mean over days with data, ranking, best-day star) are pure and deterministic. Factors are normalised with piecewise-linear ramps (`Ramp`) plus hard caps. The authoritative weight table is `research.md` R9; `WeeklyRankerTests` pins four reference weeks (snowy alpine, rainy city, sunny coast, hot/dry) — changing weights must keep those passing. Indoor = `30 + 0.6 × (100 − outdoor)`; best day is starred only at ≥ 25 (Fair); "No data" days are excluded, never counted as 0.
- **`Service/`**: `WeatherService` protocol is the data boundary; `OpenMeteoClient` (URLSession + Codable DTOs in `OpenMeteoDTOs.swift`) is the live impl, `StubWeatherService` the fake for previews/model tests. `ActivityForecastApp` is the composition root and the only place that chooses the live service.
- **`Models/`**: `LocalDate` keeps forecast days as calendar components in the *place's* time zone, so the device time zone never shifts a day. "7 days" = today + 6 in that zone.

Open-Meteo quirks already encoded in the client (verified live): a geocoding search with no matches omits `results`; snow depth is hourly-only and in metres. Fixtures in `Tests/ForecastKitTests/Fixtures/` are recorded live responses.

Test support: `StubURLProtocol` holds a process-wide handler, so any suite using it must be `@Suite(..., .serialized)`. In model tests, `Gate` scripts when an async stub returns, and `Recorder` captures the arguments stubs received.

## Workflow conventions

- Spec-driven ([Spec Kit](https://github.com/github/spec-kit), `.specify/`, `speckit-*` skills). Feature docs live in `specs/001-activity-forecast-ranking/`: `spec.md` (FR-xxx requirements, clarifications), `plan.md`, `research.md` (decisions R1–R13), `data-model.md`, `contracts/` (`open-meteo.md`, `ui.md`), `tasks.md` (Txxx). Code comments reference these IDs; keep them in sync when behaviour changes.
- Strict TDD in history: a `test: … (Txxx, red)` commit followed by `feat:`/`fix: … (Txxx, green)`. Each phase is a stacked PR.
- Deliberate constraints (see README "Trade-offs"): no third-party packages, one package (not multiple modules), iOS 18 minimum so reviewers on Xcode 16 can build — avoid newer-only APIs.
- `intent.md` captures the brief and non-goals (no persistence, no accounts, no marine/swell API — surfing is weather-only and the UI says so).
