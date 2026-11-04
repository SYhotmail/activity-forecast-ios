# Data Model: Universal App with Adaptive Layouts

No new domain data. Two screen-model changes in `ForecastKit/Features`. Search, scoring and API models are unchanged (FR-011).

## BrowseModel (new, `@MainActor @Observable`)

| Field | Type | Notes |
|---|---|---|
| `search` | `SearchModel` | Created once; query and results survive every resize (FR-007) |
| `selectedPlace` | `Place?` | `nil` = nothing selected (wide layout shows "Pick a place") |
| `forecast` | `ForecastModel?` | The forecast for `selectedPlace` |

Operations:
- `init(service: any WeatherService)` creates `search` with the same service.
- `select(_ place: Place?)`:
  - same place as now → no change (the existing `forecast` instance and its state are kept);
  - a different place → `forecast = ForecastModel(place:service:)` (new, `.loading`);
  - `nil` → `forecast = nil`.

Invariants (tested):
- `forecast?.place == selectedPlace` at all times.
- Selecting the current place again never replaces `forecast` and never triggers a fetch.
- `search` is the same instance for the model's lifetime.

## ForecastModel (extended)

| Addition | Type | Notes |
|---|---|---|
| `selectedDay` | `DaySuitability?` | The day whose detail sheet is open; `nil` = closed. Survives view rebuilds (US3-3) |
| `loadIfNeeded()` | `async` | No-op if `state` is `.loaded`; otherwise `load()`. `retry()` still always reloads |

## SearchModel (extended)

| Addition | Type | Notes |
|---|---|---|
| `lastQuery` (private) | `String?` | Trimmed query that produced the current `.loaded`/`.empty` state |

Rules (tested):
- `search()` makes no request and leaves the state unchanged when the trimmed query equals `lastQuery` and the state is `.loaded` or `.empty`.
- A different query searches as before. `retry()` clears `lastQuery` and always searches.

## State transitions

| Event | Before | After |
|---|---|---|
| select A | none | `selectedPlace = A`, `forecast(A).state = .loading` → `.loaded` / `.failed` after `loadIfNeeded()` |
| select A again | A, loaded | unchanged (same `forecast` instance, no fetch) |
| select B | A, any | `selectedPlace = B`, new `forecast(B)` in `.loading` |
| select nil | A, any | `selectedPlace = nil`, `forecast = nil` |
| window resize / fold | any | unchanged. Views rebuild against the same model. `loadIfNeeded()` is a no-op when loaded |
| resize during load (cancelled) | A, `.loading` | still `.loading`; the next `loadIfNeeded()` restarts the fetch once |
| sidebar rebuilt (resize) with results for query Q | `.loaded`/`.empty` for Q | unchanged, no request |
| tap day D / dismiss sheet | `selectedDay = nil` / `D` | `D` / `nil` |
