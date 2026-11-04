---
description: "Task list for Universal App with Adaptive Layouts"
---

# Tasks: Universal App with Adaptive Layouts

**Input**: Design documents from `/specs/003-universal-adaptive-layout/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ui.md, quickstart.md

**Tests**: REQUIRED for `ForecastKit` (constitution Principle IV). Each test task is written first and must **fail** before its paired implementation task. Commit pairs: `test: … (Txxx, red)` then `feat: … (Txxx, green)`. View and project-setting changes are exempt; they are verified by build, previews and quickstart.md.

**Gates before the PR** (constitution Quality Gates): `swiftlint lint --strict` = 0 violations, `swift test --package-path Packages/ForecastKit` all pass, clean simulator build, quickstart matrix recorded in the PR.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on unfinished tasks)
- **[Story]**: US1 / US2 / US3 from spec.md
- Paths are relative to the repository root

---

## Phase 1: Setup

- [X] T001 Confirm the baseline on branch `003-universal-adaptive-layout`: `swift test --package-path Packages/ForecastKit` passes (92 tests) and `xcodebuild -project ActivityForecast.xcodeproj -scheme ActivityForecast -destination 'generic/platform=iOS Simulator' build` succeeds. Record the default-rule lint baseline with `swiftlint lint --quiet App Packages/ForecastKit` (expected 58: line_length 32, identifier_name 14, nesting 3, multiple_closures_with_trailing_closure 3, static_over_final_class 2, function_parameter_count 2, file_length 1, cyclomatic_complexity 1)
- [X] T002 Create `.swiftlint.yml` at the repository root per research.md R8:
  - `included: [App, Packages/ForecastKit/Sources, Packages/ForecastKit/Tests]`
  - `excluded: [.build, Packages/ForecastKit/.build, DerivedData, .claude]`
  - `line_length: {warning: 120, error: 160, ignores_comments: false}`
  - `identifier_name: {min_length: {warning: 1}}`, with a comment explaining that short idiomatic names (`id`, `x`, loop indices) are allowed

  No other rule changes. Any rule later turned off MUST have a one-line `#` justification above it. Run `swiftlint lint` and note the remaining violations
- [X] T003 In `Packages/ForecastKit/Package.swift`, change the first line to `// swift-tools-version: 6.4` (constitution Principle II, research R9). Keep the default Swift 6 language mode and leave `SWIFT_VERSION = 6.0` in `ActivityForecast.xcodeproj/project.pbxproj`, since that setting is the language mode, not the compiler version. Verify `swift test --package-path Packages/ForecastKit` (92 pass) and the simulator build (command in T001) still succeed

## Phase 2: Foundational (blocks all stories: every file must be lint-clean before story work touches it)

- [X] T004 Fix every remaining violation reported by `swiftlint lint --strict` in `App/` and `Packages/ForecastKit/` without changing behaviour:
  - wrap or split lines over 120 characters;
  - flatten `nesting` (hoist nested types to file scope);
  - use a labelled closure argument instead of multiple trailing closures;
  - `static` instead of `class` members in final classes;
  - group parameters where `function_parameter_count` fires.

  For `file_length` / `cyclomatic_complexity`, either split the file or function, or add a scoped `// swiftlint:disable:next <rule>` with a reason (e.g. the scorer's per-activity switch mirrors research R9). Re-run `swift test --package-path Packages/ForecastKit` (92 pass)
- [X] T005 Verify the gate: `swiftlint lint --strict` exits 0; build still succeeds (command in T001)

**Checkpoint**: Swift 6.4 toolchain and lint gate green. All later tasks must keep it green.

---

## Phase 3: User Story 1 — Use the app natively on iPad (P1) 🎯 MVP

**Goal**: native iPad app, portrait and landscape, multitasking allowed (FR-001, FR-002, FR-003).

**Independent test**: install on the iPad Pro 11-inch (M5) simulator; the app fills the screen at native resolution in both orientations and search → place → forecast → day detail works (quickstart #5, #7).

- [X] T006 [US1] In `ActivityForecast.xcodeproj/project.pbxproj`, for both Debug and Release of the `ActivityForecast` target:
  - set `TARGETED_DEVICE_FAMILY = "1,2";`
  - rename the existing `INFOPLIST_KEY_UISupportedInterfaceOrientations` to `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` (same value);
  - add `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";`
  - do NOT add `UIRequiresFullScreen` (research R6).

  Prefer making the change in Xcode's target settings (General › Supported Destinations: add iPad; iPad orientations: all four), then confirm the resulting pbxproj diff contains only these keys
- [X] T007 [US1] Build for the simulator and install on a booted iPad Pro 11-inch (M5) simulator. Screenshot portrait and landscape (`xcrun simctl io booted screenshot`) to confirm native full-screen rendering, not iPhone compatibility mode

**Checkpoint**: the app is a native iPad app (still single-stack layout). Shippable on its own.

---

## Phase 4: User Story 2 — Make good use of wide windows (P2)

**Goal**: wide windows show results and forecast side by side; narrow windows keep the push flow (FR-004, FR-005, FR-006, FR-008, FR-010).

**Independent test**: iPhone Duo inner display or iPad full screen: search Paris, select Paris (France), then Paris (Texas). The results stay visible and the forecast is replaced in place. iPhone 16 still uses search → forecast → Back (quickstart #1–#3, #6).

### Tests (write first, must fail)

- [X] T008 [US2] Create `Packages/ForecastKit/Tests/ForecastKitTests/BrowseModelTests.swift` (`@MainActor @Suite("BrowseModel: selection and forecast ownership (FR-006, FR-007)")`), using `StubWeatherService` and a `Place` fixture like `ForecastModelTests.paris` plus a second place. Cases (per data-model.md › BrowseModel):
  1. a new model has `selectedPlace == nil` and `forecast == nil`, and `search` uses the injected service;
  2. `select(paris)` sets `selectedPlace` and creates `forecast` with `forecast?.place == paris` in `.loading`;
  3. `select(paris)` twice returns the same `forecast` instance (`===`) and the stub's forecast closure is called at most once after `loadIfNeeded()`;
  4. `select(texas)` after `select(paris)` replaces `forecast`, with `forecast?.place == texas`;
  5. `select(nil)` clears both;
  6. invariant "`forecast?.place == selectedPlace` at all times" holds after each step of a select A → B → nil → A sequence;
  7. `search` is the same instance (`===`) throughout.

  Run `swift test --filter BrowseModelTests`; expect a compile failure (red)

### Implementation

- [X] T009 [US2] Create `Packages/ForecastKit/Sources/ForecastKit/Features/BrowseModel.swift`: a `@MainActor @Observable public final class BrowseModel` with:
  - `public let search: SearchModel`;
  - `public private(set) var selectedPlace: Place?`;
  - `public private(set) var forecast: ForecastModel?`;
  - a stored `service`;
  - `public init(service: any WeatherService)`;
  - `public func select(_ place: Place?)` with the rules "same place → no change; different place → new `ForecastModel(place:service:)`; nil → forecast = nil".

  Doc comments cite FR-006/FR-007 and research R2. Make T008 pass (green) and keep the full suite and lint green
- [X] T010 [US2] Create `App/RootView.swift`: `struct RootView: View` taking `@Bindable var browse: BrowseModel`, with body `NavigationSplitView { SearchView(browse: browse) } detail: { … }`:
  - if `browse.forecast` is non-nil, show `ForecastView(model: forecast)` with `.id(forecast.place)`;
  - otherwise show `ContentUnavailableView("Pick a place", systemImage: "map", description: Text("Search for a city or town to see its week."))`.

  Add `#Preview`s for no selection and a selected place using `PreviewData.service`
- [X] T011 [US2] Update `App/Search/SearchView.swift`:
  - take `@Bindable var browse: BrowseModel` instead of `model`/`service`, and use `browse.search` for the query, state and retry;
  - replace `List(places) { NavigationLink(value:) }` with a `List(selection:)` bound to `Binding(get: { browse.selectedPlace }, set: { browse.select($0) })`, with rows `NavigationLink(value: place) { PlaceRow(place:) }` (plain `.tag` rows are not selectable in compact width; fixed after the author's folded-Duo check);
  - remove `.navigationDestination(for: Place.self)`.

  Keep the `.searchable`, debounce `.task(id:)`, idle and empty messages unchanged. Update previews to build a `BrowseModel`
- [X] T012 [US2] Update `App/Forecast/ForecastView.swift` to take `let model: ForecastModel` (no `@State` creation, no `service`) and keep everything else for now. Update its previews to construct `ForecastModel(place: PreviewData.paris, service: …)` and wrap them in `NavigationStack`
- [X] T013 [US2] Update `App/ActivityForecastApp.swift`: keep `OpenMeteoClient()` as the only live service, create `@State private var browse: BrowseModel`, and make the `WindowGroup` content `RootView(browse: browse)` (remove the `NavigationStack`)
- [X] T014 [US2] Build. Run on iPhone 16 (narrow: search → forecast → Back unchanged), on iPad full screen (two columns, "Pick a place" when empty) and on the iPhone Duo simulator inner display (two columns). Verify loading, empty, error + Retry and "No suitable day" render in both layouts (quickstart #1–#3, #6, #12)

  - Result (automated): iPhone 16 and the iPhone Duo outer display launch to the narrow search screen. iPad Pro 11" portrait launches to two columns with the "Pick a place" placeholder. While checking this, the default `.automatic` split style was found to hide the sidebar in iPad portrait, so RootView pins `.balanced` with all columns visible (FR-006). Selecting places, switching places, the error/empty states in the columns, and the Duo inner display need taps or a fold, which `simctl` cannot do, so they are covered by the manual walk-through in T023.

**Checkpoint**: adaptive layout works; state across resize not yet guaranteed.

---

## Phase 5: User Story 3 — Keep my place when the window changes size (P3)

**Goal**: fold, unfold, rotation and Split View / Stage Manager resizing keep the query, results, place, forecast and open day detail, with no refetch (FR-007, FR-012).

**Independent test**: with a forecast and a day detail open, fold or unfold the iPhone Duo (or resize an iPad window narrow ↔ wide) 10×. The same place, forecast and sheet are shown each time and there's no loading spinner (quickstart #4, #8).

### Tests (write first, must fail)

- [X] T015 [US3] Add to `Packages/ForecastKit/Tests/ForecastKitTests/SearchModelTests.swift` (per data-model.md › SearchModel (extended)), counting stub calls with `Recorder`:
  1. `search()` twice with the same query calls the service once, and the state is unchanged after the second call;
  2. after a `.empty` result, `search()` with the same query does not call the service again;
  3. changing the query (by more than whitespace) and calling `search()` calls the service again;
  4. `retry()` after `.loaded` calls the service again.

  Run `swift test --filter SearchModelTests`; expect failures (red)
- [X] T016 [US3] In `Packages/ForecastKit/Sources/ForecastKit/Features/SearchModel.swift`, add `private var lastQuery: String?`, set to the trimmed query whenever a `.loaded` or `.empty` result is applied. `search()` returns early, with no request and no state change, when `Self.trimmed(query) == lastQuery` and `state` is `.loaded` or `.empty`. `retry()` sets `lastQuery = nil` and then searches. Doc comment: the sidebar's `.task(id: query)` reruns when a resize rebuilds it (FR-007, research R3). Make T015 pass (green); the full suite and lint stay green
- [X] T017 [US3] Add to `Packages/ForecastKit/Tests/ForecastKitTests/ForecastModelTests.swift` (per data-model.md › ForecastModel):
  1. `loadIfNeeded()` on a fresh model loads once (the stub forecast closure is called once; the state becomes `.loaded`);
  2. a second `loadIfNeeded()` after `.loaded` does not call the service again (count stays 1);
  3. `retry()` after `.loaded` calls the service again (count 2);
  4. after a `loadIfNeeded()` cancelled mid-flight (use `Gate` to hold the stub, cancel the task), the state is still `.loading` and the next `loadIfNeeded()` fetches once and ends `.loaded`;
  5. `selectedDay` starts `nil`, can be set to a `DaySuitability` and cleared.

  Use `Recorder` to count calls. Run `swift test --filter ForecastModelTests`; expect failures (red)

### Implementation

- [X] T018 [US3] In `Packages/ForecastKit/Sources/ForecastKit/Features/ForecastModel.swift`:
  - add `public var selectedDay: DaySuitability?` (doc: the open day detail, survives view rebuilds, US3-3);
  - add `public func loadIfNeeded() async`, which returns early when `state` is `.loaded` and otherwise awaits `load()` (doc: research R3).

  `retry()` is unchanged. Make T017 pass (green); the full suite and lint stay green
- [X] T019 [US3] In `App/Forecast/ForecastView.swift`:
  - change `.task { await model.load() }` to `.task { await model.loadIfNeeded() }`;
  - remove the local `@State private var selection`;
  - bind the sheet to the model: `.sheet(item: Binding(get: { model.selectedDay.map(DaySelection.init) }, set: { model.selectedDay = $0?.day }))`;
  - set `model.selectedDay = day` in the `ActivitySection` `onSelect` closure.

  Keep the `DaySelection` wrapper, the title, subtitle and sections unchanged. Also, in `App/Forecast/DayDetailView.swift`, add `.keyboardShortcut(.cancelAction)` to the Done button (keep its `.confirmationAction` placement), so Escape closes the sheet on iPad with a hardware keyboard (FR-008, contracts/ui.md › Input; checked in quickstart #9)
- [ ] T020 [US3] On the iPhone Duo simulator: open a forecast and a day sheet, then fold and unfold 10× and confirm the same place, forecast (no spinner) and sheet each time. On iPad: rotate, and use Split View ⅓/½/⅔ and Stage Manager resizes with the sheet open. In the narrow → wide direction, confirm the pushed forecast becomes the selected place; in wide → narrow, confirm the forecast stays pushed and Back returns to the same results (quickstart #4, #7, #8)

**Checkpoint**: all three stories done.
- [ ] T025 [US2] Zoom transition for the day sheet on wide windows: in `App/Forecast/ActivitySection.swift` add a `transitionNamespace: Namespace.ID` and `.matchedTransitionSource(id: day, in:)` on each day button. In `App/Forecast/ForecastView.swift` add `@Namespace` and read `horizontalSizeClass`; in regular width apply `.navigationTransition(.zoom(sourceID: day, in:))` to the sheet's `DayDetailView`, otherwise leave the default sheet (research R5, FR-012). Verify with quickstart #14

---

## Phase 6: Polish

- [X] T021 [P] Update `README.md`:
  - "Run it" says the app is universal (iPhone and iPad, including iPhone Duo);
  - the Architecture diagram shows `RootView (NavigationSplitView)` and `BrowseModel`;
  - "Assumptions and limitations" drops "iPhone portrait-first";
  - add `swiftlint lint --strict` to the test commands.

  Also update the `CLAUDE.md` Commands section with the lint command, and its Architecture section to mention `BrowseModel` and that the layout follows width class.

  Remove the claims that conflict with constitution Principle II (Governance requires this):
  - `README.md` "Requirements: Xcode 16+ (Swift 6)" → "Xcode 27+ (Swift 6.4 toolchain)";
  - the README trade-off "iOS 18 minimum: reviewers on Xcode 16 can still build it…" → "iOS 18 minimum is kept; building needs Xcode 27 (constitution II). Newer APIs need `if #available`";
  - in `CLAUDE.md`, "iOS 18 minimum so reviewers on Xcode 16 can build — avoid newer-only APIs" → "iOS 18 minimum, Xcode 27 / Swift 6.4 toolchain; APIs newer than iOS 18 need `if #available`"
- [X] T022 [P] Remove the Sync Impact Report HTML comment from the top of `.specify/memory/constitution.md` (it is marked "remove before committing") so the constitution v1.1.1 can be committed with this feature
- [ ] T023 Run all gates: `swiftlint lint --strict` (0), `swift test --package-path Packages/ForecastKit` (92 + new cases pass), simulator build (no project warnings). Walk through quickstart.md (including #9 keyboard and pointer, FR-008, and #13 identical scores across devices, FR-011) #1–#13, with the manual checks that need gestures done by the author, and record the results in the PR, see quickstart.md #9, #13 checks
- [X] T024 Mark completed tasks `[X]` in this file; confirm `git status` shows only files listed in plan.md › Project Structure, lint-fixed files, `README.md`, `CLAUDE.md` and the constitution

---

### Results (2026-11-04)

| Check | Result |
|---|---|
| `swiftlint lint --strict` | ✅ 0 violations, 38 files |
| `swift test --package-path Packages/ForecastKit` | ✅ 108 tests in 8 suites (92 + 16 new) |
| Clean simulator build | ✅ BUILD SUCCEEDED, no warnings |
| Quickstart #1 iPhone 16 launch | ✅ narrow search screen |
| Quickstart #2 iPhone Duo outer display launch | ✅ narrow search screen (Duo simulator boots folded) |
| Quickstart #5/#6 iPad Pro 11" portrait launch | ✅ native full screen, two columns, "Pick a place" |
| Quickstart #10 largest accessibility text (launch screens) | ⚠️ iPad wraps cleanly. iPhone: the system large navigation title truncates to "Activity For…", unchanged since feature 001. Needs a decision |
| Quickstart #3, #4, #7–#9, #11–#13 (selection, fold/unfold ×10, rotation, Split View/Slide Over/Stage Manager, keyboard, VoiceOver, offline, cross-device scores) | ⏳ need gestures, a fold, or multitasking, which `simctl` cannot drive. To be run by the author and recorded in the PR |

## Dependencies & Execution Order

- T001 → T002 → T003 → T004 → T005 (toolchain and lint must be green before stories touch files)
- US1 (T006–T007) depends only on Phase 2.
- US2 (T008–T014): T008 → T009 → {T010, T011, T012} → T013 → T014. T010–T012 touch different files, but all need T009's `BrowseModel` API.
- US3 (T015–T020) depends on US2 (T012's `ForecastView(model:)`): {T015 → T016} ∥ {T017 → T018} → T019 → T020.
- Polish: T021 ∥ T022 any time after Phase 2; T023 → T024 last.

## Parallel opportunities

- US1 (project settings) can run in parallel with US2's T008–T009 (ForecastKit only).
- T010 ∥ T011 ∥ T012 after T009.
- In US3, the SearchModel pair (T015–T016) and the ForecastModel pair (T017–T018) touch different files and can run in parallel.
- T021 ∥ T022.

## Implementation strategy

1. **MVP**: Setup + Foundational + US1 (T001–T007). A native iPad app on the Swift 6.4 toolchain that passes the lint gate.
2. **Increment 1**: US2. Side-by-side on wide windows.
3. **Increment 2**: US3. Search, forecast and the open sheet survive folds and resizes without refetching.
4. **Finish**: Polish, all gates, quickstart results in one PR.
