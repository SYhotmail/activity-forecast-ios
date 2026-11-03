# Feature Specification: Activity Forecast Ranking

**Feature Branch**: `001-activity-forecast-ranking`

**Created**: 2026-11-03

**Status**: Draft

**Input**: User description: "based on intent.md" — a mobile app where a user searches for a city or town and sees how suitable each of the next 7 days is for Skiing, Surfing, Outdoor sightseeing and Indoor sightseeing.

## Clarifications

### Session 2026-11-03

- Q: Which architectural pattern should the app use? → A: Layered MVVM. Views only render; screen view models hold state and user actions; pure domain logic holds scoring and ranking; a data layer talks to the weather service. Dependencies point one way. Details are in [plan.md](./plan.md#architecture); requirements below stay technology-agnostic.
- Q: How is the project file maintained? → A: A native Xcode project (`.xcodeproj`), created and maintained in Xcode. No project generator and no `project.yml`.
- Q: What development discipline applies? → A: Test-driven development (red → green → refactor). Every behaviour in FR-001 to FR-013 is first expressed as a failing automated test, then implemented. Screen layout (FR-015) is checked through previews and the manual run-through instead.
- Q: If even the best day of the week is rated Poor for an activity, should it still be marked as the best day? → A: No. A best day is marked only if its score is 25 or higher (Fair or better); otherwise the activity shows "No suitable day this week". (The user moved on without choosing, so the recommended option was applied; it can be changed.)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Search a place and see the week ranked by activity (Priority: P1)

A traveller planning the coming week types the name of a city or town, picks the right match from the results, and immediately sees the four activities ordered from most to least suitable for the week. Each activity shows a suitability rating for every one of the next 7 days, with its best day highlighted.

**Why this priority**: This is the core value of the product. Without it there is nothing to show; every other story builds on it.

**Independent Test**: Search for a known place, select it, and confirm that four activities appear in ranked order, each with seven daily ratings and at most one best day marked.

**Acceptance Scenarios**:

1. **Given** the app is open with no place selected, **When** the user types "Chamonix" and selects "Chamonix, Auvergne-Rhône-Alpes, France", **Then** the user sees four activities in ranked order, each with seven daily ratings labelled Poor, Fair, Good or Excellent.
2. **Given** a selected place whose forecast is snowy and below freezing for most of the week, **When** the results appear, **Then** Skiing is ranked first.
3. **Given** a selected place whose forecast is rainy all week, **When** the results appear, **Then** Indoor sightseeing is ranked above Outdoor sightseeing.
4. **Given** results are shown, **When** the user looks at an activity whose highest daily score is 25 or more, **Then** exactly one day is marked as its best day; **When** its highest daily score is below 25, **Then** no day is marked and "No suitable day this week" is shown.
5. **Given** results are shown for one place, **When** the user searches for and selects a different place, **Then** the results are replaced with the new place's ranking.

---

### User Story 2 - Understand why a day scored the way it did (Priority: P2)

A user who sees that a day is rated "Poor" for outdoor sightseeing wants to know why before changing their plans. They open that day and see the main weather factors (temperature range, precipitation, snowfall, wind) and a short plain-language reason such as "Heavy rain — poor for being outside".

**Why this priority**: Ratings without reasons are hard to trust. Explanations make the ranking credible, but the ranking is still useful without them.

**Independent Test**: With results shown, select any activity and day and confirm the weather factors and a reason are displayed and match the rating.

**Acceptance Scenarios**:

1. **Given** results are shown, **When** the user selects a day for an activity, **Then** the temperature range, precipitation, snowfall and wind for that day are shown along with at least one plain-language reason.
2. **Given** a day rated Poor for Outdoor sightseeing because of heavy rain, **When** the user views its details, **Then** the reason mentions rain.
3. **Given** the user views Surfing details, **When** the details are shown, **Then** a note explains that the rating is based on weather only and does not include wave conditions.

---

### User Story 3 - Find the right place and recover from problems (Priority: P3)

A user searching for a common name (e.g. "Paris" or "Springfield") needs to tell the matches apart. A user with a poor connection needs to know what went wrong and how to try again.

**Why this priority**: Improves reliability and trust, but the core flow works for unambiguous names on a good connection without it.

**Independent Test**: Search for an ambiguous name and confirm results show region and country; disable connectivity and confirm a clear message with a retry option.

**Acceptance Scenarios**:

1. **Given** the user types "Paris", **When** results appear, **Then** each result shows its name, region and country (e.g. "Paris, Île-de-France, France" and "Paris, Texas, United States").
2. **Given** a search with no matches, **When** results come back, **Then** the user sees a "No places found" message and can edit the search.
3. **Given** the device is offline, **When** the user searches or loads a forecast, **Then** the user sees a message explaining the problem and a Retry action that repeats the request.
4. **Given** results are loading, **When** the user is waiting, **Then** a loading indicator is visible.
5. **Given** the user types quickly ("Lon" then "London"), **When** responses arrive out of order, **Then** only the results for the latest text are shown.

---

### Edge Cases

- Search text that is empty or a single character: no search is performed and a hint is shown.
- Place names with accents or non-Latin characters (e.g. "Zürich", "東京") are searchable and displayed correctly.
- The forecast returns fewer than 7 days or some weather values are missing: available days are scored; missing days or values are shown as "No data" rather than as a misleading rating.
- A place far from the sea is selected: Surfing is still scored from weather, and the weather-only caveat stays visible.
- A warm or low-lying place is selected: Skiing scores Poor for days with no snow and temperatures above freezing.
- Days are shown in the selected place's local time zone, even if the user's device is in a different time zone.
- The connection drops after search results appear but before the forecast loads: an error with Retry is shown for the forecast only, and the search results are kept.
- Two activities have the same weekly score: the one with the higher best-day score ranks higher; if still tied, the fixed order Skiing, Surfing, Outdoor sightseeing, Indoor sightseeing applies.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to search for a city or town by name; a search starts once at least 2 characters are entered.
- **FR-002**: Each search result MUST show the place name, region (where available) and country.
- **FR-003**: Users MUST be able to select a search result to load the next 7 days of weather for that place (today plus the following 6 days, in the place's local time zone).
- **FR-004**: The system MUST give each of the four activities (Skiing, Surfing, Outdoor sightseeing, Indoor sightseeing) a suitability score from 0 to 100 for each day.
- **FR-005**: Each daily score MUST be shown as a label: Poor (0–24), Fair (25–49), Good (50–74), Excellent (75–100).
- **FR-006**: The system MUST rank the four activities by their weekly score (the average of their daily scores), highest first, using the tie-break rules in Edge Cases.
- **FR-007**: The system MUST mark at most one best day per activity: the highest-scoring day (the earliest if tied), and only if its score is 25 or higher. Otherwise it shows "No suitable day this week".
- **FR-008**: For any activity and day, users MUST be able to see the temperature range, precipitation, snowfall and wind, plus at least one plain-language reason for the score.
- **FR-009**: Scoring MUST be deterministic: the same weather input always produces the same scores, labels and ranking.
- **FR-010**: Scoring MUST follow these suitability rules:
  - **Skiing** rises with fresh snowfall or existing snow cover and cold temperatures (at or below freezing); falls with strong wind, rain, or temperatures above freezing; is Poor when there is no snow and it is above freezing.
  - **Surfing** rises with moderate wind, mild-to-warm temperatures and dry conditions; falls with thunderstorms, very strong wind or cold. A note MUST state that wave conditions are not included.
  - **Outdoor sightseeing** rises with dry, comfortable temperatures (about 15–25 °C), light wind and sunshine; falls with rain, snow, strong wind, or extreme heat or cold.
  - **Indoor sightseeing** never drops below Fair and rises as outdoor conditions get worse.
- **FR-011**: The system MUST show a loading state while searching or loading the forecast, a "No places found" state for empty results, and an error state with a Retry action for connection or service failures.
- **FR-012**: When search text changes, results for older text MUST NOT replace results for newer text.
- **FR-013**: Missing days or missing weather values MUST be shown as "No data" and excluded from the weekly average rather than scored as zero.
- **FR-014**: The app MUST NOT require an account and MUST NOT collect or store personal data; nothing persists after the app is closed.
- **FR-015**: All text MUST support the device's larger text sizes, and ratings MUST be readable by screen readers (e.g. "Skiing, Tuesday, Excellent, 82").
- **FR-016**: Values MUST be shown in metric units (°C, mm, cm, km/h).

### Key Entities

- **Place**: a city or town the user can select. Name, region, country, geographic position, local time zone.
- **Daily Weather**: the forecast for one day at a place. Date, minimum and maximum temperature, precipitation amount, snowfall, snow cover, maximum wind speed, general condition (e.g. clear, rain, thunderstorm), sunshine duration.
- **Activity Suitability**: one activity on one day. Activity, date, score (0–100), label, reasons.
- **Activity Ranking**: one activity across the week. Activity, weekly score, best day, rank position, and its seven Activity Suitability entries.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A first-time user can go from opening the app to seeing a ranked week for a known city in under 30 seconds and no more than 3 interactions (type, select, view).
- **SC-002**: Ranked results appear within 3 seconds of selecting a place on a typical mobile connection.
- **SC-003**: For a fixed set of reference weekly forecasts, the top-ranked activity matches the expected one in 100% of cases: snowy alpine week → Skiing; rainy city week → Indoor sightseeing; dry, 20 °C sunny week → Outdoor sightseeing; mild, breezy, dry coastal week → Surfing ranks above Skiing.
- **SC-004**: Every tested failure (offline, service error, no results, partial data) shows an understandable message, and every recoverable failure can be retried without restarting the app.
- **SC-005**: In a walkthrough, a first-time user can correctly explain why the top activity ranked first using only on-screen information.
- **SC-006**: Every daily rating is announced meaningfully by a screen reader, and no text is cut off at the largest standard text size.

## Assumptions

- The product is a native iOS app (the platform choice is fixed in `intent.md`), built with a layered MVVM architecture (see Clarifications). The technology stack is decided during planning.
- Scoring and ranking rules (FR-004 to FR-010, FR-013) are independent of any screen, so they can be checked on their own against the reference forecasts in SC-003.
- Work proceeds test-first. Each acceptance scenario and edge case that does not depend on visual layout has an automated test written before the behaviour exists. The commit history shows each failing test landing before the code that makes it pass.
- Weather and place search come from Open-Meteo's place-search and forecast services, as the brief requires. They are free, need no key, and have no backend in between.
- The forecast service provides no wave or swell data, and the brief limits data sources to those two services, so Surfing is a weather-only estimate and is labelled as such.
- An internet connection is required. There is no offline mode, cache, favourites or search history (out of scope to keep the submission focused).
- Single anonymous user, English only, metric units.
- "Rank" means ordering the activities by weekly suitability while also showing per-day ratings, so both "which activity" and "which day" questions are answered.
- Exact scoring weights and thresholds within the rules in FR-010 are tuned during planning and documented in the README, and the reference forecasts in SC-003 are used to verify them.
