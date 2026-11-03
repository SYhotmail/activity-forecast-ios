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

`GET https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,rain_sum,snowfall_sum,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,sunshine_duration&hourly=snow_depth&timezone=auto&forecast_days=7`

Response 200 (abridged):
```json
{
  "timezone": "Europe/Paris",
  "daily_units": { "temperature_2m_max": "°C", "precipitation_sum": "mm", "snowfall_sum": "cm",
                   "wind_speed_10m_max": "km/h", "sunshine_duration": "s", "precipitation_probability_max": "%" },
  "daily": {
    "time": ["2026-11-03", "2026-11-04"],
    "weather_code": [45, 3],
    "temperature_2m_max": [8.7, 10.5], "temperature_2m_min": [-3.9, 1.5],
    "precipitation_sum": [0.0, 0.0], "rain_sum": [0.0, 0.0], "snowfall_sum": [0.0, 0.0],
    "precipitation_probability_max": [0, 3],
    "wind_speed_10m_max": [6.8, 14.3], "wind_gusts_10m_max": [13.0, 28.8],
    "sunshine_duration": [34028.68, 33626.44]
  },
  "hourly_units": { "snow_depth": "m" },
  "hourly": { "time": ["2026-11-03T00:00", "..."], "snow_depth": [0.0, "..."] }
}
```
- The daily arrays are parallel and indexed by `time`. Any element can be `null`, so each one is decoded as `Double?` or `Int?`.
- `time` is a local calendar date (because of `timezone=auto`). Parse it with a fixed `yyyy-MM-dd` format in the place's time zone.
- `snow_depth` is hourly, in **metres**: group by the date prefix of `hourly.time`, take the max and multiply by 100 to get cm.
- `sunshine_duration` is in seconds: divide by 3600 to get hours.

## Error mapping (FR-011)

| Condition | UserFacingError |
|---|---|
| `URLError.notConnectedToInternet`, `.networkConnectionLost`, `.timedOut` | `.offline` |
| HTTP 4xx/5xx (Open-Meteo returns `{"error":true,"reason":"..."}`) | `.serviceUnavailable` |
| Decoding failure, or forecast with zero days | `.unexpected` |
| `CancellationError` / `URLError.cancelled` | not an error. Ignored (superseded request) |
