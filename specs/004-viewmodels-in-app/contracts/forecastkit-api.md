# Contract: Public API of the package after feature 004

## Product `ForecastKit` (the only product; linked by the app)
Domain and data only (constitution V):
- Models: `Activity`, `Place`, `DailyWeather`, `LocalDate`, `SuitabilityLabel`, `Reason`, `DaySuitability`, `ActivityRanking`, `WeeklyRanking`
- Scoring: `Ramp`, `ActivityScorer`, `WeeklyRanker`
- Data: `WeatherService` (protocol), `OpenMeteoClient`, `UserFacingError`

No user-facing text: ForecastKit returns typed values only (`Reason` carries a `Reason.Detail` with the raw measured value, not a sentence). Titles, error messages, place names and reason sentences are app extensions in `App/Extensions/` (refactoring-sdk).

MUST NOT be public here: `LoadState`, `SearchModel`, `ForecastModel`, `BrowseModel`, `StubWeatherService`.

## Test doubles (not package API)
- `StubWeatherService`: in the app, internal, no `#if DEBUG`. Used by previews and, through `@testable import`, by `ActivityForecastTests`; never by production code (only `ActivityForecastApp` chooses the service).
- `Gate`, `Recorder<Value>`: internal to the `ActivityForecastTests` target.

The release binary MUST contain none of their symbols (checked in quickstart.md #5).
