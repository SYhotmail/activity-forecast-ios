# Implementation Plan: Stricter MVVM in the App Layer

**Branch**: `refactoring-better-mvvm` | **Date**: 2026-11-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-mvvm-refactor/spec.md`

## Summary

A behaviour-preserving refactor of the app layer to a stricter MVVM shape:
1. **Renames and feature slices**: `…Model` → `…ViewModel`, `RootView` → `BrowseView`; each feature's view and view model share one folder. `LoadState` and `LoadStateView` move to `App/Views/LoadStateView/` (research R4).
2. **Selection in the view model**: `BrowseViewModel.selection` is a computed get/set over `select(_:)`, so the list binds `$browse.selection` directly (R1).
3. **Day sheet in the view model**: `ForecastViewModel.presentedDay: PresentedDay?` replaces `selectedDay`, and `showDetail(for:)` is the tap intent. The sheet binds `$model.presentedDay`, and the view's `DaySelection` and hand-written binding are deleted (R2, R3).
4. **Bug fix: the forecast owns its fetch (FR-012)**: a cancelled view `.task` no longer stops the request. `loadIfNeeded()` joins a fetch already in flight, and `BrowseViewModel.select` cancels the replaced forecast's request (R6).

The debounce stays in the view, there is no ViewData layer, and `ForecastKit` is unchanged.

## Technical Context

**Language/Version**: Swift 6.4 toolchain, Swift 6 language mode, Xcode 27. App target `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.

**Primary Dependencies**: SwiftUI, Observation, Swift Testing. Nothing new.

**Storage**: N/A.

**Testing**: the hosted `ActivityForecastTests` target (Swift Testing, simulator) for the view models; `swift test` for the package (unchanged).

**Target Platform**: iOS 18.0+, universal (iPhone, iPhone Duo, iPad).

**Project Type**: mobile app + local Swift package.

**Performance Goals**: N/A (no runtime change).

**Constraints**:
- No user-visible change (FR-009).
- The view-model test baseline is preserved (FR-010).
- No `project.pbxproj` edits: the groups are file-system-synchronised.

**Scale/Scope**:
- About 14 files moved or renamed.
- 3 test files renamed.
- 2 small view-model API additions with ≥ 5 new tests.
- 2 views simplified.
- CLAUDE.md and README updated.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution v2.2.0.

| Principle / Gate | Status |
|---|---|
| I. Concurrency | ⚠️ Justified exception (see Complexity Tracking): `ForecastViewModel` owns one unstructured fetch `Task` (FR-012). It is main-actor isolated, cancelled on deselect, retry or replace, and cancellation never surfaces as an error. Otherwise the view models stay main-actor `@Observable`, `PresentedDay` is a `nonisolated` `Sendable` value type, and there are no unsafe escapes |
| II. Toolchain | ✅ Unchanged |
| III. Adaptive layout | ✅ No layout change. The selection and sheet state stay in long-lived view models, so they still survive a fold or resize. The manual 003 checks are re-run (SC-005) |
| IV. Test-First Logic | ✅ The new behaviour (`selection`, `presentedDay`/`showDetail`) gets red → green pairs. The renames keep every existing test, with the same count (R5) |
| V. Layering / simplicity | ✅ App-only change. No new protocols, layers or libraries. `dismissDetail()` was dropped because nothing in production would call it (R3). Test doubles are untouched; the `nm` Release check is re-run because previews move |
| Quality gates 1–4 | ✅ Planned: lint, `swift test`, `xcodebuild test`, clean build (quickstart) |

**Post-design re-check**: ✅ passes with one recorded exception (Principle I, FR-012). The design adds one value type, two members for presentation and selection, and the fetch-ownership members (`cancel()`, a private `loadTask`). It removes one private type and two hand-written bindings.

## Project Structure

### Documentation (this feature)

```text
specs/005-mvvm-refactor/
├── spec.md
├── plan.md
├── research.md
├── data-model.md         # includes old → new name map
├── contracts/viewmodels.md
├── quickstart.md
├── checklists/requirements.md
└── tasks.md              # /speckit-tasks
```

### Source Code (repository root)

```text
App/
├── ActivityForecastApp.swift          # composition root: BrowseViewModel(service: OpenMeteoClient())
├── Features/
│   ├── Browse/   BrowseView.swift, BrowseViewModel.swift
│   ├── Search/   SearchView.swift, SearchViewModel.swift
│   └── Forecast/ ForecastView.swift, ForecastViewModel.swift, ActivitySection.swift, DayCell.swift, DayDetailView.swift
├── Views/
│   └── LoadStateView/ LoadState.swift, LoadStateView.swift
├── Shared/       Formatting.swift, PreviewData.swift, StubWeatherService.swift
└── (Assets, Info unchanged)
AppTests/
├── BrowseViewModelTests.swift, SearchViewModelTests.swift, ForecastViewModelTests.swift
└── Support/      Gate.swift, Recorder.swift
Packages/ForecastKit/                  # unchanged
```

**Structure Decision**: vertical feature slices under `App/Features/`, plus a dedicated folder for the shared load-state view (user request). The old `App/Search/` and `App/Forecast/` folders disappear.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Constitution I prefers structured concurrency; `ForecastViewModel` holds one unstructured `Task` for its fetch (FR-012, bug found in T022) | SwiftUI cancelled the forecast screen's `.task` with a stray disappear mid-push while the screen stayed visible, and nothing restarted the load: an endless spinner | Keeping the fetch in the view's `.task` is the bug itself. Retrying on `onAppear` depends on another SwiftUI event that did not arrive. The task is still cancelled on deselect, and cancellation still never surfaces as an error |
