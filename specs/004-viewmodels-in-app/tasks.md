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

- [X] T003 Add the hosted unit-test target `ActivityForecastTests` to `ActivityForecast.xcodeproj/project.pbxproj` (research R4), preferably via Xcode › File › New › Target › Unit Testing Bundle (Swift Testing, target to be tested: ActivityForecast):
  - product type `com.apple.product-type.bundle.unit-test`;
  - `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/ActivityForecast.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/ActivityForecast"`, `BUNDLE_LOADER = "$(TEST_HOST)"`;
  - `IPHONEOS_DEPLOYMENT_TARGET = 18.0`, `SWIFT_VERSION = 6.0`, `GENERATE_INFOPLIST_FILE = YES`, `TARGETED_DEVICE_FAMILY = "1,2"`, bundle id `com.example.ActivityForecastTests`;
  - a file-system-synchronized root group for `AppTests/`;
  - a target dependency on `ActivityForecast`;
  - no package product dependencies: `ForecastKit` resolves from the host app through `BUNDLE_LOADER` (research R4).

  Create `AppTests/SmokeTests.swift` with one `@Test func appModuleLinks()` that does `@testable import ActivityForecast` and passes. It proves the wiring and is deleted in T011.
- [X] T004 Add `ActivityForecastTests` as a `TestableReference` (`skipped = "NO"`) in the Test action of `ActivityForecast.xcodeproj/xcshareddata/xcschemes/ActivityForecast.xcscheme`, next to the existing `ForecastKitTests` entry. Run gate 3 and expect `ForecastKitTests` and the smoke test to pass. Commit `chore: app unit-test target ActivityForecastTests (004 T003-T004)`.

**Checkpoint**: `xcodebuild test` runs both bundles.

---

## Phase 3: User Story 2 + User Story 1 + User Story 3: one atomic move (revised during implementation)

The original Phases 3–4 planned a `ForecastKitTestSupport` package library (T005–T008), then the view-model move (T009–T013). Implementing T005–T008 showed the library shipped the stub, `Gate` and `Recorder` in Release (78/52/54 symbols) and duplicated `ForecastKit` at runtime ("implemented in both"). The owner chose Debug-only test doubles in the app (research R2, constitution 2.1.0). The stub can only leave the package together with the view-model tests that use it, so everything below shipped as one commit.

**Independent test**:
- quickstart #5: the Release binary has 0 stub, `Gate`, `Recorder` and `PreviewData` symbols, and no frameworks;
- quickstart #6: the moved test names equal `baseline-vm-tests.txt`;
- quickstart #7: no view model, `LoadState` or stub in the package, and no `public` in the app's moved files;
- gates 1–4 pass.

- [X] T005 [US2] `Packages/ForecastKit/Package.swift` keeps a single product, `ForecastKit` (comment added). The `ForecastKitTestSupport` library briefly added in this task was removed (research R2).
- [X] T006 [US2] `git mv` `Packages/ForecastKit/Sources/ForecastKit/Service/StubWeatherService.swift` → `App/Shared/StubWeatherService.swift`: internal, wrapped in `#if DEBUG`, `import ForecastKit`. `git mv` `Packages/ForecastKit/Tests/ForecastKitTests/Support/{Gate,Recorder}.swift` → `AppTests/Support/` (internal). `StubURLProtocol.swift` stays in package tests.
- [X] T007 [US2] `App/Shared/PreviewData.swift` and every `#Preview` block (ActivitySection, DayCell, DayDetailView, ForecastView, RootView, SearchView, LoadStateView) are wrapped in `#if DEBUG` again. `#Preview` bodies are compiled in Release (research R7). The SearchView preview helper takes `any WeatherService`.
- [X] T008 [US1] Split `Features/LoadState.swift`: `UserFacingError` moves to `Packages/ForecastKit/Sources/ForecastKit/Service/UserFacingError.swift` (public); `LoadState` moves to `App/Features/LoadState.swift` (internal, `import ForecastKit`).
- [X] T009 [US1] `git mv` `Packages/ForecastKit/Sources/ForecastKit/Features/{SearchModel,ForecastModel,BrowseModel}.swift` → `App/Features/`, with every `public` removed and `import ForecastKit` added. The empty `Features/` directory is removed.
- [X] T010 [US3] `git mv` the three view-model suites → `AppTests/`. Imports only: `import ForecastKit` + `@testable import ActivityForecast`. `AppTests/SmokeTests.swift` deleted.
- [X] T011 [US1] Removed the support-library product references from `ActivityForecast.xcodeproj/project.pbxproj`. The test target links no package products.
- [X] T012 [US3] Verified:
  - lint 0;
  - `swift test` 69 pass;
  - `xcodebuild test` 69 (`ForecastKitTests`) + 39 (`ActivityForecastTests`) = 108 pass, with no "implemented in both" warning;
  - clean Debug build with no warnings;
  - Release: Stub=0, Gate=0, Recorder=0, PreviewData=0, no Frameworks;
  - moved test names identical to the baseline (39);
  - each moved test file differs by imports only (3 lines);
  - the package's public surface matches `contracts/forecastkit-api.md`.
- [X] T013 Constitution amended to 2.1.0 (Principle V: Debug-only test doubles; previews in `#if DEBUG`). Spec, plan, research, data model, contract and quickstart updated to match.

**Checkpoint**: constitution 2.1.0 Principle V satisfied.

---

## Phase 5: Polish

- [ ] T014 [P] Update `README.md`:
  - Architecture diagram: `App/ (views + Features: BrowseModel, SearchModel, ForecastModel, LoadState)` → `ForecastKit (Models, Scoring, Service)`; test doubles are Debug-only in the app;
  - add the `xcodebuild test` command to the test commands;
  - replace "All logic lives in a local Swift package" with "Domain, scoring and data live in the package; view models live in the app and are tested in `ActivityForecastTests`".
- [ ] T015 [P] Update `CLAUDE.md`:
  - Commands: add `xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 16'` and `-only-testing:ActivityForecastTests/<Suite>` for one suite;
  - Architecture: `App/Features/` holds the view models; `ForecastKit` holds domain, scoring and data; `StubWeatherService` is Debug-only in `App/Shared`, `Gate`/`Recorder` are in `AppTests/Support`; previews stay in `#if DEBUG`;
  - drop the "`App/` contains SwiftUI views only" wording;
  - Test support: `StubURLProtocol` stays in package tests.
- [ ] T016 Smoke run (quickstart #10): 001 quickstart #1–#6 and 003 quickstart #1–#4 on iPhone 16, iPhone Duo (folded and unfolded) and iPad. Steps needing taps are done by the author; record the results in the PR.
- [ ] T017 Mark completed tasks `[X]`; `git status` shows only planned files; delete `specs/004-viewmodels-in-app/baseline-vm-tests.txt` or keep it as evidence (keep: it documents SC-002).

---

## Dependencies & Execution Order

- T001 → T002 → Phase 2 (T003 → T004) → Phase 3 (T005–T013, one atomic change) → Phase 5
- Phase 3 needs Phase 2: the moved tests go into the target created in T003.

## Parallel opportunities

- T014 ∥ T015 (different files).

## Implementation strategy

1. Phases 1–2: baseline, constitution, app test target.
2. Phase 3: one atomic move. View models and `LoadState` into the app, test doubles Debug-only, tests into `ActivityForecastTests`.
3. Phase 5: docs, the smoke run, and one PR with the gates and quickstart #5–#10 recorded.
