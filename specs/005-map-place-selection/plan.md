# Implementation Plan: Select a Place on a Map

**Branch**: `005-map-place-selection` | **Date**: 2026-11-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-map-place-selection/spec.md`. User direction: "MapKit should be used".

## Summary

When the search text is empty, the sidebar shows a MapKit map instead of the idle hint. Tapping any point drops a marker, names the point after the nearest locality within 25 km (coordinates otherwise), and shows its forecast:

- **Wide windows**: the detail column updates as soon as the point is named.
- **Narrow windows**: a callout offers **Show forecast**, which pushes the detail.

Technical approach:

- **Data layer**: a new `PlaceLocating` protocol in ForecastKit with a live `MapKitPlaceLocator`. It uses `MKReverseGeocodingRequest` on iOS 26+ and `CLGeocoder` on iOS 18–25, and `MKLocalSearch` for the initial country region.
- **Domain**: a pure `MapSelection.place(at:nearest:)` applies the 25 km rule and builds coordinate-labelled places.
- **App view models**: a new `@Observable MapPickerModel`, owned by `BrowseModel`, keeps the camera and the pin across rebuilds. "Last tap wins" comes from `.task(id: pin)` with cancellation.
- **Narrow push**: driven by `NavigationSplitView`'s `preferredCompactColumn`.
- **Unchanged**: `OpenMeteoClient`, `WeatherService` and scoring.

See [research.md](./research.md) R1–R9.

## Technical Context

**Language/Version**: Swift 6.4 toolchain (`swift-tools-version: 6.4`, Xcode 27), Swift 6 language mode.

**Primary Dependencies**: SwiftUI, Observation, **MapKit** (`Map`, `MapReader`, `Marker`, `MKReverseGeocodingRequest`, `MKLocalSearch`) and CoreLocation (`CLGeocoder` fallback). All are Apple system frameworks; there are no packages and no API key.

**Storage**: none. Camera and pin are in memory for the session.

**Testing**: Swift Testing.
- `MapSelectionTests` in ForecastKit (`swift test`): 25 km rule, coordinate labels, ids, exact-point forecast coordinates.
- `MapPickerModelTests` and new `BrowseModelTests` / `SearchModelTests` cases in `ActivityForecastTests`, using the app-internal `StubPlaceLocator`.
- `MapKitPlaceLocator` and the map view are covered by previews and [quickstart.md](./quickstart.md).

**Target Platform**: iOS 18.0+, universal (iPhone, iPhone Duo, iPad). `MKReverseGeocodingRequest` is behind `if #available(iOS 26, macOS 26, *)`.

**Project Type**: mobile app (iOS), no backend.

**Performance Goals**: the marker appears in the frame of the tap. The name appears within 2 s on a typical connection (SC-002). A fold or resize causes no new lookup or forecast request.

**Constraints**: no location permission (FR-011). Layout is chosen by size class only. A stale lookup never overwrites a newer one (FR-007).

**Scale/Scope**:
- ForecastKit: 3 new domain types, 1 protocol, 1 live locator, 1 test suite.
- App: 1 new view model, 2 view models extended, 1 new view, 3 views changed, 1 new stub, preview data.
- Docs: constitution amendment, README trade-offs, CLAUDE.md.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution v2.2.0 (`.specify/memory/constitution.md`).

| Principle / Gate | Status |
|---|---|
| I. Full Swift Concurrency Safety | ✅ `MapPickerModel` is main-actor `@Observable`. `PlaceLocating` is `Sendable`. Lookups run in `.task(id:)`, so cancellation propagates as `CancellationError` and is never shown. A stale result is dropped by the pin-unchanged guard (R4) |
| II. Latest Swift Toolchain | ✅ No toolchain change. The iOS 26 API is behind `if #available`; the deployment target stays at iOS 18 |
| III. Adaptive Layout | ✅ Wide vs narrow behaviour comes from `horizontalSizeClass`. Camera, pin, selection and forecast live in long-lived models and survive fold and resize (R7). The Duo and iPad checks are in quickstart Q-10 |
| IV. Test-First Logic | ✅ `MapSelection` (ForecastKit) and `MapPickerModel` / `BrowseModel` / `SearchModel` additions start red. The live locator (thin Apple wrapper), view bodies and the composition root are exempt and covered by quickstart |
| V. Focused Scope and Layered Simplicity | ✅ (constitution amended to 2.3.0 in T002). `PlaceLocating` has a live implementation and a double, so it is allowed. The stub stays app-internal; the `nm` check is in quickstart. MapKit is not third-party, but the constitution's **Data** constraint ("Open-Meteo … only") and the `ForecastKit → Foundation` line do not yet allow it. **Task 1 amends the constitution to 2.3.0** (R9) |
| Quality Gates | ✅ All four gates plus `nm` and the layout matrix are in quickstart.md |

**Post-design re-check (after Phase 1)**: passes once the 2.3.0 amendment lands. No other exceptions.

## Project Structure

### Documentation (this feature)

```text
specs/005-map-place-selection/
├── plan.md                    # This file
├── research.md                # Phase 0: R1–R9
├── data-model.md              # Phase 1: MapSelection, PlaceLocating, MapPickerModel, BrowseModel changes
├── quickstart.md              # Phase 1: gates + manual matrix Q-1…Q-12
├── contracts/ui.md            # Phase 1: map in the sidebar, wide vs narrow
├── contracts/place-locating.md# Phase 1: ForecastKit locator API
├── checklists/requirements.md # from /speckit-specify
└── tasks.md                   # Phase 2 (/speckit-tasks, not created here)
```

### Source Code (repository root)

```text
.specify/memory/constitution.md                          # CHANGED: v2.3.0 allows MapKit/CoreLocation (R9)
App/
├── ActivityForecastApp.swift                            # CHANGED: BrowseModel(service:locator: MapKitPlaceLocator(), regionCode:)
├── RootView.swift                                       # CHANGED: owns preferredCompactColumn, passes it to SearchView
├── Search/SearchView.swift                              # CHANGED: map when search.showsMap, else existing LoadStateView
├── Search/MapPickerView.swift                           # NEW: Map + MapReader, marker, narrow callout, .task(id: pin)
├── Features/MapPickerModel.swift                        # NEW (test-first)
├── Features/BrowseModel.swift                           # CHANGED: map model, locateMapPin, selectMapPin, recentre on search pick
├── Features/SearchModel.swift                           # CHANGED: showsMap
├── Shared/StubPlaceLocator.swift                        # NEW: internal double for previews/tests
└── Shared/PreviewData.swift                             # CHANGED: locator fixtures, map previews
AppTests/
├── MapPickerModelTests.swift                            # NEW
├── BrowseModelTests.swift                               # CHANGED: map pin selection, recentre, wide/narrow
└── SearchModelTests.swift                               # CHANGED: showsMap
Packages/ForecastKit/
├── Sources/ForecastKit/Models/Coordinate.swift          # NEW
├── Sources/ForecastKit/Models/GeoRegion.swift           # NEW
├── Sources/ForecastKit/Models/MapSelection.swift        # NEW (test-first): 25 km rule, labels, ids
├── Sources/ForecastKit/Models/Place.swift               # CHANGED: `coordinate` accessor
├── Sources/ForecastKit/Service/PlaceLocating.swift      # NEW: protocol
├── Sources/ForecastKit/Service/MapKitPlaceLocator.swift # NEW: MapKit/CoreLocation live impl
└── Tests/ForecastKitTests/MapSelectionTests.swift       # NEW
README.md, CLAUDE.md                                     # CHANGED: MapKit trade-off, architecture notes
```

**Structure Decision**: the same two layers as features 003 and 004. Domain rules and the data boundary are in ForecastKit, so they are testable with `swift test`. Screen state and the map view are in the app. MapKit types (`MapCameraPosition`) appear only in the app. ForecastKit's MapKit import is confined to `MapKitPlaceLocator`, and its domain types stay Foundation-only.

## Complexity Tracking

No unjustified violations. The data-source and dependency change is handled by the constitution amendment (R9), not by an exception.
