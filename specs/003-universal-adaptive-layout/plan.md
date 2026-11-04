# Implementation Plan: Universal App with Adaptive Layouts

**Branch**: `003-universal-adaptive-layout` | **Date**: 2026-11-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-universal-adaptive-layout/spec.md`

## Summary

Make the app universal (iPhone + iPad) and let the layout follow the window's width class:

- **Wide windows** (iPad full screen, wide Split View or Stage Manager, iPhone Duo inner display) show search results and the selected place's forecast side by side.
- **Narrow windows** keep today's push flow.
- The day detail stays a sheet everywhere (FR-012).

Technical approach:

- A `NavigationSplitView` replaces the root `NavigationStack`. It collapses to a stack in compact width by itself, so one view hierarchy covers both layouts.
- Navigation state (search, selected place, forecast, open day) moves out of view-local `@State` into a new `@MainActor @Observable BrowseModel` in `ForecastKit`, written test-first.
- `ForecastModel.loadIfNeeded()` and an idempotent `SearchModel.search()` stop columns rebuilt on resize from fetching again (FR-007). The package moves to the Swift 6.4 toolchain (R9).
- Project settings turn on iPad and multitasking.
- Per the constitution's Quality Gates, this feature also adds `.swiftlint.yml` and makes the codebase pass `swiftlint lint --strict`. See [research.md](./research.md) R1–R9.

## Technical Context

**Language/Version**: Swift 6.4 toolchain (`swift-tools-version: 6.4`, Xcode 27.2), Swift 6 language mode (`SWIFT_VERSION = 6.0` is the language-mode setting). See research R9.

**Primary Dependencies**: SwiftUI (`NavigationSplitView`, `List(selection:)`), Observation. No new packages. SwiftLint (Homebrew, dev-only) for the lint gate.

**Storage**: none. Navigation state is in memory for the session (constitution: no persistence).

**Testing**: Swift Testing in `ForecastKitTests`, test-first for `BrowseModel` and the `ForecastModel` additions. Views are checked with previews, the simulator build and the manual matrix in [quickstart.md](./quickstart.md).

**Target Platform**: iOS 18.0+, universal (`TARGETED_DEVICE_FAMILY = 1,2`). Verified on the iPhone 16, iPhone Duo and iPad simulators.

**Project Type**: mobile app (iOS), no backend.

**Performance Goals**: a window resize or fold causes no network request and no visible reload. The layout reflows within a frame.

**Constraints**: the layout is chosen by size class only, never by device model (FR-004). VoiceOver wording is unchanged (FR-009). Scores are identical on every device (FR-011).

**Scale/Scope**: 1 new model (+ tests), 2 models extended, 1 tools-version bump, 4 view files reworked, 1 project-settings change, 1 lint config plus lint fixes.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution v1.1.1 (`.specify/memory/constitution.md`).

| Principle / Gate | Status |
|---|---|
| I. Full Swift Concurrency Safety | ✅ `BrowseModel` is `@MainActor @Observable`, holding only `Sendable` values and main-actor models. No `@unchecked Sendable` / `nonisolated(unsafe)` in production code. Async work stays in `.task` (structured, cancelled with the view) |
| II. Latest Swift Toolchain | ✅ `swift-tools-version` raised to 6.4 in this feature. Language mode stays Swift 6 (`SWIFT_VERSION = 6.0`), exactly as Principle II requires since v1.1.1 (research R9) |
| III. Adaptive Layout: iPhone, iPhone Duo, iPad | ✅ This feature implements it: size-class-driven split view, native iPad, all multitasking sizes, state kept across resize |
| IV. Test-First Domain Logic | ✅ `BrowseModelTests` and the new `ForecastModelTests` cases are written red before the code. View changes are exempt and verified by quickstart |
| V. Focused Scope and Layered Simplicity | ✅ One new model, needed to own the FR-007 invariant. `App` stays views-only. No new runtime dependencies |
| Quality Gates (lint, tests, build, Duo + iPad check) | ✅ `.swiftlint.yml` added here; all three gates plus the layout matrix are run before the PR (quickstart.md) |

**Post-design re-check (after Phase 1)**: passes with no exceptions.

## Project Structure

### Documentation (this feature)

```text
specs/003-universal-adaptive-layout/
├── plan.md              # This file
├── research.md          # Phase 0: decisions R1–R9
├── data-model.md        # Phase 1: BrowseModel, ForecastModel additions, state transitions
├── quickstart.md        # Phase 1: gates + device/window matrix
├── contracts/ui.md      # Phase 1: wide vs narrow layout contract
└── tasks.md             # Phase 2 (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
.swiftlint.yml                                   # NEW: tuned rules, justified exceptions (R8)
ActivityForecast.xcodeproj/project.pbxproj       # CHANGED: TARGETED_DEVICE_FAMILY = "1,2", iPad orientations (R6)
App/
├── ActivityForecastApp.swift                    # CHANGED: creates one BrowseModel, root = RootView
├── RootView.swift                               # NEW: NavigationSplitView (sidebar SearchView, detail forecast or placeholder)
├── Search/SearchView.swift                      # CHANGED: List(selection:) bound to BrowseModel; no navigationDestination
└── Forecast/ForecastView.swift                  # CHANGED: takes ForecastModel; .task → loadIfNeeded(); sheet bound to model.selectedDay
Packages/ForecastKit/
├── Package.swift                                       # CHANGED: swift-tools-version 6.4 (R9)
├── Sources/ForecastKit/Features/BrowseModel.swift      # NEW (test-first)
├── Sources/ForecastKit/Features/ForecastModel.swift    # CHANGED: selectedDay, loadIfNeeded()
├── Sources/ForecastKit/Features/SearchModel.swift      # CHANGED: no repeat request for an unchanged query (R3)
└── Tests/ForecastKitTests/BrowseModelTests.swift       # NEW
    Tests/ForecastKitTests/ForecastModelTests.swift     # CHANGED: loadIfNeeded / selectedDay cases
    Tests/ForecastKitTests/SearchModelTests.swift       # CHANGED: repeat-query cases
(+ lint fixes across existing App/ and ForecastKit files, no behaviour change)
```

**Structure Decision**: same two-layer layout as feature 001 (`App` views → `ForecastKit`). `BrowseModel` sits in `ForecastKit/Features` beside the other screen models so it can be tested with `swift test`.

## Complexity Tracking

No violations. Nothing to justify.
