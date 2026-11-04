# Implementation Plan: View Models Live in the App

**Branch**: `004-viewmodels-in-app` | **Date**: 2026-11-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-viewmodels-in-app/spec.md`

## Summary

A structural refactor to meet constitution v2.0.0 (Principles IV and V). Nothing changes for the end user.

1. `SearchModel`, `ForecastModel`, `BrowseModel` and `LoadState` move from `ForecastKit/Features` into the app (`App/Features/`) and become `internal`.
2. `UserFacingError`, which the data layer throws, stays in `ForecastKit` in its own file under `Service/`.
3. `StubWeatherService`, `Gate` and `Recorder` move into a new developer-only package library, **`ForecastKitTestSupport`**. It is linked by the new app test target and by the app (for SwiftUI previews only; `#Preview` code and preview data are stripped from Release). A static library that release code never references contributes no code to the release binary, and this is verified with `nm`.
4. A new hosted app unit-test target, **`ActivityForecastTests`**, receives the 39 view-model test functions unchanged and runs on a simulator. It is added to the `ActivityForecast` scheme's Test action, beside `ForecastKitTests`.

See [research.md](./research.md) R1–R7.

## Technical Context

**Language/Version**: Swift 6.4 toolchain (`swift-tools-version: 6.4`), Swift 6 language mode, Xcode 27.2.

**Primary Dependencies**: SwiftUI, Observation, Swift Testing. No new third-party code. `ForecastKitTestSupport` is a local, developer-only library.

**Storage**: N/A.

**Testing**:
- Package: `swift test` (domain, scoring, data; no simulator).
- App: `xcodebuild test -scheme ActivityForecast -destination 'platform=iOS Simulator,name=iPhone 16'` runs `ForecastKitTests` plus the new `ActivityForecastTests`.
- Expectations are unchanged. Tests are moved, not rewritten.

**Target Platform**: iOS 18.0+, universal (unchanged).

**Project Type**: mobile app + local Swift package.

**Performance Goals**: N/A (no runtime change).

**Constraints**:
- No behaviour change (FR-008).
- The release app must contain no test-support code (FR-004).
- The package's production product exposes only domain, scoring and data (FR-001, SC-001).

**Scale/Scope**:
- 4 types moved to the app, 1 type relocated within the package, 3 test helpers moved to a new library.
- 3 test files (39 test functions) moved to a new app test target.
- Project, scheme, `Package.swift`, README and `CLAUDE.md` updated.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution v2.0.0.

| Principle / Gate | Status |
|---|---|
| I. Concurrency | ✅ View models stay `@MainActor @Observable`. `Gate`/`Recorder` are `Sendable` as today. No new unsafe escapes |
| II. Toolchain | ✅ Unchanged (tools 6.4, Swift 6 mode). The new test target uses Swift 6 mode |
| III. Adaptive layout | ✅ No layout change. The 003 quickstart is re-run to prove it (SC-004) |
| IV. Test-First Logic | ✅ This is a move, not new behaviour: the 39 view-model tests move verbatim and must pass in the app test target before and after each step. No behaviour is added, so no new red/green pair is due. Package tests keep running with `swift test` |
| V. Layering | ✅ This feature implements it: the app owns views and view models, `ForecastKit` owns domain, scoring and data, and test doubles live in `ForecastKitTestSupport` (developer-only) |
| Quality gates 1–4 | ✅ lint, `swift test`, `xcodebuild test` (new gate 3), clean build. All run before the PR |

**Post-design re-check (after Phase 1)**: passes. Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/004-viewmodels-in-app/
├── plan.md
├── research.md              # R1–R7
├── data-model.md            # what moves where; public surface before/after
├── quickstart.md            # gates + release-binary symbol check + 001/003 smoke
├── contracts/forecastkit-api.md   # public API of ForecastKit and ForecastKitTestSupport
└── tasks.md                 # /speckit-tasks
```

### Source Code (repository root)

```text
Packages/ForecastKit/
├── Package.swift                                   # CHANGED: + library ForecastKitTestSupport (target depends on ForecastKit)
├── Sources/ForecastKit/
│   ├── Features/                                   # REMOVED (all four files move to the app)
│   └── Service/UserFacingError.swift               # NEW (moved out of Features/LoadState.swift)
│       Service/StubWeatherService.swift            # REMOVED (moves to ForecastKitTestSupport)
├── Sources/ForecastKitTestSupport/                 # NEW
│   ├── StubWeatherService.swift                    # public, from ForecastKit
│   ├── Gate.swift                                  # public, from Tests/Support
│   └── Recorder.swift                              # public, from Tests/Support
└── Tests/ForecastKitTests/
    ├── SearchModelTests.swift, ForecastModelTests.swift, BrowseModelTests.swift   # REMOVED (move to app)
    └── Support/StubURLProtocol.swift               # unchanged (client tests only)
App/
├── Features/                                       # NEW: LoadState, SearchModel, ForecastModel, BrowseModel (internal)
├── Shared/PreviewData.swift                        # CHANGED: `import ForecastKitTestSupport` (no #if DEBUG; previews stripped in Release)
└── … views unchanged apart from imports
AppTests/                                           # NEW synchronized group → target ActivityForecastTests
├── SearchModelTests.swift, ForecastModelTests.swift, BrowseModelTests.swift   # moved verbatim; imports changed
ActivityForecast.xcodeproj/project.pbxproj          # CHANGED: test target, TestSupport product on app + tests
ActivityForecast.xcodeproj/xcshareddata/xcschemes/ActivityForecast.xcscheme   # CHANGED: + ActivityForecastTests testable
README.md, CLAUDE.md                                # CHANGED: layering + test commands (FR-010)
```

**Structure Decision**: same two-part repo (app + one local package). The package gains a second library product and the app gains a test target, as required by Principles IV and V and clarified in spec Q1/Q2.

## Complexity Tracking

No violations. Nothing to justify.
