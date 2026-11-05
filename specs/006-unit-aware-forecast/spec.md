# Feature Specification: Unit-Aware Forecast

**Feature Branch**: `006-unit-aware-forecast`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "Pass non-default unit parameters to the API request and make the scoring logic measurement specific."

## Context

Until now the app always fetched the forecast in Open-Meteo's metric defaults, and every weather value travelled through ForecastKit as a bare `Double` whose unit was only a doc comment (°C, mm, cm, km/h). Scoring thresholds silently assumed those units. The display already converted values to the user's units (specs/001 FR-016).

This feature makes units explicit end to end: the request asks for the user's units, every value carries its unit, and scoring converts to the units its thresholds are written in. The scores therefore do not depend on the units the data arrived in.

## Clarifications

### Session 2026-11-05

- Q: Two threshold tables (metric and imperial), or one table with conversion? → A: One table (research.md R9 of specs/001, in metric). Values carry their unit (`Measurement`), and the scorer converts before applying a threshold (R1).
- Q: Which units does the request ask for? → A: The user's locale: °F when the locale or the iOS temperature setting says so; inches for precipitation and snow in the US measurement system; mph for wind outside the metric system (UK, US); otherwise °C, mm and km/h (R2).
- Q: Trust the requested units, or the response? → A: The response. Each series is read with the unit named in `daily_units` / `hourly_units`. A present series with a missing or unknown unit fails as `UserFacingError.unexpected` (R3).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Scores do not depend on units (Priority: P1)

A user in the US and a user in Germany who look at the same place on the same day see the same scores and the same reasons; only the units of the values differ.

**Independent Test**: score the four reference weeks given in metric and the same weeks converted to imperial; every score, label, best day and rank is identical.

**Acceptance Scenarios**:

1. **Given** a week in °F, inches and mph, **When** it is ranked, **Then** the result equals the ranking of the same week in °C, mm/cm and km/h.
2. **Given** snow depth in feet, **When** skiing is scored, **Then** the snow factor equals the one computed from the same depth in metres.

### User Story 2 - The forecast is fetched in the user's units (Priority: P2)

The forecast request asks Open-Meteo for the user's units, and values are decoded with the units the response states.

**Independent Test**: client tests check the unit parameters of the request, decode a recorded imperial response, and reject an unknown unit.

**Acceptance Scenarios**:

1. **Given** US units, **When** the forecast is requested, **Then** the request has `temperature_unit=fahrenheit`, `wind_speed_unit=mph` and `precipitation_unit=inch`.
2. **Given** a response whose `daily_units` say `°F`, **When** it is decoded, **Then** temperatures are Fahrenheit measurements with the response's values.
3. **Given** a response with a unit the app does not know, **When** it is decoded, **Then** the forecast fails with the retryable "unexpected" error.

### Edge Cases

- A series absent from the response needs no unit; a present series without a unit is an error.
- Snow depth arrives hourly in metres or feet; the daily maximum keeps that unit.
- Sunshine always arrives in seconds; it is a duration measurement, shown in hours.

## Requirements *(mandatory)*

- **FR-001**: The forecast request MUST include `temperature_unit`, `wind_speed_unit` and `precipitation_unit`, chosen by `ForecastUnits`.
- **FR-002**: The app MUST choose `ForecastUnits` from the user's locale (R2) in the composition root; the client defaults to metric.
- **FR-003**: Every weather quantity in `DailyWeather` and in `Reason.Detail` MUST be a `Measurement` of the matching dimension (temperature, length, speed, duration). Probability and weather code stay plain numbers.
- **FR-004**: Decoding MUST use the units stated in the response, and MUST fail with `UserFacingError.unexpected` for a present series whose unit is missing or unknown.
- **FR-005**: Scoring MUST give identical results for the same weather in any supported units; thresholds stay as in specs/001 research R9.
- **FR-006**: Reasons MUST carry the measurement as received; the app formats it in the user's units (specs/001 FR-016).
- **FR-007**: The four reference weeks in `WeeklyRankerTests` MUST keep their expected results.

## Success Criteria *(mandatory)*

- **SC-001**: The reference weeks in metric and in imperial rank identically (automated).
- **SC-002**: A recorded live imperial response decodes to the same scores as the metric response for the same place within rounding (automated, Chamonix fixtures).
- **SC-003**: All quality gates pass (`swiftlint lint --strict`, `swift test`, `xcodebuild test`, simulator build).

## Assumptions

- Supported response units: `°C`, `°F`; `mm`, `cm`, `m`, `inch`, `ft`; `km/h`, `mp/h`, `m/s`, `kn`; `s` (verified live 2026-11-05).
- The display path (specs/001 FR-016) is unchanged in behaviour.
