# Data Model: View Models Live in the App

No data shapes change; only ownership and visibility.

| Type | Before | After | Visibility after |
|---|---|---|---|
| `SearchModel` | `ForecastKit/Features` | `App/Features` | internal |
| `ForecastModel` | `ForecastKit/Features` | `App/Features` | internal |
| `BrowseModel` | `ForecastKit/Features` | `App/Features` | internal |
| `LoadState<Value>` | `ForecastKit/Features/LoadState.swift` | `App/Features/LoadState.swift` | internal |
| `UserFacingError` | `ForecastKit/Features/LoadState.swift` | `ForecastKit/Service/UserFacingError.swift` | public (unchanged) |
| `StubWeatherService` | `ForecastKit/Service` (public) | `ForecastKitTestSupport` | public, test-support only |
| `Gate`, `Recorder` | `Tests/ForecastKitTests/Support` (internal) | `ForecastKitTestSupport` | public, test-support only |
| `StubURLProtocol` | `Tests/ForecastKitTests/Support` | unchanged | internal to package tests |

Invariants (all unchanged, now proven in `ActivityForecastTests`):
- `BrowseModel`: `forecast?.place == selectedPlace`; re-selecting the same place never refetches.
- `SearchModel`: a stale result never overwrites a newer query; an unchanged query is not re-requested; `retry()` always searches.
- `ForecastModel`: `loadIfNeeded()` never refetches a loaded week; `retry()` always reloads; `selectedDay` survives rebuilds.
