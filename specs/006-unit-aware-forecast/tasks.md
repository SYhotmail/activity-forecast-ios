# Tasks: Unit-Aware Forecast

**Input**: `/specs/006-unit-aware-forecast/` (spec.md, plan.md, research.md)

Gates: `swiftlint lint --strict`, `swift test --package-path Packages/ForecastKit`, `xcodebuild test …`, simulator build.

## Phase 1: Setup

- [X] T001 Commit the 006 spec artifacts.

## Phase 2: US1 + US2 (P1, P2) — measurements end to end

- [ ] T002 [red] Package tests: scorer/ranker tests on measurements; `UnitIndependenceTests` (imperial = metric for the reference weeks, snow depth in feet); client tests for unit parameters, imperial fixture `forecast-chamonix-imperial.json` (recorded live), unknown/missing unit → unexpected; `ForecastUnitsTests` for the locale mapping. App `DisplayTextTests` on measurements.
- [ ] T003 [green] `ForecastUnits`; `DailyWeather` / `Reason.Detail` measurements; DTO unit decoding; request unit parameters; scorer conversion; app `Formatting`, `Reason+Display`, `DayDetailView`, previews, composition root.
- [ ] T004 Docs: specs/001 FR-016 and contracts/open-meteo.md note units from the response; CLAUDE.md quirks line.

## Phase 3: Polish

- [ ] T005 All gates; Release binary has no `StubWeatherService`/`PreviewData` symbols.
