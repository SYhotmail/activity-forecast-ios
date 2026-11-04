# Research: View Models Live in the App

Format: Decision / Rationale / Alternatives considered.

## R1. What moves, what stays
- **Decision**:
  - Move `LoadState`, `SearchModel`, `ForecastModel`, `BrowseModel` to `App/Features/` and make them `internal` (drop `public`).
  - Keep `UserFacingError` in `ForecastKit`, moving it from `Features/LoadState.swift` to `Service/UserFacingError.swift`.
- **Rationale**: `WeatherService`, `OpenMeteoClient` and `OpenMeteoDTOs` throw `UserFacingError`, so it belongs to the data layer (constitution V). `LoadState` is screen state, used only by view models and `LoadStateView`.
- **Alternatives**: move `UserFacingError` too (the data layer would then depend on the app, which is impossible); keep `LoadState` in the package as "shared" (violates V: screen state in `ForecastKit`).

## R2. Test-support library
- **Decision**: add product `.library(name: "ForecastKitTestSupport", targets: ["ForecastKitTestSupport"])` with target `ForecastKitTestSupport` depending on `ForecastKit`. It contains `StubWeatherService`, `Gate` and `Recorder`, made `public` with public initialisers.
- **Rationale**: spec Q1 and constitution V. One shared fake for app tests and app previews, so there's no duplicate. `Gate` and `Recorder` are only used by the view-model tests, which move to the app, so they move with them into the shared library instead of being copied.
- **Alternatives**: duplicate the stub in the app and in package tests (rejected in Q1); keep `Gate`/`Recorder` in `Tests/Support` (unreachable from the app test target).

## R3. "Release app must not link it" (FR-004)
- **Decision**: the `ActivityForecast` target lists `ForecastKitTestSupport` as a package product dependency. The only app source that imports it is `PreviewData.swift`. There are no `#if DEBUG` wrappers (removed 2026-11-04 at the owner's request): `#Preview` macros are compiled out of Release builds, and `PreviewData` is then unreferenced and dead-stripped. A Release build after the wrappers were removed has 0 `PreviewData` and 0 preview symbols. SwiftPM libraries are static by default, and the linker drops unreferenced code. Today's Release binary still has `StubWeatherService` symbols, the same count as before the wrappers were removed, because the stub lives in the `ForecastKit` module; moving it out (T006) is what removes them. Verified by `nm` on the Release build: no `StubWeatherService`, `Gate` or `Recorder` symbols (quickstart Gate 5).
- **Rationale**: Xcode can't attach a package product to one build configuration only. The binary check is the real proof of "not in the shipped app".
- **Alternatives**: a separate preview-only target (Xcode doesn't support configuration-specific product links cleanly); `DEVELOPMENT_ASSET_PATHS` (it's for assets, not code); a dynamic library (would ship as a framework in Release, which is worse).

## R4. App unit-test target
- **Decision**: a new hosted unit-test bundle `ActivityForecastTests`:
  - product type `com.apple.product-type.bundle.unit-test`;
  - `TEST_HOST = $(BUILT_PRODUCTS_DIR)/ActivityForecast.app/ActivityForecast`, `BUNDLE_LOADER = $(TEST_HOST)`;
  - Swift 6 mode, iOS 18.0, `GENERATE_INFOPLIST_FILE = YES`;
  - a file-system-synchronized group `AppTests/`;
  - depends on the app target, and links `ForecastKit` and `ForecastKitTestSupport`.

  Tests use `import Testing`, `@testable import ActivityForecast`, `import ForecastKit`, `import ForecastKitTestSupport`. Add it to the scheme's Test action next to `ForecastKitTests`.
- **Rationale**: spec Q2 and constitution IV. A hosted bundle makes `@testable import` of the app module possible. A synchronized group matches the existing `App/` group, so new test files need no project edits.
- **Alternatives**: a non-hosted logic-test bundle compiling app sources directly (duplicate membership, fragile); UI tests (wrong level).

## R5. Moving the tests without changing behaviour
- **Decision**: move the three suites with `git mv`, then change only their imports (`@testable import ForecastKit` becomes `@testable import ActivityForecast` + `import ForecastKit` + `import ForecastKitTestSupport`). Assertions are untouched. Proof: compare the test-function names before and after; the set of 39 names must be identical (quickstart Gate 6).
- **Rationale**: spec FR-006, SC-002, and the edge case "a test that needs editing signals an unintended change".

## R6. Order of work, keeping everything green
- **Decision**:
  1. Create `ForecastKitTestSupport` and move the stub, `Gate` and `Recorder` there. Package VM tests import it, and everything is green.
  2. Add the empty `ActivityForecastTests` target and scheme entry. Green.
  3. Move the view models and `LoadState` to the app, `UserFacingError` to `Service/`, and the VM tests to `AppTests/`, in one commit (they can't compile apart). Green on both test commands.
  4. Docs.
- **Rationale**: each commit builds and passes. Step 3 has to be atomic because the tests must move with the types they reference.

## R7. Previews
- **Decision**: `PreviewData.swift` and all `#Preview` blocks have no `#if DEBUG` wrapper. `PreviewData.swift` adds `import ForecastKitTestSupport`. Views construct the app-internal view models as today.
- **Rationale**: FR-005. Xcode strips `#Preview` code from Release, and preview-only data is dead-stripped, so the wrappers added noise without protecting anything (verified by building Release before and after).
