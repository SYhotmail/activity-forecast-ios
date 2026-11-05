# Contract: Open-Meteo (consumed)

These are the only external interfaces. Shapes were verified against the live endpoints on 2026-11-03. Only the fields we decode are listed; unknown fields are ignored. No API key is needed.

## Geocoding — place search

`GET https://geocoding-api.open-meteo.com/v1/search?name={query}&count=10&language=en&format=json`

`{query}` is percent-encoded and trimmed, and has at least 2 characters.

Response 200:
```json
{
  "results": [
    { "id": 2988507, "name": "Paris", "latitude": 48.85341, "longitude": 2.3488,
      "country": "France", "admin1": "Île-de-France Region", "timezone": "Europe/Paris" }
  ],
  "generationtime_ms": 0.31
}
```
- **No matches**: the `results` key is **absent** (`{"generationtime_ms":0.13}`). Decoded as an empty list, which shows the "No places found" state.
- `admin1` and `country` are optional.

## Forecast — 7 days

`GET https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,rain_sum,snowfall_sum,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,sunshine_duration&hourly=snow_depth&timezone=auto&timeformat=unixtime&forecast_days=7&temperature_unit={celsius|fahrenheit}&wind_speed_unit={kmh|ms|mph|kn}&precipitation_unit={mm|inch}`

The unit parameters come from `ForecastUnits` and are sent only when they differ from the defaults `celsius`, `kmh`, `mm` (specs/006 FR-001).

Response 200 (abridged):
```json
{
  "utc_offset_seconds": 3600,
  "timezone": "Europe/Paris",
  "daily_units": { "temperature_2m_max": "°C", "precipitation_sum": "mm", "snowfall_sum": "cm",
                   "wind_speed_10m_max": "km/h", "sunshine_duration": "s", "precipitation_probability_max": "%" },
  "daily": {
    "time": [1793660400, 1793746800],
    "weather_code": [45, 3],
    "temperature_2m_max": [8.7, 10.5], "temperature_2m_min": [-3.9, 1.5],
    "precipitation_sum": [0.0, 0.0], "rain_sum": [0.0, 0.0], "snowfall_sum": [0.0, 0.0],
    "precipitation_probability_max": [0, 3],
    "wind_speed_10m_max": [6.8, 14.3], "wind_gusts_10m_max": [13.0, 28.8],
    "sunshine_duration": [34028.68, 33626.44]
  },
  "hourly_units": { "snow_depth": "m" },
  "hourly": { "time": [1793660400, "..."], "snow_depth": [0.0, "..."] }
}
```
- The daily arrays are parallel and indexed by `time`. Any element can be `null`, so each one is decoded as `Double?` or `Int?`.
- `time` is Unix seconds in GMT (`timeformat=unixtime`); `timezone=auto` still decides where each day starts, so a daily value is the place's local midnight. Convert it to a calendar day with the place's `TimeZone(identifier: timezone)`, which follows DST. `utc_offset_seconds` is only a fallback for an unknown identifier: it is the offset at request time, so adding it misdates days after a spring DST change. *(refactoring-sdk; originally local `yyyy-MM-dd` strings.)*
- Every measured series is decoded as a `Measurement` in the unit `daily_units` / `hourly_units` names for it, never in the unit requested (specs/006 FR-004). Known symbols: `°C`, `°F`; `mm`, `cm`, `inch` (precipitation, snowfall); `m`, `ft` (snow depth); `km/h`, `mp/h`, `m/s`, `kn`; `s` (sunshine). A present series with a missing or unknown unit → `UserFacingError.unexpected`.
- `snow_depth` is hourly, in metres (feet with `precipitation_unit=inch`): group by the place's calendar day of `hourly.time` (same conversion) and take the max, keeping the unit.
- `sunshine_duration` is always in seconds; the app shows it in hours.

## Error mapping (FR-011)

| Condition | UserFacingError |
|---|---|
| `URLError.notConnectedToInternet`, `.networkConnectionLost`, `.timedOut` | `.offline` |
| HTTP 4xx/5xx (Open-Meteo returns `{"error":true,"reason":"..."}`) | `.serviceUnavailable` |
| Decoding failure, or forecast with zero days | `.unexpected` |
| `CancellationError` / `URLError.cancelled` | not an error. Ignored (superseded request) |
