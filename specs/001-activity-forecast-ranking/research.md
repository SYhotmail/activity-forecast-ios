# Research: Activity Forecast Ranking

Phase 0 output for [plan.md](./plan.md). Each entry gives the decision, why it was made, and what else was considered.
Facts about the Open-Meteo APIs were checked against the live endpoints on 2026-11-03 (see [contracts/open-meteo.md](./contracts/open-meteo.md)).

## R1. UI framework and minimum iOS version

- **Decision**: SwiftUI, minimum iOS 18.0, Swift 6 language mode with strict concurrency.
- **Rationale**: SwiftUI with `@Observable` gives the least boilerplate for three screens. iOS 18 still lets reviewers on Xcode 16 build the project, and it covers almost every device in use. Swift 6 strict concurrency catches data races at compile time, which matters because search requests are cancelled and replaced while the user types.
- **Alternatives considered**: UIKit, which needs more code and gives no benefit for this scope. iOS 26 or 27 minimum, which would lock out reviewers on older Xcode for little API gain. The Swift 5 language mode, which hides concurrency bugs.

## R2. Project layout and modularisation

- **Decision**: a thin iOS app target (views only) plus one local Swift package, `ForecastKit`, that holds the domain models, the scoring engine, the Open-Meteo client and the `@Observable` view models.
- **Rationale**: all logic worth testing runs with `swift test` on macOS in seconds, with no simulator. The package boundary keeps SwiftUI views from reaching into networking. One package is enough; splitting it further (Domain, Networking, Features) would be ceremony at this size.
- **Alternatives considered**: everything in the app target, where tests need the simulator and boundaries rest on discipline alone. Several packages, too much structure for roughly 15 source files.

## R3. Xcode project

- **Decision**: a native `ActivityForecast.xcodeproj`, created and maintained in Xcode (clarified 2026-11-03). It uses file-system synchronised groups (Xcode 16+), so adding a file to `App/` doesn't touch `project.pbxproj`. The local `ForecastKit` package is added as a package reference.
- **Rationale**: this is the format reviewers expect: open it and run, with no tools to install and no generated-file drift. Synchronised groups remove most pbxproj merge noise, the main historical reason for generators.
- **Alternatives considered**: XcodeGen (`project.yml` plus a generated project), dropped at the user's direction because it adds a tool and two sources of truth. Tuist, heavier and not installed. A package-only app, since an iOS app target still needs a project.
## R4. Networking and third-party dependencies

- **Decision**: `URLSession` async/await with `Codable`. **No third-party dependencies.**
- **Rationale**: there are two GET endpoints with small JSON payloads. The standard library covers it, and zero dependencies means nothing to vet or update.
- **Alternatives considered**: Alamofire, or an OpenAPI generator. Both add surface with no benefit at two endpoints.

## R5. State management and stale search results (FR-011, FR-012)

- **Decision**: two `@MainActor @Observable` models. `SearchModel` holds the query and a `LoadState<[Place]>`. `ForecastModel` holds the place and a `LoadState<WeeklyRanking>`. Search is driven from the view with `.task(id: query)`: wait 300 ms (debounce), then fetch. SwiftUI cancels the previous task whenever the query changes, so a stale response can never be applied. The model also checks `Task.isCancelled` before assigning.
- **Rationale**: structured concurrency ties request lifetime to the UI. There is no Combine, no manual task bookkeeping, and no race between responses. One explicit state enum per screen makes the loading, empty and error states exhaustive in `switch`.
- **Alternatives considered**: Combine `debounce` plus `switchToLatest`, more machinery and a second concurrency model. One app-wide store, which would couple two screens that have no shared state.

## R6. Dependency seam for tests

- **Decision**: a `WeatherService` protocol (`searchPlaces(_:)`, `forecast(for:)`). `OpenMeteoClient` is the real implementation. Tests use an in-memory stub. Client decoding is tested separately with a `URLProtocol` stub serving recorded JSON fixtures.
- **Rationale**: the models need a fake to test loading, error and retry flows without the network. That is a real second implementation, not a speculative abstraction.
- **Alternatives considered**: closures injected into the models, which work too but read worse at call sites. Hitting the live API in tests, which is flaky and not deterministic.

## R7. Weather data requested

- **Decision**: one forecast request per place:
  - `daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,rain_sum,snowfall_sum,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,sunshine_duration`
  - `hourly=snow_depth`, reduced to a daily maximum and converted from m to cm
  - `timezone=auto`, `forecast_days=7`
- **Rationale**: these are exactly the inputs the scoring rules in FR-010 need. `timezone=auto` returns dates already in the place's local time zone, which satisfies FR-009 with no client-side time-zone maths. Snow depth only exists as an hourly variable, and skiing needs "existing snow cover".
- **Alternatives considered**: the Marine API for wave height, excluded because the brief limits sources to Geocoding + Forecast (see intent.md). Doing it would be a one-endpoint extension noted in the README. Hourly scoring, more precise but harder to explain than one rating per day.

## R8. Geocoding parameters

- **Decision**: `search?name=<query>&count=10&language=en&format=json`. Show `name`, `admin1` (optional) and `country`. A missing `results` key means no matches.
- **Rationale**: verified live, an unknown name returns only `generationtime_ms`. Region and country tell "Paris, Île-de-France Region, France" apart from "Paris, Texas, United States" (FR-002).

## R9. Scoring model (FR-004, FR-005, FR-010)

- **Decision**: each activity is a **weighted sum of normalised factors** (each factor maps to 0…1 through piecewise-linear ramps), multiplied by 100, rounded and clamped to 0…100. Hard **caps** apply for disqualifying conditions. Starting weights, to be fixed by the reference-forecast tests:

| Activity | Factors (weight) | Caps |
|---|---|---|
| Skiing | snow = min(1, snowfall_cm/10 + depth_cm/100) (50); cold: tmax ≤0 °C → 1, ≥5 °C → 0 (25); wind: gusts ≤30 → 1, ≥70 km/h → 0 (15); no rain: 1 − min(rain_mm/10, 1) (10) | no snowfall and no depth and tmin > 0 °C → max 10 |
| Surfing | wind: 0 km/h → 0.3, 15–35 → 1, ≥50 → 0 (40); warmth: tmax ≤5 → 0, 18–30 → 1, ≥38 → 0.5 (30); dry: 1 − min(precip_mm/10, 1) (30) | thunderstorm (WMO 95–99) → max 10 |
| Outdoor sightseeing | comfort: tmax ≤0 or ≥38 → 0, 15–25 → 1 (35); dry: 1 − max(min(precip_mm/10, 1), precip_prob/100 × 0.5) (35); calm: wind ≤20 → 1, ≥50 → 0 (15); sun: min(sunshine_h/8, 1) (15) | thunderstorm or snowfall ≥ 2 cm → max 20 |
| Indoor sightseeing | 30 + 0.6 × (100 − outdoor score) | always within 30…90, so never below Fair |

- **Weekly score** = mean of the days that have data. **Rank** = weekly score descending, then best-day score, then the fixed activity order. **Best day** = highest score, earliest if tied.
- **Reasons** (FR-008): each factor carries a positive and a negative phrase. A day shows its biggest negative contributor (weight × (1 − value)) when that factor is below 0.4, and its biggest positive contributor when one is at or above 0.8. A cap, when applied, is always the first reason.
- **Rationale**: transparent, deterministic (FR-009), explainable in one sentence per factor, and easy to unit-test at each threshold. Indoor is derived from outdoor because that is literally its meaning ("go inside when it's bad out"). The 30–90 band keeps it below a genuinely great skiing or outdoor week.
- **Sanity check against SC-003** (hand-computed with the weights above; a first draft failed here, see note):
  - Snowy alpine (20 cm snowfall, 80 cm depth, −5 °C, gusts 25 km/h): skiing = 50 + 25 + 15 + 10 = **100**. Outdoor raw ≈ 15 (capped at 20). Indoor = 30 + 0.6 × 85 = 81 → **Skiing** first.
  - Rainy city (12 mm, tmax 11 °C, wind 20 km/h, no sun): outdoor = 25.7 + 0 + 15 + 0 ≈ 41, so indoor = 30 + 0.6 × 59 ≈ **65**. Surfing = 40 + 30 × 0.46 + 0 ≈ 54. Skiing ≤ 10 → **Indoor** first.
  - Sunny 20 °C, dry, wind 10 km/h, 9 h sun: outdoor = **100**, surfing ≈ 31 + 30 + 30 = 91, indoor = 30 → **Outdoor**.
  - Mild breezy coast (22 °C, 25 km/h, dry): surfing = **100**, skiing ≤ 10 → **Surfing** above Skiing.
  - *Note*: the first draft (surfing weights 45/35/20, indoor 25 + 0.5 × …) scored the rainy city as surfing 61 against indoor 55, which broke SC-003. That is why the reference weeks are encoded as tests rather than trusted from reasoning.
- **Alternatives considered**: a rule table (if/else bands), simple but jumpy at boundaries and harder to explain. Machine-learned or crowd-sourced weights, which have no data and can't be checked. User-adjustable weights, out of scope (speculative).

## R10. Testing approach

- **Decision**: **test-driven development** (clarified 2026-11-03) with Swift Testing (`@Test`, `#expect`, parameterised tests) in the `ForecastKit` test target. Each item below is written as a failing test before the code it covers (workflow in [plan.md](./plan.md#development-workflow-tdd)):
  - **Scorer tests**: factor ramps at each threshold, caps, and the indoor floor and ceiling.
  - **Ranking tests**: the SC-003 reference weeks built in code, tie-breaks, best day, and missing-data exclusion (FR-013).
  - **Client tests**: decode the recorded Geocoding and Forecast JSON fixtures, including the "no results" shape and null values; check how hourly snow depth reduces to a daily figure.
  - **Model tests**: state transitions, error → retry, and cancellation of stale searches with the stub service.
  - **UI verification**: a manual run-through on the simulator per [quickstart.md](./quickstart.md), plus SwiftUI previews fed by stub data for each state. No XCUITest suite, which costs a lot to keep up for three screens.
- **Rationale**: TDD fits naturally here because the spec already states its behaviour as testable rules (thresholds, caps, tie-breaks, states), and it puts the brief's "verification" emphasis into practice. A fast package suite (no simulator) keeps the red → green loop to seconds. Tests go where the logic and risk are (scoring, decoding, state). They run without a simulator, so reviewers can check them with one command.
- **Alternatives considered**: XCTest, which works but is older and wordier. Snapshot tests, which add a third-party dependency.

## R11. Accessibility and units (FR-015, FR-016)

- **Decision**: system text styles only (Dynamic Type). Each day cell gets a combined accessibility label: "Skiing, Tuesday 4 November, Excellent, 82". Rating colour is always paired with a text label. Metric values are formatted with `Measurement` and `FormatStyle` in a fixed metric unit.
- **Rationale**: meets FR-015 without custom infrastructure. Colour alone would fail colour-blind users.

## R12. Known data limitation: model elevation

- **Finding**: the forecast is computed at the grid-cell elevation (Chamonix returned an elevation of 1034 m), not at ski-resort altitude, so it can understate snow conditions on the mountain.
- **Decision**: accept it and document it in the README. Passing the resort's summit elevation would need data we don't have.

## R13. Architectural pattern

- **Decision**: **layered MVVM**. SwiftUI views → `@Observable` screen view models → pure domain (models + scoring) → data layer (`WeatherService` / `OpenMeteoClient`). Dependencies are injected at one composition root. See [plan.md § Architecture](./plan.md#architecture).
- **Rationale**: this is the idiomatic shape for SwiftUI with Observation and needs no framework. View models make the screen logic (debounce, cancellation, retry, error states) unit-testable without a simulator. Keeping scoring pure makes the core "how suitable is it" rules deterministic and testable on their own (FR-009, SC-003). It also matches the existing package layout without any new layers.
- **Alternatives considered**:
  - TCA: very testable, but a large third-party dependency and steep conventions for three screens.
  - Clean Architecture / VIPER: use cases, repositories and routers would each wrap one call, which is indirection with no payoff here.
  - MV (views own stores directly): least code, but screen logic sits inside views and is hard to test.
