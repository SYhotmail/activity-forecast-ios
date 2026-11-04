---
description: "Task list for Select a Place on a Map"
---

# Tasks: Select a Place on a Map

**Input**: Design documents from `/specs/005-map-place-selection/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R9), data-model.md, contracts/ui.md, contracts/place-locating.md, quickstart.md

**Tests**: REQUIRED (constitution Principle IV).
- ForecastKit behaviour is tested with `swift test`; app view-model behaviour in `ActivityForecastTests` on a simulator.
- Each test task is written first and must **fail** before its paired implementation task. Commit pairs: `test: … (Txxx, red)`, then `feat: … (Txxx, green)`.
- Exempt (verified by build, previews and quickstart.md): view bodies, the composition root, and `MapKitPlaceLocator`, a thin wrapper around Apple services (contracts/place-locating.md).

**Gates before the PR**: quickstart.md Q-G1…Q-G4, the Release `nm` check, and the manual matrix Q-1…Q-12 recorded in the PR.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on unfinished tasks)
- **[Story]**: US1 / US2 / US3 from spec.md
- Paths are relative to the repository root

## Shared conventions for test commands
- Package: `swift test --package-path Packages/ForecastKit --filter <Suite>`
- App: `xcodebuild test -project ActivityForecast.xcodeproj -scheme ActivityForecast -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ActivityForecastTests/<Suite>`
- App view models are main-actor isolated by `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Value fixtures and stubs are `nonisolated`, as `StubWeatherService` is.

---

## Phase 1: Setup

- [X] T001 Confirm the baseline on branch `005-map-place-selection`:
  - `swiftlint lint --strict` exits 0;
  - `swift test --package-path Packages/ForecastKit` passes (69 tests);
  - `xcodebuild test` (command above, no `-only-testing`) passes (39 app tests + package tests);
  - `xcodebuild -project ActivityForecast.xcodeproj -scheme ActivityForecast -destination 'generic/platform=iOS Simulator' build` succeeds with no project warnings.

  Record the counts in the PR description draft.
- [X] T002 Amend `.specify/memory/constitution.md` to **2.3.0** (MINOR) with `/speckit-constitution`, per research.md R9:
  - Platform & Tooling › Data: "Open-Meteo Geocoding and Forecast APIs for place search and weather; Apple MapKit/CoreLocation (system frameworks, keyless) for map display and reverse geocoding. No location permission."
  - Principle V: `ForecastKit` may import MapKit/CoreLocation in its data layer only (`Service/`). Domain types (`Models/`, `Scoring/`) still import only Foundation.
  - Add a Clarifications bullet for Session 2026-11-04 and bump **Version** / **Last Amended**.
  - Update the plan's Constitution Check row V in `specs/005-map-place-selection/plan.md` to ✅.

**Checkpoint**: baseline green; constitution allows MapKit.

---

## Phase 2: Foundational (domain types and data boundary used by every story)

- [X] T003 [P] Write `Packages/ForecastKit/Tests/ForecastKitTests/MapSelectionTests.swift` (red, `@Suite("MapSelection: naming a tapped point (specs/005 FR-003, FR-006)")`) covering `MapSelection.place(at:nearest:)` and `MapSelection.coordinateLabel(_:)` from data-model.md:
  - a locality 3 km from the tap → name/region/country/timeZone from the locality; latitude/longitude equal the **tap**, not the locality (FR-006);
  - a locality 24.9 km away → named; 25.1 km away → coordinate label, `region == nil`, `country == nil`, `timeZone == "GMT"` (`namingRadius` = 25 km, great-circle distance; Clarification Q1);
  - `nearest == nil` → coordinate label;
  - labels: `(48.8566, 2.3522)` → `"48.86° N, 2.35° E"`; `(-33.87, -151.21)` → `"33.87° S, 151.21° W"`; `(0, 0)` → `"0.00° N, 0.00° E"`; longitude 190 is normalised to `"…170.00° W"`;
  - id: negative; equal for taps equal after rounding to 4 decimals; different for taps 0.001° apart;
  - `Place.coordinate` returns its latitude/longitude.

  Run the package test command with `--filter MapSelectionTests`: it must fail to compile/fail.
- [X] T004 Make T003 green:
  - `Packages/ForecastKit/Sources/ForecastKit/Models/Coordinate.swift`: `public struct Coordinate: Sendable, Hashable` with `latitude` (−90…90) and `longitude` (−180…180), and a public init.
  - `Packages/ForecastKit/Sources/ForecastKit/Models/GeoRegion.swift`: `public struct GeoRegion: Sendable, Hashable` with `center: Coordinate`, `latitudeDelta`, `longitudeDelta`.
  - `Packages/ForecastKit/Sources/ForecastKit/Models/MapSelection.swift`: `public enum MapSelection` with `namingRadius` (meters, 25_000), `place(at:nearest:)`, `coordinateLabel(_:)` and a private haversine distance.
  - Add `public var coordinate: Coordinate` to `Packages/ForecastKit/Sources/ForecastKit/Models/Place.swift`.

  Foundation only; doc comments cite `specs/005 FR-003/FR-006`, research R3. `swift test --package-path Packages/ForecastKit` passes (69 + new).
- [X] T005 [P] Create `Packages/ForecastKit/Sources/ForecastKit/Service/PlaceLocating.swift`: `public protocol PlaceLocating: Sendable` with `nearestLocality(to: Coordinate) async throws -> Place?` and `region(ofCountry code: String) async throws -> GeoRegion?`, exactly as contracts/place-locating.md. The doc comment states the error contract: `UserFacingError.offline` / `.serviceUnavailable`, `CancellationError` on cancel, `nil` for none.
- [X] T006 Create `Packages/ForecastKit/Sources/ForecastKit/Service/MapKitPlaceLocator.swift`: `public struct MapKitPlaceLocator: PlaceLocating` with a public no-argument init (research R2, R6).
  - `nearestLocality(to:)`:
    - `if #available(iOS 26, macOS 26, *)`: `MKReverseGeocodingRequest(location:)` → `mapItems()`. Use the first item's city name, region, country, location and time zone, mapped in one private function. Verify the property names against the SDK.
    - else: `CLGeocoder().reverseGeocodeLocation`, using `locality` / `administrativeArea` / `country` / `location` / `timeZone`.
    - Return `nil` when there is no city/locality. The returned `Place` uses the **locality's** coordinates and `id: 0` (`MapSelection` assigns the final id).
  - `region(ofCountry:)`: return `nil` unless `code` is two ASCII letters. Otherwise use `MKLocalSearch` with `naturalLanguageQuery = Locale(identifier: "en_US").localizedString(forRegionCode: code)` and `resultTypes = .address` → `boundingRegion` → `GeoRegion`.
  - Error mapping on both paths: cancellation → `CancellationError`; `CLError.network` or a `URLError` offline code → `UserFacingError.offline`; anything else → `.serviceUnavailable`. Nothing is found → `nil`, not an error.

  No `CLLocationManager`. Build both `swift build --package-path Packages/ForecastKit` (macOS) and the iOS simulator build with zero warnings. In particular, the `CLGeocoder` fallback must not warn at the iOS 18 deployment target. If it does, stop and report rather than suppress.
  - Result (2026-11-04): builds with no warnings on macOS and the iOS simulator; the `CLGeocoder` fallback does not warn at the iOS 18 / macOS 15 targets. A live probe on macOS 26 (scratch executable) showed that MapKit 26's `cityWithContext` is "Chamonix, France" / "Cupertino, CA United States", not "city, region", which had given "France, France" subtitles. Fixed test-first: `MapKitPlaceLocator.region(fromCityContext:city:country:)` with `MapKitRegionParsingTests` (red → green). Live results: Chamonix → Chamonix / France; mid-Atlantic → nil (coordinates); 45.83° N 6.87° E → Courmayeur / Italy; GB and FR regions resolve; "001" → nil.
- [X] T007 [P] Create `App/Shared/StubPlaceLocator.swift`, `nonisolated struct StubPlaceLocator: PlaceLocating`, mirroring `App/Shared/StubWeatherService.swift`:
  - closures `nearest: @Sendable (Coordinate) async throws -> Place?` (default returns `nil`) and `region: @Sendable (String) async throws -> GeoRegion?` (default returns `nil`);
  - the same doc warning that production code must never use it (constitution Principle V).

  In `App/Shared/PreviewData.swift`, add:
  - `chamonix: Place` (45.92, 6.87, "Auvergne-Rhône-Alpes", "France", "Europe/Paris");
  - `locator = StubPlaceLocator(nearest: { _ in chamonix }, region: { _ in GeoRegion(center: Coordinate(latitude: 46.6, longitude: 2.4), latitudeDelta: 9, longitudeDelta: 11) })`;
  - `hangingLocator`, which never returns, the same way `hangingService` does.
- [X] T008 Refactor `BrowseModel` construction (no behaviour change, tests stay green):
  - `App/Features/BrowseModel.swift`: change to a required `init(service: any WeatherService, locator: any PlaceLocating, regionCode: String?)`, with no default locator, because production code must never default to a stub. Store `locator` and `regionCode` for T014.
  - Update `App/ActivityForecastApp.swift`: `BrowseModel(service: OpenMeteoClient(), locator: MapKitPlaceLocator(), regionCode: Locale.current.region?.identifier)`.
  - Update every `BrowseModel(service:)` call in `App/RootView.swift`, `App/Search/SearchView.swift` previews and `AppTests/BrowseModelTests.swift` to pass `locator: StubPlaceLocator(), regionCode: nil` (previews: `PreviewData.locator`, `"FR"`).

  `xcodebuild test` passes (39 app tests).

**Checkpoint**: domain rule tested, data boundary and live locator compile on iOS and macOS, stub available. User stories can start.

---

## Phase 3: User Story 1 — Pick a spot on the map (P1) 🎯 MVP

**Goal**: an empty search shows a map. Tapping any point marks it, names it (locality within 25 km, else coordinates) and shows its forecast. Wide layouts update immediately; narrow layouts get a **Show forecast** callout. The map opens on the device-region country (FR-001…FR-007, FR-010, FR-011).

**Independent test**: quickstart Q-1, Q-2, Q-3, Q-5, Q-6, Q-7, Q-9, Q-12.

### Tests (write first, must fail)

- [X] T009 [P] [US1] In `AppTests/SearchModelTests.swift`, add `showsMap` cases (red): `""` → true; `"   "` → true; `"a"` → false; `"Paris"` → false; changing the query back to `" "` → true (FR-001; 1 character keeps the existing idle hint).
- [X] T010 [P] [US1] Create `AppTests/MapPickerModelTests.swift` (red, `@MainActor @Suite("MapPickerModel: tap, name, last tap wins (specs/005 FR-002…FR-007, FR-011)")`). Use `StubPlaceLocator`, `Gate` and `Recorder` from `AppTests/Support/`. Cases:
  - initial: `pin == nil`; `camera.region` equals `MapPickerModel.worldRegion` (`MKCoordinateRegion(.world)`);
  - `tap(at: c)` sets `pin == MapPin(coordinate: c, place: nil)` synchronously, before any await (FR-004);
  - `locatePin()` with a locality 3 km away → returns and stores a place named after it, at `c` (delegates to `MapSelection.place(at:nearest:)`);
  - locator returns `nil` → coordinate label place;
  - locator receives exactly the tapped coordinate (Recorder);
  - **last tap wins** (FR-007): tap A, start `locatePin()` gated, tap B, open the gate → pin is B, still locating (A's result discarded); a second `locatePin()` names B;
  - cancelling the task running `locatePin()` → pin unchanged and still locating; no error anywhere;
  - `locatePin()` on an already named pin returns that place without calling the locator (idempotent across rebuilds, FR-009);
  - `loadInitialRegionIfNeeded()`:
    - with region code `"FR"`, the stub returns a region → camera shows that region;
    - `"001"`, `"150"` and `nil` → locator not called, camera stays world;
    - the locator throws → camera stays world;
    - after a tap (pin set) or a user-positioned camera → camera not changed;
    - called twice → locator called once.
- [X] T011 [P] [US1] In `AppTests/BrowseModelTests.swift`, add map cases (red):
  - `browse.map` exists and uses the injected locator;
  - `locateMapPin(selectingWhenNamed: true)` after `map.tap(at:)` → `selectedPlace` is the named pin's place and `forecast?.place` equals it (wide layout, FR-005);
  - `selectingWhenNamed: false` → nothing selected, pin named (narrow layout);
  - `selectMapPin()` with a named pin → selected; with a locating pin or no pin → no change;
  - selecting the map pin's place again keeps the same `ForecastModel` instance (FR-010);
  - a map selection does not move the camera (research R7).

### Implementation

- [X] T012 [US1] Make T009 green: add `var showsMap: Bool` (trimmed query is empty) to `App/Features/SearchModel.swift`, with a doc comment citing specs/005 FR-001.
- [X] T013 [US1] Make T010 green: create `App/Features/MapPickerModel.swift` per data-model.md:
  - `struct MapPin: Hashable, Sendable` (`coordinate`, `place: Place?`, `isLocating`);
  - `@Observable final class MapPickerModel` with `init(locator:regionCode:)`:
    - `static let worldRegion = MKCoordinateRegion(.world)` and `var camera: MapCameraPosition` (default: `.region(worldRegion)`);
    - `private(set) var pin: MapPin?`;
    - `tap(at:)`;
    - `locatePin() async -> Place?`: capture the pin; call the locator; on `CancellationError` return nil with no change; apply only if `!Task.isCancelled && pin == captured`; build the place with `MapSelection.place(at:nearest:)`. **Do not handle other errors here**: treat them like cancellation (return nil, pin unchanged). The coordinate fallback for failures is US3's behaviour (T021 → T022), so its tests must fail first;
    - `loadInitialRegionIfNeeded() async`: ISO check = two ASCII letters; skip when `pin != nil` or `camera.positionedByUser`; one attempt per session.

  `import MapKit` is allowed here (app layer). Doc comments cite research R4, R6, R7.
- [X] T014 [US1] Make T011 green in `App/Features/BrowseModel.swift`:
  - `let map: MapPickerModel`, created in `init` from `locator` and `regionCode`;
  - `func locateMapPin(selectingWhenNamed: Bool) async`: `if let place = await map.locatePin(), selectingWhenNamed { selectWithoutRecentring(place) }`;
  - `func selectMapPin()`;
  - a private `selectWithoutRecentring(_:)` sharing the existing guard in `select(_:)` (re-selecting the same place keeps the forecast).

  Keep the invariant `forecast?.place == selectedPlace`.
- [X] T015 [US1] Create `App/Search/MapPickerView.swift` (contracts/ui.md › Map, Wide, Narrow). Inputs: `browse: BrowseModel`, `compactColumn: Binding<NavigationSplitViewColumn>`.
  - `MapReader { proxy in Map(position: $map.camera) { … } }`:
    - a `Marker` at `pin.coordinate`, titled with the place name or "Locating…";
    - `.onTapGesture { location in … }`: convert with `proxy.convert(location, from: .local)`. Ignore the tap if the current pin's screen point (`proxy.convert(pin, to: .local)`) is within 22 pt (FR-010, R8); otherwise `map.tap(at:)`.
  - `.task(id: map.pin) { await browse.locateMapPin(selectingWhenNamed: horizontalSizeClass == .regular) }`.
  - `.task { await map.loadInitialRegionIfNeeded() }`.
  - In compact width, when `pin?.place` is non-nil, a callout (e.g. `.safeAreaInset(edge: .bottom)`) shows the name, the subtitle (`place.subtitle`) and a **Show forecast** button: `browse.selectMapPin(); compactColumn.wrappedValue = .detail` (R5).
  - No `UserAnnotation`, no `MapUserLocationButton` (FR-011).
  - Previews: "Map – wide", "Map – narrow callout" with `PreviewData.locator`.
- [X] T016 [US1] Wire the map into the layout:
  - `App/RootView.swift`: add `@State private var compactColumn = NavigationSplitViewColumn.sidebar` and use `NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $compactColumn)`. Pass `$compactColumn` to `SearchView`. The detail placeholder text becomes "Search for a city or town, or tap the map, to see its week."
  - `App/Search/SearchView.swift`: accept `compactColumn: Binding<NavigationSplitViewColumn>`. `if search.showsMap { MapPickerView(…) } else { existing LoadStateView }`. Keep `.searchable`, `.task(id: search.query)` and the list unchanged.

  Update the previews in both files.
- [ ] T017 [US1] Verify on the simulator (record in the PR): quickstart Q-1, Q-2, Q-3, Q-5, Q-6, Q-7, Q-9, Q-12, and Q-13 (SC-002 naming time). Also check the research R5 risk: in compact width, a search-list row still pushes, and Back from a map-pushed forecast returns to the map. If `preferredCompactColumn` misbehaves, record it and fix it before continuing.
  - Result (2026-11-04), partial: Q-1 passed on iPhone 16 (iOS 18.5) and iPad Pro 11" (M5, iOS 26). The map shows in place of the idle hint, opens on Poland for region `en_PL`, there is no location prompt, and the iPad detail placeholder reads "…or tap the map…". The steps that need taps (Q-2, Q-3, Q-5, Q-6, Q-7, Q-9, Q-12, Q-13) and the R5 compact push/Back check are left for the author: no simulator tap tooling (idb/axe) was available here.

**Checkpoint**: MVP. A user can choose any place from the map on every layout.

---

## Phase 4: User Story 2 — The map reflects the current selection (P2)

**Goal**: a place picked from search results is the map's marker and is centred when the search is cleared. Camera, marker and selection survive fold, rotation, resize and map ↔ list switches (FR-008, FR-009).

**Independent test**: quickstart Q-8 and Q-10.

- [X] T018 [P] [US2] Add tests (red):
  - `AppTests/MapPickerModelTests.swift`: `show(place)` → `pin == MapPin(coordinate: place.coordinate, place: place)` (named, not locating); the camera is centred on the place with a city-level span (assert the region center ≈ place coordinate and span ≤ 0.5°); `show` after `loadInitialRegionIfNeeded` has run keeps the place's camera; a later `loadInitialRegionIfNeeded()` does not override it.
  - `AppTests/BrowseModelTests.swift`: `select(paris)` (search path) → `map.pin?.place == paris` and the camera is centred on Paris; `select(nil)` leaves the pin and camera as they were.
- [X] T019 [US2] Make T018 green:
  - `App/Features/MapPickerModel.swift`: add `show(_ place: Place)`. It sets a named pin and `camera = .region(MKCoordinateRegion(center:, span: 0.3°))`.
  - `App/Features/BrowseModel.swift`: `select(_:)` calls `map.show(place)` for non-nil places. The map path keeps using `selectWithoutRecentring`.
- [ ] T020 [US2] Verify persistence on the simulator: quickstart Q-8 and Q-10 (iPhone Duo folded ↔ unfolded with a map selection, with a pin still locating, and with a pin named in the narrow layout but not yet shown, which must be selected on unfolding; iPad Split View resize). Confirm that no forecast or lookup request repeats: watch with a breakpoint or the network log.
  - Pending: needs taps and folding (author). The model side is covered by `MapPickerModelTests` (idempotent `locatePin`, `show`) and `BrowseModelTests`.

**Checkpoint**: map and search always agree on the selection.

---

## Phase 5: User Story 3 — Clear feedback while the spot is being named (P3)

**Goal**: the marker shows "Locating…" at once. A naming failure falls back to coordinates without an error, and the forecast still loads. The marker is announced by VoiceOver (FR-004, FR-012, US3).

**Independent test**: quickstart Q-4 and Q-11.

- [X] T021 [P] [US3] Add tests (red) to `AppTests/MapPickerModelTests.swift`:
  - the locator throws `UserFacingError.offline` → `locatePin()` returns a coordinate-label place and the pin is named with it;
  - the same for `.serviceUnavailable` and for an arbitrary non-`UserFacingError`;
  - `MapPickerModel` exposes no error state.

  In `AppTests/BrowseModelTests.swift`: with an offline locator, `locateMapPin(selectingWhenNamed: true)` still selects the coordinate place and creates its `ForecastModel` (the forecast is requested; its own error/retry comes from ForecastModel).
- [X] T022 [US3] Make T021 green in `App/Features/MapPickerModel.swift`: every non-cancellation error maps to `nearest = nil`, so the pin is named with its coordinate label. Keep the catch order: `CancellationError` first. (T013 deliberately left this out, so T021 is red until now; constitution Principle IV.)
- [X] T023 [US3] Accessibility and feedback in `App/Search/MapPickerView.swift`:
  - the marker title is "Locating…" while `pin.isLocating`;
  - `.accessibilityLabel("Selected place, \(name)")` / `"Selected place, locating"` on the marker;
  - the callout text uses Dynamic Type styles (`.headline` / `.subheadline`) and wraps at the largest sizes;
  - the **Show forecast** button has a 44 pt minimum hit area;
  - check Light/Dark in previews.
  - The marker is an `Annotation` hosting `PinView`, because `MapContent` has no accessibility modifiers. Label: "Selected place, <name>" / "Selected place, locating". The pin pulses while locating. The callout stacks vertically at accessibility text sizes, and the button has a 44 pt minimum height.
- [ ] T024 [US3] Verify quickstart Q-4 (Network Link Conditioner 100% loss) and Q-11 (VoiceOver, largest accessibility text size, Dark mode) on iPhone 16 and iPad.
  - Pending: needs Network Link Conditioner, VoiceOver and taps (author).

**Checkpoint**: every tap gives feedback; failures degrade to coordinates.

---

## Phase 6: Polish & Cross-Cutting

- [X] T025 [P] Update `README.md`:
  - features: "Choose a place by search or by tapping the map";
  - Trade-offs: the map uses Apple MapKit (system framework, keyless). Reverse geocoding uses MapKit because Open-Meteo has no reverse lookup. The 25 km naming rule. No location permission;
  - architecture diagram: add `PlaceLocating`/`MapKitPlaceLocator` (ForecastKit Service) and `MapPickerModel` (App Features).
- [X] T026 [P] Update `CLAUDE.md` › Architecture:
  - **Service/**: `PlaceLocating` + `MapKitPlaceLocator` (MKReverseGeocodingRequest on iOS 26+, CLGeocoder before; MKLocalSearch for country bounds); the double is the app-internal `StubPlaceLocator`.
  - **Scoring/Models**: `MapSelection` (25 km rule, coordinate labels, negative ids, forecast at the tapped point).
  - **Layout**: an empty search shows `MapPickerView`. `RootView` owns `preferredCompactColumn` for the narrow **Show forecast** push.
  - Add specs/005 to the spec list and the 005 quickstart to the manual checklists.
- [X] T027 [P] Update `intent.md` §5 "Search": add one line saying a place can also be chosen on a map (MapKit, additive to Open-Meteo search; constitution 2.3.0).
- [ ] T028 Run all gates (quickstart Q-G1…Q-G4) and the Release `nm` check (`StubPlaceLocator`, `StubWeatherService`, `PreviewData`: 0 symbols). Re-run the 001 and 003 quickstart checklists on iPhone 16, iPhone Duo (both displays) and iPad (full screen and one Split View size) for SC-005. Record all results in the PR description.
  - Result (2026-11-04): lint 0; `swift test` 77; `xcodebuild test` 67 app + 77 package on iPhone 16 (iOS 18.5) and iPad Pro 11" M5 (iOS 26); clean simulator build with no project warnings; Release `nm`: StubPlaceLocator 0, StubWeatherService 0, PreviewData 0, Gate 0, Recorder 0, and MapKit geocoding classes linked. Still to do: re-run the 001/003 quickstart tap checks (SC-005), which needs the author.
- [X] T029 Mark completed tasks `[X]`. `git status` shows only the files listed in plan.md › Source Code plus spec docs.

  - `git status` shows only planned files, plus `.specify/memory/constitution.md`, `README.md`, `CLAUDE.md`, `intent.md`, and the pre-existing scheme change, which was not touched.
---

## Dependencies & Execution Order

- **Phase 1** (T001 → T002) → **Phase 2** (T003 → T004; T005 ∥ T007 after T004; T006 after T005; T008 after T005 and T007) → stories.
- **US1** (T009–T017) needs Phase 2. Within it: T009 → T012; T010 → T013; T011 → T014 (T014 needs T013); T015 needs T013 and T014; T016 needs T012 and T015; T017 last.
- **US2** (T018–T020) needs T013 and T014. It can start once those are green; it does not need the US1 views until T020.
- **US3** (T021–T024) needs T013 (model) and T015 (view, for T023).
- **Polish** (T025–T029) after the stories that ship.

## Parallel Opportunities

- Phase 2: T003 ∥ T005 (different files); T007 ∥ T006 once T005 exists.
- US1 tests: T009 ∥ T010 ∥ T011 (three files), all red before T012–T014.
- After US1 models (T013, T014): US2 tests (T018) ∥ US3 tests (T021). Both touch `MapPickerModelTests.swift` and `BrowseModelTests.swift`, so in one working copy do them in sequence; with separate worktrees they can run in parallel.
- Polish: T025 ∥ T026 ∥ T027.

### Example: US1 test batch
```text
T009 AppTests/SearchModelTests.swift   (showsMap)
T010 AppTests/MapPickerModelTests.swift (new suite)
T011 AppTests/BrowseModelTests.swift   (map pin selection)
```

## Implementation Strategy

1. **MVP** = Phases 1–3. The constitution is amended, the domain rule and locator exist, and tapping the map works on every layout. Demo with quickstart Q-1…Q-7.
2. **+US2**: selection sync and persistence (small: one model method and a call).
3. **+US3**: failure fallback hardening and accessibility polish.
4. Polish: docs and the full gate run. Ship as stacked PRs per phase, as in earlier features (each with its red/green commit pairs).
