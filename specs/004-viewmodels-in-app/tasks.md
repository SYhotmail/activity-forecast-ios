---
description: "Task list for View Models Live in the App"
---

# Tasks: View Models Live in the App

**Input**: Design documents from `/specs/004-viewmodels-in-app/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/forecastkit-api.md, quickstart.md

**Tests**: no new behaviour, so no new red/green pairs (constitution v2.0.0 IV; plan › Constitution Check). The 39 existing view-model test functions are **moved verbatim** (imports only) and must pass at every step. Each phase ends with gates 2 and 3 green:
- `swift test --package-path Packages/ForecastKit`
- `xcodebuild test -project ActivityForecast.xcodeproj -scheme ActivityForecast -destination 'platform=iOS Simulator,name=iPhone 16'`

**Delivery**: one branch (`004-viewmodels-in-app`), one PR. One commit per phase; Phase 4 is atomic (research R6).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on unfinished tasks)
- **[Story]**: US1 / US2 / US3 from spec.md
- Paths are relative to the repository root

---

## Phase 1: Setup

- [X] T001 Record the baseline on `004-viewmodels-in-app`:
  - lint 0, `swift test` 108 pass, clean build;
  - save the sorted test-function names of the three view-model suites to `specs/004-viewmodels-in-app/baseline-vm-tests.txt` (expected 39 lines), using `swift test --package-path Packages/ForecastKit list | grep -E 'SearchModelTests|ForecastModelTests|BrowseModelTests' | sed 's/^ForecastKitTests\.//' | sort`. Phase 4 compares against this list (quickstart #6).
- [X] T002 Commit the constitution v2.0.0 amendment first:
  - remove the Sync Impact Report HTML comment from `.specify/memory/constitution.md` (marked "remove before committing");
  - commit it, together with the 004 spec, plan, research, data model, contract and quickstart.

## Phase 2: Foundational (blocks US1 and US3): app unit-test target

- [ ] T003 Add the hosted unit-test target `ActivityForecastTests` to `ActivityForecast.xcodeproj/project.pbxproj` (research R4), preferably via Xcode › File › New › Target › Unit Testing Bundle (Swift Testing, target to be tested: ActivityForecast):
  - product type `com.apple.product-type.bundle.unit-test`;
  - `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/ActivityForecast.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/ActivityForecast"`, `BUNDLE_LOADER = "$(TEST_HOST)"`;
  - `IPHONEOS_DEPLOYMENT_TARGET = 18.0`, `SWIFT_VERSION = 6.0`, `GENERATE_INFOPLIST_FILE = YES`, `TARGETED_DEVICE_FAMILY = "1,2"`, bundle id `com.example.ActivityForecastTests`;
  - a file-system-synchronized root group for `AppTests/`;
  - a target dependency on `ActivityForecast`;
  - package product dependencies `ForecastKit` (and `ForecastKitTestSupport`, added in T006).

  Create `AppTests/SmokeTests.swift` with one `@Test func appModuleLinks()` that does `@testable import ActivityForecast` and passes. It proves the wiring and is deleted in T011.
- [ ] T004 Add `ActivityForecastTests` as a `TestableReference` (`skipped = "NO"`) in the Test action of `ActivityForecast.xcodeproj/xcshareddata/xcschemes/ActivityForecast.xcscheme`, next to the existing `ForecastKitTests` entry. Run gate 3 and expect `ForecastKitTests` and the smoke test to pass. Commit `chore: app unit-test target ActivityForecastTests (004 T003-T004)`.

**Checkpoint**: `xcodebuild test` runs both bundles.

---

## Phase 3: User Story 2: the fake weather service leaves production (P1)

**Goal**: `StubWeatherService` is no longer in the `ForecastKit` product. A developer-only `ForecastKitTestSupport` library provides it and the test helpers (FR-004, constitution V).

**Independent test**: `grep -rn StubWeatherService Packages/ForecastKit/Sources/ForecastKit` returns nothing. Package tests, app previews and gate 3 still pass. A Release build's binary has no `StubWeatherService`, `Gate` or `Recorder` symbols (quickstart #5).

- [ ] T005 [US2] In `Packages/ForecastKit/Package.swift`:
  - add the product `.library(name: "ForecastKitTestSupport", targets: ["ForecastKitTestSupport"])`;
  - add the target `.target(name: "ForecastKitTestSupport", dependencies: ["ForecastKit"])`;
  - add `"ForecastKitTestSupport"` to `ForecastKitTests`' dependencies.
- [ ] T006 [US2] Move the test doubles with `git mv`:
  - `Packages/ForecastKit/Sources/ForecastKit/Service/StubWeatherService.swift` → `Packages/ForecastKit/Sources/ForecastKitTestSupport/StubWeatherService.swift`. Add `import ForecastKit`; the type stays `public`.
  - `Packages/ForecastKit/Tests/ForecastKitTests/Support/Gate.swift` and `Recorder.swift` → `Packages/ForecastKit/Sources/ForecastKitTestSupport/`. Make `Gate`, its `init`, `open()` and `wait()` `public`. Make `Recorder`, `values` (keep `private(set)`) and `append(_:)` `public`, and add `public init() {}`.

  Add `import ForecastKitTestSupport` to the package suites that use them: `SearchModelTests.swift`, `ForecastModelTests.swift`, `BrowseModelTests.swift`. Link the `ForecastKitTestSupport` product to the `ActivityForecast` and `ActivityForecastTests` targets in `project.pbxproj`.
- [ ] T007 [US2] In `App/Shared/PreviewData.swift` (no `#if DEBUG` wrapper; previews are stripped from Release, research R3/R7), add `import ForecastKitTestSupport` under the existing imports. No other app file may import it (`grep -rn ForecastKitTestSupport App` → only PreviewData.swift).
- [ ] T008 [US2] Verify:
  - lint, gate 2 (108 pass), gate 3, previews build;
  - Release build: `xcodebuild -project ActivityForecast.xcodeproj -scheme ActivityForecast -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath <tmp> build`, then `nm -gU <tmp>/Build/Products/Release-iphonesimulator/ActivityForecast.app/ActivityForecast | grep -E 'StubWeatherService|4Gate|8Recorder'` must print nothing (quickstart #5).

  Commit `refactor: move StubWeatherService, Gate and Recorder to ForecastKitTestSupport (004 T005-T008)`.

**Checkpoint**: the test double is out of the production product.

---

## Phase 4: User Story 1 + User Story 3: view models in the app, still fully tested (P1 / P2)

These two stories ship in one atomic commit: the view models and their tests can't compile apart (research R6).

**Goal**:
- US1: the `ForecastKit` product contains only domain, scoring and data. The view models and `LoadState` live in the app (FR-001, FR-002, FR-003).
- US3: all 39 view-model tests run unchanged in `ActivityForecastTests` (FR-006, SC-002).

**Independent test**:
- quickstart #7: no view model or `LoadState` in `Packages/ForecastKit/Sources/ForecastKit`, and no `public` in `App/Features`;
- quickstart #6: the moved test names equal `baseline-vm-tests.txt`;
- gates 2 and 3 pass.

- [ ] T009 [US1] Split `Packages/ForecastKit/Sources/ForecastKit/Features/LoadState.swift`:
  - move `UserFacingError` (enum, cases and `message`, still `public`, doc comment kept) into the new `Packages/ForecastKit/Sources/ForecastKit/Service/UserFacingError.swift`;
  - `git mv` the remaining `LoadState` file to `App/Features/LoadState.swift`, drop `public` from `LoadState`, and add `import ForecastKit` (for `UserFacingError`).
- [ ] T010 [US1] `git mv` `Packages/ForecastKit/Sources/ForecastKit/Features/{SearchModel,ForecastModel,BrowseModel}.swift` → `App/Features/`. In each file:
  - add `import ForecastKit`;
  - remove every `public` modifier (types, inits, properties, methods), leaving them `internal`;
  - keep doc comments and spec references (e.g. `specs/003 FR-007`) unchanged.

  Delete the now-empty `Packages/ForecastKit/Sources/ForecastKit/Features/` directory.
- [ ] T011 [US3] `git mv` `Packages/ForecastKit/Tests/ForecastKitTests/{SearchModelTests,ForecastModelTests,BrowseModelTests}.swift` → `AppTests/`. In each, replace `@testable import ForecastKit` with `@testable import ActivityForecast`, `import ForecastKit` and `import ForecastKitTestSupport`. Change nothing else. Delete `AppTests/SmokeTests.swift`.
- [ ] T012 [US1] Fix the app compile, imports only:
  - `App/ActivityForecastApp.swift`, `App/RootView.swift`, `App/Search/SearchView.swift`, `App/Forecast/ForecastView.swift`, `App/Shared/LoadStateView.swift` keep `import ForecastKit` (domain types); the view models and `LoadState` now resolve from the app module.
  - If any `ForecastKit` source still references a moved type, the design is wrong. Stop and report rather than re-exporting it.
- [ ] T013 [US3] Verify:
  - quickstart #6: `xcodebuild test … -only-testing:ActivityForecastTests` lists the suites; the sorted function names equal `specs/004-viewmodels-in-app/baseline-vm-tests.txt`; `git diff -M --stat` shows the three test files as renames with only import lines changed (`git diff -M -- AppTests`);
  - quickstart #7 greps return nothing;
  - gates 1–4 pass; total tests (package + app) ≥ 108 (SC-003).

  Commit `refactor: view models and LoadState move to the app; tests to ActivityForecastTests (004 T009-T013)`.

**Checkpoint**: constitution v2.0.0 Principle V satisfied. `contracts/forecastkit-api.md` holds (check `grep -rhoE "^public (struct|enum|final class|protocol) [A-Za-z]+" Packages/ForecastKit/Sources/ForecastKit` against the contract list).

---

## Phase 5: Polish

- [ ] T014 [P] Update `README.md`:
  - Architecture diagram: `App/ (views + Features: BrowseModel, SearchModel, ForecastModel, LoadState)` → `ForecastKit (Models, Scoring, Service)`, plus `ForecastKitTestSupport (developer-only)`;
  - add the `xcodebuild test` command to the test commands;
  - replace "All logic lives in a local Swift package" with "Domain, scoring and data live in the package; view models live in the app and are tested in `ActivityForecastTests`".
- [ ] T015 [P] Update `CLAUDE.md`:
  - Commands: add `xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 16'` and `-only-testing:ActivityForecastTests/<Suite>` for one suite;
  - Architecture: `App/Features/` holds the view models; `ForecastKit` holds domain, scoring and data; `ForecastKitTestSupport` holds `StubWeatherService`, `Gate`, `Recorder`;
  - drop the "`App/` contains SwiftUI views only" wording;
  - Test support: `StubURLProtocol` stays in package tests.
- [ ] T016 Smoke run (quickstart #10): 001 quickstart #1–#6 and 003 quickstart #1–#4 on iPhone 16, iPhone Duo (folded and unfolded) and iPad. Steps needing taps are done by the author; record the results in the PR.
- [ ] T017 Mark completed tasks `[X]`; `git status` shows only planned files; delete `specs/004-viewmodels-in-app/baseline-vm-tests.txt` or keep it as evidence (keep: it documents SC-002).

---

## Dependencies & Execution Order

- T001 → T002 → Phase 2 (T003 → T004) → Phase 3 (T005 → T006 → T007 → T008) → Phase 4 (T009 → T010 → T011 → T012 → T013) → Phase 5
- Phase 3 needs Phase 2: T006 links the support product to the test target created in T003.
- Phase 4 needs Phase 3: the moved tests import `ForecastKitTestSupport`.
- T009–T012 are one atomic change; commit only after T013 passes.

## Parallel opportunities

- T014 ∥ T015 (different files).
- Within Phase 4, T009/T010 (sources) and T011 (tests) touch different files and can be edited in parallel, but are committed together.

## Implementation strategy

1. **MVP**: Phases 1–3. The test double is out of the production product, and the app test target exists and runs.
2. **Core**: Phase 4. The layering matches constitution v2.0.0, with all view-model tests moved and green.
3. **Finish**: Phase 5. Docs, the smoke run, and one PR with the gates and quickstart #5–#10 recorded.
