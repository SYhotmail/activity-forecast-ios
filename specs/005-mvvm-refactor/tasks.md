---
description: "Task list for Stricter MVVM in the App Layer"
---

# Tasks: Stricter MVVM in the App Layer

**Input**: Design documents from `/specs/005-mvvm-refactor/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/viewmodels.md, quickstart.md

**Tests**:
- The new view-model behaviour (US2, US3) is test-first: a `test: … (Txxx, red)` commit, then a `feat: … (Txxx, green)` commit (constitution IV, FR-010).
- US1 is renames and moves only. Its proof is the existing tests, unchanged in count (research R5).

Gates used at the end of each phase:
- **G-app**: `xcodebuild test -project ActivityForecast.xcodeproj -scheme ActivityForecast -destination 'platform=iOS Simulator,name=iPhone 16'`
- **G-lint**: `swiftlint lint --strict`

**Delivery**: branch `refactoring-better-mvvm`, one PR. Commit per phase as noted.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on unfinished tasks)
- **[Story]**: US1 / US2 / US3 from spec.md
- Paths are relative to the repository root

---

## Phase 1: Setup

- [X] T001 Record the baseline on `refactoring-better-mvvm` before any code change:
  - `swiftlint lint --strict` (0), `swift test --package-path Packages/ForecastKit` (all pass), G-app (all pass);
  - write the sorted app test-function identifiers (`Suite/function`) from the G-app output (`xcodebuild test … 2>&1 | grep -E "Test case '.*(SearchModelTests|ForecastModelTests|BrowseModelTests)" | …`, or `-enumerate-tests` if available) to `specs/005-mvvm-refactor/baseline-vm-tests.txt`. *(Done: extracted from the `@Test` functions in `AppTests/*Tests.swift` because the runner logs display names, not identifiers; 39 lines, equal to the runner's "39 tests in 3 suites". The plain name `iPhone 16` matched several simulators, so the gates ran with `-destination 'id=<booted iPhone 16>'`.)*
- [X] T002 Commit the 005 spec artifacts (`specs/005-mvvm-refactor/**`; `.specify/feature.json` is git-ignored local state) as `docs: spec, plan and tasks for MVVM refactor (005)`.

## Phase 2: Foundational

None. US1's moves are the base the other stories build on, so they are done first (see Dependencies).

---

## Phase 3: User Story 1 - Each screen's view and view model are found together (Priority: P1) 🎯 MVP

**Goal**: rename to `…ViewModel`/`BrowseView` and move into feature folders, with no behaviour change (FR-001…FR-003).

**Independent Test**:
- the tree matches plan.md › Project Structure;
- G-app passes;
- the test list equals the baseline with `ModelTests` → `ViewModelTests` (quickstart › Test-set proof).

All of Phase 3 is **one atomic commit**: `refactor: View/ViewModel names and feature-slice folders (005 T003–T012)`.

- [X] T003 [US1] Create the folders and `git mv` the files (the project uses file-system-synchronised groups, so no `project.pbxproj` edit):
  - `App/RootView.swift` → `App/Features/Browse/BrowseView.swift`
  - `App/Features/BrowseModel.swift` → `App/Features/Browse/BrowseViewModel.swift`
  - `App/Search/SearchView.swift` → `App/Features/Search/SearchView.swift`
  - `App/Features/SearchModel.swift` → `App/Features/Search/SearchViewModel.swift`
  - `App/Forecast/{ForecastView,ActivitySection,DayCell,DayDetailView}.swift` → `App/Features/Forecast/`
  - `App/Features/ForecastModel.swift` → `App/Features/Forecast/ForecastViewModel.swift`
  - `App/Features/LoadState.swift` → `App/Views/LoadStateView/LoadState.swift`
  - `App/Shared/LoadStateView.swift` → `App/Views/LoadStateView/LoadStateView.swift`
  - `AppTests/{Search,Forecast,Browse}ModelTests.swift` → `AppTests/{Search,Forecast,Browse}ViewModelTests.swift`

  Remove the now-empty `App/Search/` and `App/Forecast/`.
- [X] T004 [P] [US1] Rename `final class SearchModel` → `SearchViewModel` in `App/Features/Search/SearchViewModel.swift`. Keep the doc comment, changing "Screen model" to "View model".
- [X] T005 [P] [US1] Rename `final class ForecastModel` → `ForecastViewModel` in `App/Features/Forecast/ForecastViewModel.swift`. Leave `selectedDay` untouched for now (US3 changes it).
- [X] T006 [US1] Rename `final class BrowseModel` → `BrowseViewModel` in `App/Features/Browse/BrowseViewModel.swift`, along with its member types: `let search: SearchViewModel`, `private(set) var forecast: ForecastViewModel?`, and the `SearchViewModel(...)`/`ForecastViewModel(...)` initialisers. Keep the comment citing `specs/003 … data-model.md › BrowseModel`, and add "(now `BrowseViewModel`, specs/005 data-model.md)".
- [X] T007 [US1] In `App/Features/Browse/BrowseView.swift`, rename `struct RootView` → `BrowseView` and `@Bindable var browse: BrowseViewModel`, and update both `#Preview`s.
- [X] T008 [P] [US1] In `App/Features/Search/SearchView.swift`, change to `@Bindable var browse: BrowseViewModel` and `private var search: SearchViewModel`, and update `searchPreview(_:query:)`.
- [X] T009 [P] [US1] In `App/Features/Forecast/ForecastView.swift`, change to `let model: ForecastViewModel` and update the three `#Preview`s.
- [X] T010 [US1] In `App/ActivityForecastApp.swift`, change to `@State private var browse = BrowseViewModel(service: OpenMeteoClient())` and `BrowseView(browse: browse)`.
- [X] T011 [US1] Rename the test suites and their references:
  - `struct SearchModelTests` → `SearchViewModelTests` in `AppTests/SearchViewModelTests.swift`, `ForecastModelTests` → `ForecastViewModelTests` in `AppTests/ForecastViewModelTests.swift`, `BrowseModelTests` → `BrowseViewModelTests` in `AppTests/BrowseViewModelTests.swift`;
  - the `@Suite("…")` titles;
  - every `SearchModel(`/`ForecastModel(`/`BrowseModel(` constructor call;
  - the cross-suite fixture references (`SearchModelTests.parisFrance` → `SearchViewModelTests.parisFrance`, `ForecastModelTests.alpineWeek` → `ForecastViewModelTests.alpineWeek`).

  Test bodies are otherwise unchanged.
- [X] T012 [US1] Verify, then make the Phase 3 commit:
  - G-lint is 0;
  - G-app passes;
  - the test list equals `baseline-vm-tests.txt` after `sed 's/ModelTests/ViewModelTests/'` (same count);
  - `grep -rnw -e SearchModel -e ForecastModel -e BrowseModel -e RootView App AppTests | grep -v 'specs/'` shows no matches.

**Checkpoint**: US1 is complete and shippable on its own.

---

## Phase 4: User Story 2 - Choosing a place is a view-model rule, covered by tests (Priority: P1)

**Goal**: `BrowseViewModel.selection` is bindable, and `SearchView` binds it directly (FR-004, FR-005, research R1).

**Independent Test**: the new tests pass, and `SearchView` contains no `Binding(get:`.

### Tests (red)

- [ ] T013 [US2] Add three `@Test`s to `AppTests/BrowseViewModelTests.swift`, using the existing `StubWeatherService`, `Recorder` and `ForecastViewModelTests.alpineWeek` fixtures:
  - (a) `selectionSelects`: on a fresh model, setting `model.selection = Self.paris` makes `selectedPlace == Self.paris`, `selection == Self.paris`, and `forecast?.state == .loading`;
  - (b) `selectionReselectKeepsForecast`: set the selection, `await model.forecast!.load()`, then set the same place again. The result is the identical forecast instance (`===`), it is not `.loading`, and the recorder shows exactly one fetch;
  - (c) `selectionNilClears`: setting `nil` makes `selectedPlace == nil` and `forecast == nil`.

  Run G-app and confirm it **fails to compile or fails**. Commit `test: bindable browse selection (005 T013, red)`.

### Implementation (green)

- [ ] T014 [US2] In `App/Features/Browse/BrowseViewModel.swift`, add the doc-commented `var selection: Place? { get { selectedPlace } set { select(newValue) } }`. The comment should say: "Bindable selection for the search list; setting it applies `select(_:)`'s rules (specs/005 FR-004)". Run G-app, which must pass. Commit `feat: bindable browse selection (005 T014, green)`.
- [ ] T015 [US2] In `App/Features/Search/SearchView.swift`:
  - replace `List(places, selection: selection)` with `List(places, selection: $browse.selection)`;
  - delete the private `selection: Binding<Place?>` property;
  - move its "(FR-008)" comment onto the `List` line.

  Run G-app and G-lint, then commit `refactor: search list binds the view-model selection (005 T015)`.

**Checkpoint**: US2 is complete. Place selection works on iPhone (push) and iPad (detail column).

---

## Phase 5: User Story 3 - Opening a day's detail is a view-model intent, covered by tests (Priority: P2)

**Goal**: `presentedDay: PresentedDay?` and `showDetail(for:)` live in `ForecastViewModel`, and `ForecastView` binds the sheet directly (FR-006, FR-007, research R2/R3).

**Independent Test**: the new tests pass. `ForecastView` contains no `DaySelection` and no `Binding(get:`.

### Tests (red)

- [ ] T016 [US3] In `AppTests/ForecastViewModelTests.swift`, replace the `selectedDayRoundTrip` test with three `@Test`s:
  - (a) `showDetailPresentsDay`: `presentedDay` starts as `nil`. After `model.showDetail(for: day)`, `presentedDay?.day == day` and `presentedDay?.id == day`. Then `showDetail(for: otherDay)` replaces it with `otherDay`;
  - (b) `dismissClearsPresentedDay`: show a day, then set `model.presentedDay = nil`. The result is `nil`, and `showDetail(for: day)` presents it again;
  - (c) `presentedDaySurvivesReload`: load the week, show a day, then `await model.loadIfNeeded()`. The same day is still presented, and the recorder shows one fetch.

  Take the days from the loaded ranking, as the old test did. Run G-app and confirm red. Commit `test: forecast day presentation intent (005 T016, red)`.

### Implementation (green)

- [ ] T017 [US3] In `App/Features/Forecast/ForecastViewModel.swift`:
  - replace `var selectedDay: DaySuitability?` with `var presentedDay: PresentedDay?`, keeping the "survives a fold/resize (specs/003 US3)" comment and adding "the sheet binding clears it on dismiss";
  - add `func showDetail(for day: DaySuitability) { presentedDay = PresentedDay(day: day) }`;
  - add, at file scope, `nonisolated struct PresentedDay: Identifiable, Hashable, Sendable { let day: DaySuitability; var id: DaySuitability { day } }` with a doc comment.

  Run G-app, which must pass. Commit `feat: forecast day presentation intent (005 T017, green)`.
- [ ] T018 [US3] In `App/Features/Forecast/ForecastView.swift`:
  - in `body`, add `@Bindable var model = model`;
  - make `ActivitySection`'s trailing closure `model.showDetail(for: $0)`, or `{ day in model.showDetail(for: day) }`;
  - change the sheet to `.sheet(item: $model.presentedDay) { presented in dayDetail(presented.day) }`;
  - delete `daySelection` and the private `struct DaySelection`.

  Run G-app and G-lint, then commit `refactor: forecast sheet binds the view-model presented day (005 T018)`.

**Checkpoint**: all user stories are complete.

---

## Phase 6: Polish & Cross-Cutting

- [ ] T019 [P] Update `CLAUDE.md` › Architecture:
  - the paths (`App/Features/{Browse,Search,Forecast}/`, `App/Views/LoadStateView/`, `App/RootView.swift` → `App/Features/Browse/BrowseView.swift`);
  - the names (`SearchViewModel`, `ForecastViewModel`, `BrowseViewModel`, `ForecastViewModel.presentedDay`, `BrowseViewModel.selection`);
  - the example `-only-testing:ActivityForecastTests/SearchViewModelTests`;
  - add `005 MVVM refactor` to the spec list in Workflow conventions.
- [ ] T020 [P] Update `README.md`: the architecture lines (around line 54–56, `RootView` and `App/Features (view models) BrowseModel → …`) and any other reference to the old names or folders.
- [ ] T021 Final gates (quickstart.md):
  - G-lint is 0, `swift test` passes, G-app passes, and the clean simulator build has 0 project warnings;
  - Release `nm` check: no `StubWeatherService`/`PreviewData` symbols;
  - the test-list diff against the baseline shows only renames plus the 6 new tests minus `selectedDayRoundTrip`;
  - `grep -rn "Binding(get" App/` is empty.

  Commit `docs: CLAUDE.md and README for MVVM refactor (005 T019–T021)`.
- [ ] T022 Manual checks from quickstart.md › Manual layout checks (iPhone; Duo outer/inner with an open sheet across a fold; iPad full screen and Split View). Record the results for the PR description, then mark the tasks done in this file.

---

## Dependencies & Execution Order

- **Setup (T001–T002)** comes first: T001 must record the baseline before any code change.
- **US1 (T003–T012)** blocks US2 and US3, because the new tests and code use the final names and paths. Within it, T003 comes first, then T004/T005 [P], then T006, T007, T008/T009 [P], then T010, T011, T012.
- **US2 (T013–T015)** and **US3 (T016–T018)** are independent of each other once US1 is done; either order works. Within each story, red comes before green, which comes before the view update.
- **Polish (T019–T022)** comes after all stories. T019 and T020 can run in parallel.

## Parallel Opportunities

- US1: T004 ∥ T005 (different files); T008 ∥ T009.
- After US1: US2 and US3 can proceed in parallel. They touch different files: Browse VM/tests/SearchView versus Forecast VM/tests/ForecastView.
- Polish: T019 ∥ T020.

## Implementation Strategy

- **MVP = US1**: the naming and structure, already a reviewable, behaviour-identical PR on its own.
- Then US2: the selection binding, with tests.
- Then US3: the day sheet, with tests.
- Then docs and gates.

Each checkpoint leaves the app building with all tests green.
