# Implementation Plan: Unit-Aware Forecast

**Branch**: `006-unit-aware-forecast` | **Date**: 2026-11-05 | **Spec**: [spec.md](./spec.md)

## Summary

1. `ForecastKit/Models`: `ForecastUnits` (request units, `init(locale:)`); `DailyWeather` and `Reason.Detail` hold `Measurement`s (R1).
2. `ForecastKit/Service`: the forecast request sends the three unit parameters; DTOs decode `daily_units` / `hourly_units` and build measurements in the stated unit (R3).
3. `ForecastKit/Scoring`: `ActivityScorer` converts inputs to its threshold units; weights and ramps unchanged.
4. App: `Formatting` helpers take measurements; `ActivityForecastApp` passes `ForecastUnits(locale: .current)`; previews and stubs build measurements.

## Constitution Check

- No third-party dependencies, one package, iOS 18: unchanged.
- TDD: red commit (tests) then green commit (implementation).
- ForecastKit still holds no user-facing strings.

## Testing

- Package: scorer and ranker tests build weather from measurements; a new suite proves imperial = metric for the reference weeks; client tests cover request parameters, an imperial fixture (`forecast-chamonix-imperial.json`, recorded live) and unknown units.
- App: `DisplayTextTests` format measurements in other units.
