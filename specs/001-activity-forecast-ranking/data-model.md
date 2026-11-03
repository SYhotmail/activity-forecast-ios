# Data Model: Activity Forecast Ranking

Phase 1 output. All types are immutable value types (`struct` or `enum`, `Sendable`, `Equatable`) in `ForecastKit`, apart from the two `@Observable` screen models.

## Place
A selectable city or town (spec: Place).

| Field | Type | Rule |
|---|---|---|
| id | Int | Geocoding `id`. Unique, used for list identity |
| name | String | non-empty |
| region | String? | Geocoding `admin1`. Can be missing |
| country | String? | Geocoding `country`. Can be missing for some territories |
| latitude, longitude | Double | −90…90 and −180…180 |
| timeZone | String | IANA identifier, display only. Forecast dates already arrive in local time (`timezone=auto`) |

Derived: `displayName` = name plus whichever of region and country are present, joined with ", " (FR-002).

## DailyWeather
One forecast day (spec: Daily Weather). Values are optional because the API can return `null` (FR-013).

| Field | Type | Unit |
|---|---|---|
| date | `DateComponents` / `Date` at local midnight | local calendar day |
| weatherCode | Int? | WMO code |
| temperatureMax, temperatureMin | Double? | °C |
| precipitation, rain | Double? | mm |
| snowfall | Double? | cm |
| snowDepth | Double? | cm (daily max of hourly metres × 100) |
| precipitationProbability | Double? | % |
| windSpeedMax, windGustsMax | Double? | km/h |
| sunshine | Double? | hours (API seconds ÷ 3600) |

Rule: a day is **scorable** for an activity only if every factor that activity needs is present. Otherwise its suitability is `.noData`.

## Activity
`enum Activity: CaseIterable { skiing, surfing, outdoorSightseeing, indoorSightseeing }`. Declaration order is the final tie-break.

## SuitabilityLabel
`enum { poor, fair, good, excellent }`, built from a score: 0–24 → poor, 25–49 → fair, 50–74 → good, 75–100 → excellent (FR-005).

## Reason
`struct { kind: positive | negative | cap, text: String }`. Examples: "Fresh snow 12 cm", "Strong gusts 65 km/h", "Thunderstorms — unsafe". At most two per day, with a cap reason first.

## DaySuitability
One activity on one day (spec: Activity Suitability).

| Field | Type | Rule |
|---|---|---|
| activity | Activity | |
| date | Date | |
| result | `.scored(score: Int, label: SuitabilityLabel, reasons: [Reason])` or `.noData` | score 0…100, deterministic (FR-009) |
| weather | DailyWeather | kept for the detail view (FR-008) |

## ActivityRanking
One activity across the week (spec: Activity Ranking).

| Field | Type | Rule |
|---|---|---|
| activity | Activity | |
| days | [DaySuitability] | in date order, up to 7 |
| weeklyScore | Int? | rounded mean of scored days. `nil` if no day is scorable |
| bestDay | Date? | highest score, earliest if tied, only if ≥ 25. Otherwise `nil` ("No suitable day this week") (FR-007) |
| rank | Int | 1…4 |

## WeeklyRanking
`struct { place: Place, rankings: [ActivityRanking] }`. Rankings are sorted by weeklyScore descending (`nil` last), then best-day score, then `Activity` order (FR-006).

## LoadState (screen state)
```text
enum LoadState<Value> { idle, loading, loaded(Value), empty, failed(UserFacingError) }
```
- `SearchModel.state: LoadState<[Place]>`
  - query shorter than 2 characters → `idle` (shows a hint)
  - typing ≥2 characters → `loading` → `loaded` / `empty` / `failed`
  - when the query changes, the in-flight request is cancelled and its result is dropped (FR-012)
- `ForecastModel.state: LoadState<WeeklyRanking>`: `loading` → `loaded` / `failed`. `retry()` goes back to `loading`.
- `UserFacingError`: `.offline`, `.serviceUnavailable`, `.unexpected`. Each has a message and is retryable (FR-011).

## Relationships
```text
Place 1 ── 1 WeeklyRanking 1 ── 4 ActivityRanking 1 ── ≤7 DaySuitability ── 1 DailyWeather
```
