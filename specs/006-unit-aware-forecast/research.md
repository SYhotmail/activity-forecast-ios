# Research: Unit-Aware Forecast

## R1 — One threshold table, values carry units

**Decision**: `DailyWeather` and `Reason.Detail` hold `Measurement<Unit…>` values. The scorer converts each input to the unit its ramp or cap is written in (°C, mm, cm, km/h, hours) at the top of each activity's scoring function.

**Rationale**: a second (imperial) threshold table would double the tuning surface and the four reference weeks would pin only one of them. Conversion keeps research.md R9 of specs/001 the single source of truth.

**Alternatives**: unit-tagged `Ramp<Unit>` types (more types for no extra safety, since conversion happens in one place); converting to metric in the DTO layer (the domain would again rely on an implicit unit).

## R2 — Units from the locale

**Decision**: `ForecastUnits(locale:)`: temperature from `Locale.temperatureUnit` (honours the iOS Temperature setting); precipitation `inch` when `measurementSystem == .us`, else `mm`; wind `kmh` when `measurementSystem == .metric`, else `mph`. Built once in `ActivityForecastApp`.

**Rationale**: matches what `MeasurementFormatter` usages show, so the fetched units are usually already the displayed ones. A later locale change only affects display formatting, which converts anyway; scores are unit-independent (R1).

## R3 — Trust response units

**Decision**: decode `daily_units` and `hourly_units` and map each unit string to a Foundation unit. Unknown or missing unit for a present series → `UserFacingError.unexpected`.

**Verified live (2026-11-05)**: with `temperature_unit=fahrenheit&precipitation_unit=inch` the response says `°F`, `inch` (also for `snowfall_sum`), and `snow_depth` `ft`; `wind_speed_unit` `mph|ms|kn` gives `mp/h`, `m/s`, `kn`. Defaults: `°C`, `mm`, `cm` (snowfall), `m` (snow depth), `km/h`; sunshine always `s`.
