# Research: Stricter MVVM in the App Layer

No unknowns remained in the Technical Context. These are the design decisions behind the spec.

## R1 — Bindable place selection on `BrowseViewModel`

- **Decision**: Add a computed property `var selection: Place? { get { selectedPlace } set { select(newValue) } }`. `SearchView` binds `List(places, selection: $browse.selection)`, where `$browse` comes from the existing `@Bindable`. `select(_:)` stays as it is, and remains the one place for the selection rules.
- **Rationale**:
  - `@Bindable` produces bindings for any settable property of an `@Observable` class, including computed ones.
  - Observation tracks the stored `selectedPlace` that the getter reads, so views still update.
  - The rule that re-selecting keeps the forecast is already in `select(_:)` (its `guard place != selectedPlace`). That guard also absorbs the duplicate sets `List` makes when a rebuilt sidebar reports its current selection again.
  - The existing `BrowseModelTests` keep calling `select(_:)` unchanged, so the renamed test count matches the baseline.
- **Alternatives considered**:
  - A settable `selectedPlace` with a `didSet`. It removes `select(_:)`, but every existing test call site would change, breaking the "renames only" proof (FR-010).
  - Keeping the `Binding(get:set:)` in the view. That is the wiring this feature removes (FR-005).

## R2 — How a day becomes sheet-presentable

- **Decision**: In `ForecastViewModel.swift`, define `nonisolated struct PresentedDay: Identifiable, Hashable, Sendable { let day: DaySuitability; var id: DaySuitability { day } }`. The view model holds `var presentedDay: PresentedDay?` in place of `selectedDay: DaySuitability?`.
- **Rationale**:
  - `.sheet(item:)` requires `Identifiable`. `DaySuitability` is a `ForecastKit` type that is `Hashable` but not `Identifiable`.
  - The wrapper only moves from the view (private `DaySelection`) to the view model, so the view binds `$model.presentedDay` directly.
  - `nonisolated` follows the project's rule for value types under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (CLAUDE.md). The type stays `Sendable` with no isolated conformance.
- **Alternatives considered**:
  - `extension DaySuitability: @retroactive Identifiable` in the app. A retroactive conformance on another module's type is fragile: it breaks if `ForecastKit` ever adds the conformance, and it is discouraged.
  - Adding `Identifiable` in `ForecastKit`. That is out of scope (no package changes), and it is a presentation need, not a domain one.
  - `sheet(isPresented:)` with a separate day. That makes two pieces of state that can disagree.

## R3 — Show and dismiss intents

- **Decision**:
  - Add `showDetail(for day: DaySuitability)`, which sets `presentedDay = PresentedDay(day: day)`. `ActivitySection`'s `onSelect` calls it.
  - Dismissal is the sheet binding setting `presentedDay` to `nil`. This covers swipe-down and Done (`@Environment(\.dismiss)`).
  - No separate `dismissDetail()` method.
- **Rationale**:
  - Every dismissal path in SwiftUI goes through the item binding, so a `dismissDetail()` method would have no production caller. Constitution V forbids building what no requirement uses.
  - Tests cover dismissal by setting `presentedDay = nil`, which is exactly what the binding does.
- **Spec impact**: FR-006 and US3 scenario 2 were reworded from "dismiss intent" to "dismissing clears the presented day" (spec updated).
- **Alternatives considered**: a `private(set) var` plus `dismissDetail()`. That needs a hand-written `Binding` in the view again, the opposite of FR-007.

## R4 — Folder layout and renames

- **Decision**:
  - `App/Features/{Browse,Search,Forecast}/` each hold that feature's views and its view model.
  - `App/Views/LoadStateView/` holds `LoadState.swift` and `LoadStateView.swift`.
  - `App/Shared/` keeps `Formatting`, `PreviewData` and `StubWeatherService`.
  - Tests become `AppTests/{Browse,Search,Forecast}ViewModelTests.swift`.
  - Types: `SearchModel`→`SearchViewModel`, `ForecastModel`→`ForecastViewModel`, `BrowseModel`→`BrowseViewModel`, `RootView`→`BrowseView`.
  - Stored property names (`browse.search`, `browse.forecast`, `model`) are unchanged.
- **Rationale**:
  - These are vertical feature slices, the MVVM playbook's default.
  - Both `App/` and `AppTests/` are file-system-synchronised groups (4 `PBXFileSystemSynchronized*` entries in the project), so `git mv` needs no `project.pbxproj` edits.
  - Leaving the property names alone keeps the diff to type names.
- **Alternatives considered**:
  - Renaming the properties too (`searchViewModel`). It is noisier and adds no clarity.
  - Leaving `LoadState` in `Shared/`. The user asked for a dedicated folder for shared views.

## R5 — Commit sequence and proof

- **Decision**:
  1. Phase A is one atomic `refactor:` commit with the renames and moves. Its proof is that the test names match the baseline list, apart from the suite-name substitution.
  2. Phases B and C each have a `test: … (Txxx, red)` commit, then a `feat: … (Txxx, green)` commit.
  3. Docs come last.
- **Rationale**: Constitution IV requires red/green pairs for new view-model behaviour. Doing the renames first means the new tests are written against the final names.

## R6 — Who owns the forecast request (FR-012)

- **Decision**: `ForecastViewModel` runs each fetch in a `Task` it stores. `load()` awaits that task, so cancelling the caller only stops the waiting. `loadIfNeeded()` joins a fetch already in flight. A newer `load()` (and so `retry()`) supersedes the current fetch, and `cancel()` stops it. `BrowseViewModel.select` cancels the replaced forecast.
- **Rationale**: two traces on iPhone 18 Pro showed `appear → disappear` on the forecast screen with no Back and no new selection. That cancelled its `.task` while the screen stayed visible, and no further appear came to restart the load.
- **Alternatives considered**:
  - Retrying in `onAppear`: it depends on a SwiftUI event that did not arrive.
  - `.task(id:)` keyed on the place: it is cancelled by the same stray disappear.
  - Detaching the fetch and never cancelling it: a deselected place would keep fetching.
