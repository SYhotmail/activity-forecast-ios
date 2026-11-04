# Research: View Models Live in the App

Format: Decision / Rationale / Alternatives considered.

## R1. What moves, what stays
- **Decision**:
  - Move `LoadState`, `SearchModel`, `ForecastModel`, `BrowseModel` to `App/Features/` and make them `internal` (drop `public`).
  - Keep `UserFacingError` in `ForecastKit`, moving it from `Features/LoadState.swift` to `Service/UserFacingError.swift`.
- **Rationale**: `WeatherService`, `OpenMeteoClient` and `OpenMeteoDTOs` throw `UserFacingError`, so it belongs to the data layer (constitution V). `LoadState` is screen state, used only by view models and `LoadStateView`.
- **Alternatives**: move `UserFacingError` too (the data layer would then depend on the app, which is impossible); keep `LoadState` in the package as "shared" (violates V: screen state in `ForecastKit`).

## R2. Where test doubles live (revised during implementation)
- **Decision**:
  - `StubWeatherService` lives in the app as an `internal` type (`App/Shared/StubWeatherService.swift`). SwiftUI previews and `ActivityForecastTests` share it, the tests through `@testable import ActivityForecast`.
  - `Gate` and `Recorder` live in the test target (`AppTests/Support/`).
  - Previews and `PreviewData` have no `#if DEBUG` (R7, constitution 2.2.0).
  - There is no test-support package library (constitution 2.1.0).
- **Rationale**: the first design, a `ForecastKitTestSupport` library linked by both the app (for previews) and the test target, failed two checks:
  1. The Release binary contained 78 `StubWeatherService`, 52 `Gate` and 54 `Recorder` symbols. Swift keeps protocol-conformance records, so linking the library ships it even when release code never calls it.
  2. Linking one package product from two targets made Xcode package it as a dynamic framework that embeds its own copy of `ForecastKit`. The test run logged "Class … is implemented in both …", a risk for dynamic casts such as `as? UserFacingError`.

  One `internal` copy in the app fixes both: Release has 0 such symbols (unused internal code is removed by whole-module optimisation, which can't happen for `public` code in another module), `ForecastKit` is linked once, and the test target links no package products.
- **Alternatives**: make `ForecastKit` a dynamic framework and link the support library into the app for Debug only (fragile: Xcode has no per-configuration package links; adds embedded frameworks); accept the doubles in Release (breaks constitution V).

## R3. Proving the release app has no test doubles (FR-004)
- **Decision**: build Release and run `nm` on the app binary. There must be 0 `StubWeatherService`, `Gate`, `Recorder` and `PreviewData` symbols, and no embedded frameworks (quickstart #5). Verified on 2026-11-04 both with and without `#if DEBUG` around previews: all 0.
- **Rationale**: the binary is the real proof. Assumptions about dead-stripping turned out to be wrong (R2).

## R4. App unit-test target
- **Decision**: a new hosted unit-test bundle `ActivityForecastTests`:
  - product type `com.apple.product-type.bundle.unit-test`;
  - `TEST_HOST = $(BUILT_PRODUCTS_DIR)/ActivityForecast.app/ActivityForecast`, `BUNDLE_LOADER = $(TEST_HOST)`;
  - Swift 6 mode, iOS 18.0, `GENERATE_INFOPLIST_FILE = YES`;
  - a file-system-synchronized group `AppTests/`;
  - depends on the app target, and links `ForecastKit` and `ForecastKitTestSupport`.

  Tests use `import Testing`, `import ForecastKit` and `@testable import ActivityForecast`. The test target links no package products: `ForecastKit` symbols resolve from the host app through `BUNDLE_LOADER`, which keeps one copy at runtime. Add it to the scheme's Test action next to `ForecastKitTests`.
- **Rationale**: spec Q2 and constitution IV. A hosted bundle makes `@testable import` of the app module possible. A synchronized group matches the existing `App/` group, so new test files need no project edits.
- **Alternatives**: a non-hosted logic-test bundle compiling app sources directly (duplicate membership, fragile); UI tests (wrong level).

## R5. Moving the tests without changing behaviour
- **Decision**: move the three suites with `git mv`, then change only their imports (`@testable import ForecastKit` becomes `import ForecastKit` + `@testable import ActivityForecast`). Assertions are untouched. Proof: compare the test-function names before and after; the set of 39 names must be identical (quickstart Gate 6).
- **Rationale**: spec FR-006, SC-002, and the edge case "a test that needs editing signals an unintended change".

## R6. Order of work, keeping everything green
- **Decision**:
  1. Add the empty `ActivityForecastTests` target and scheme entry. Green.
  2. In one commit, move the stub (Debug-only, into the app), `Gate`/`Recorder` (into `AppTests/Support`), the view models and `LoadState` (into the app), `UserFacingError` (to `Service/`) and the VM tests (to `AppTests/`). They can't compile apart. Green on both test commands.
  3. Docs.
- **Rationale**: each commit builds and passes. Step 3 has to be atomic because the tests must move with the types they reference.

## R7. Previews
- **Decision**: no `#if DEBUG` around `#Preview` blocks, `PreviewData` or `StubWeatherService` (owner's request, constitution 2.2.0). Preview helpers take `any WeatherService`, not the concrete stub.
- **Rationale**: `#Preview` bodies are type-checked in Release, so their data must compile there. Because the fixtures are `internal` to the app module and nothing in production calls them, Release whole-module optimisation removes them. The Release binary has 0 `PreviewData` and 0 `StubWeatherService` symbols, the same result as with the wrappers. The `nm` check (quickstart #5) guards this on every change.
- **History**: the wrappers were briefly restored while the stub was a `public` type in a separate package library. Public code in another module can't be dead-stripped, which is where the 78 symbols came from.
