# Contract: Public API of the package after feature 004

## Product `ForecastKit` (production; linked by the app in all configurations)
Domain and data only (constitution V):
- Models: `Activity`, `Place`, `DailyWeather`, `LocalDate`, `SuitabilityLabel`, `Reason`, `DaySuitability`, `ActivityRanking`, `WeeklyRanking`
- Scoring: `Ramp`, `ActivityScorer`, `WeeklyRanker`
- Data: `WeatherService` (protocol), `OpenMeteoClient`, `UserFacingError`

MUST NOT be public here: `LoadState`, `SearchModel`, `ForecastModel`, `BrowseModel`, `StubWeatherService`.

## Product `ForecastKitTestSupport` (developer-only)
- `StubWeatherService` (closure-scripted `WeatherService`)
- `Gate` (one-shot async latch), `Recorder<Value>` (actor collecting stub arguments)

Linked by `ActivityForecastTests`, and by the app for SwiftUI previews only (`#Preview` and preview data are stripped from Release). The release binary MUST contain none of its symbols (checked in quickstart.md).
