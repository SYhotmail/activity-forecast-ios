# Data Model: Stricter MVVM in the App Layer

All types are `internal` to the app target and main-actor isolated, unless marked `nonisolated`. `ForecastKit` is unchanged.

## Name mapping (old → new)

Code comments and earlier specs (001, 003, 004) use the old names. This table resolves them.

| Old | New | New location |
|---|---|---|
| `BrowseModel` | `BrowseViewModel` | `App/Features/Browse/BrowseViewModel.swift` |
| `RootView` | `BrowseView` | `App/Features/Browse/BrowseView.swift` |
| `SearchModel` | `SearchViewModel` | `App/Features/Search/SearchViewModel.swift` |
| `ForecastModel` | `ForecastViewModel` | `App/Features/Forecast/ForecastViewModel.swift` |
| `ForecastModel.selectedDay: DaySuitability?` | `ForecastViewModel.presentedDay: PresentedDay?` | same file |
| `ForecastView`'s private `DaySelection` | `PresentedDay` | `App/Features/Forecast/ForecastViewModel.swift` |
| `LoadState` (`App/Features/`) | unchanged name | `App/Views/LoadStateView/LoadState.swift` |
| `LoadStateView` (`App/Shared/`) | unchanged name | `App/Views/LoadStateView/LoadStateView.swift` |
| `{Browse,Search,Forecast}ModelTests` | `{Browse,Search,Forecast}ViewModelTests` | `AppTests/` |

## BrowseViewModel

The fields from specs/003 are unchanged: `search: SearchViewModel` (let), `selectedPlace: Place?` (private(set)), `forecast: ForecastViewModel?` (private(set)).

The invariant is unchanged: `forecast?.place == selectedPlace`.

| Member | Kind | Behaviour |
|---|---|---|
| `selection: Place?` | **new**, computed get/set | get → `selectedPlace`; set → `select(newValue)` |
| `select(_ place: Place?)` | unchanged | same place → no-op (forecast kept); other place → new `ForecastViewModel`; `nil` → clears both |

Selection transitions, the same as before:
- `nil` → set(place): selected, forecast `.loading`.
- set(same): no-op.
- set(other): forecast replaced, together with its `presentedDay`.
- set(nil): cleared.

`select(_:)` also cancels the replaced forecast's request (FR-012).

## ForecastViewModel

`place` and `state: LoadState<WeeklyRanking>` are unchanged.

| Member | Kind | Behaviour |
|---|---|---|
| `presentedDay: PresentedDay?` | **replaces** `selectedDay`, settable | `nil` = no sheet; the sheet binding writes `nil` on dismiss |
| `showDetail(for day: DaySuitability)` | **new** intent | `presentedDay = PresentedDay(day: day)`; replaces any day already presented |
| `cancel()` | **new** | stops the fetch in flight; its result is dropped and the state stays as it is |
| `loadIfNeeded()` | **changed** | still skips when loaded; now joins a fetch in flight instead of starting a second one |
| `load()` / `retry()` | **changed** | supersede any fetch in flight; a cancelled caller no longer stops the fetch |

Loading never touches `presentedDay`, so a rebuild that calls `loadIfNeeded()` keeps the sheet open (specs/003 US3).

## PresentedDay (new, `nonisolated`)

| Field | Type | Notes |
|---|---|---|
| `day` | `DaySuitability` | the activity and day whose detail is shown |
| `id` | `DaySuitability` (computed) | `day`, which is `Hashable`, so it is a valid identity |

Conformances: `Identifiable, Hashable, Sendable`.

## SearchViewModel, LoadState

Renamed or moved only. Behaviour is unchanged.
