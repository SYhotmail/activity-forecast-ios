# Feature Specification: Stricter MVVM in the App Layer

**Feature Branch**: `refactoring-better-mvvm`

**Created**: 2026-11-04

**Status**: Draft

**Input**: User description: "Refactor the app based on MVVM architecture." The agreed scope covers three things:
- rename to the View/ViewModel convention;
- organise the files by feature;
- move the state wiring that still lives in views (place selection, day-sheet presentation) into the view models as tested intents.

Out of scope:
- The search debounce stays view-driven.
- No ViewData layer.
- No `ForecastKit` changes.
- No user-visible change, except the bug fix in FR-012 (found during the manual check).

## Context

The app is already layered MVVM: each screen has an observable view model, views render a single load state, and data comes through the weather service protocol. Three gaps remain against a strict MVVM reading.

1. **Naming and layout.** The view models are named `…Model`, which does not show which view each one pairs with. They also sit in one folder, apart from their views, so the files are grouped by kind rather than by feature.
2. **Wiring in views.** The search screen turns its list selection into a "select this place" call itself. The forecast screen keeps a private wrapper type that makes a day presentable as a sheet, and it maps the view model's open day to and from that wrapper itself.
3. **Untested wiring.** Because that wiring lives in views, no automated test covers it.

This is a structural change. The end user sees no difference, except that a forecast that could spin forever after picking a new city now loads (FR-012).

## Clarifications

### Session 2026-11-04

- Q: How far should the refactor go? → A: Renames, feature-slice folders, and moving the selection and day-sheet wiring into the view models. The debounce stays in the view (specs/003 research R5). No ViewData layer.
- Q: Where do the shared load-state type and its view live? → A: Together in their own folder, `App/Views/LoadStateView/`, not in `Shared/`.
- Q: Track as a spec or as a plain refactor? → A: As a spec (this feature).
- Bug found in the T022 manual check (iPhone 18 Pro): after a loaded city, picking a new one (Minsk) showed an endless spinner. A trace showed SwiftUI sending the forecast screen a stray disappear mid-push, which cancelled its `.task` while it stayed visible, and nothing restarted the load. The bug predates this feature. Q: Fix? → A: The forecast view model owns its request; a view's task being cancelled no longer stops it, and deselecting the place cancels it (FR-012).

## User Scenarios & Testing *(mandatory)*

The "users" of this change are the developers and reviewers of the codebase. The end user of the app must see no difference.

### User Story 1 - Each screen's view and view model are found together (Priority: P1)

A developer looking for a screen finds its view and view model side by side, in one folder named after the feature. The names show which view each view model pairs with. Code that every screen shares (the load-state type and its view, formatting, preview data, the fake service) lives outside the feature folders.

**Why this priority**: it is the most visible part of the request, and every later change navigates by this structure.

**Independent Test**: open the app source tree.
- Each of the browse, search and forecast features has one folder holding its view and its view model.
- Every view model's name is its view's name plus "ViewModel".
- The app builds, and every existing view-model test passes under its new name, with the same number of tests.

**Acceptance Scenarios**:

1. **Given** the app source tree, **When** a reviewer opens the search feature folder, **Then** it holds the search view and the search view model and nothing from other features.
2. **Given** the renamed code, **When** all test suites run, **Then** every view-model behaviour tested before the change passes, and no test was dropped.
3. **Given** the app after the change, **When** a user searches, selects a place, opens a day and retries after an error, **Then** everything behaves exactly as before on iPhone, iPhone Duo and iPad.

---

### User Story 2 - Choosing a place is a view-model rule, covered by tests (Priority: P1)

When the user picks a place in the search list, the list binds straight to the browse view model's selection. The view no longer turns the selection into a call itself. The existing rules still apply, and tests now cover them through the selection the list uses:
- re-selecting the current place keeps its loaded forecast;
- choosing another place starts a fresh forecast;
- clearing the selection clears the forecast.

**Why this priority**: selection drives the whole adaptive layout (detail column on wide screens, push on narrow ones), so its rules must be tested where the view uses them.

**Independent Test**: unit tests set the selection the list binds to and check the selected place and its forecast. The search view has no hand-written selection binding left.

**Acceptance Scenarios**:

1. **Given** nothing is selected, **When** the selection is set to a place, **Then** that place is selected and its forecast starts loading.
2. **Given** a place with a loaded forecast is selected, **When** the selection is set to the same place again, **Then** the same forecast is kept and nothing is fetched again.
3. **Given** a place is selected, **When** the selection is cleared, **Then** no place is selected and no forecast is shown.

---

### User Story 3 - Opening a day's detail is a view-model intent, covered by tests (Priority: P2)

When the user taps a day, the view asks the forecast view model to show that day's detail. The sheet binds straight to the day the view model presents. Closing the sheet clears that day. The view no longer needs its own wrapper type or mapping. As before, the open day survives a fold or window resize, because it lives in the view model.

**Why this priority**: it removes the last piece of presentation state handled by a view, and adds test coverage for the sheet surviving a resize (specs/003 US3). It ranks below US2 because the sheet affects one screen, not the whole layout.

**Independent Test**: unit tests ask the view model to show a day, check that the day is presented, ask it to dismiss, and check that nothing is presented. The forecast view has no private presentation wrapper left.

**Acceptance Scenarios**:

1. **Given** a loaded forecast with no day open, **When** the view model is asked to show a day's detail, **Then** that day is presented.
2. **Given** a day is presented, **When** the sheet is dismissed (the presented day is cleared), **Then** no day is presented, and showing a day afterwards opens it again.
3. **Given** a day is presented, **When** the screen asks to load again because a resize rebuilt it, **Then** the same day is still presented and the forecast is not fetched again.

---

### Edge Cases

- Showing a different day while one is already presented replaces it. One sheet at most.
- Swiping the sheet down and tapping Done both clear the presented day, so the next tap opens the sheet again.
- Setting the selection to the place that is already selected, for example when a rebuilt list reports its current selection again, never restarts a loaded forecast.
- Selecting another place replaces the forecast. The old forecast's open day goes with it, so no stale sheet appears for the new place.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each screen's view model MUST be named after its view plus "ViewModel" (browse, search, forecast). The root view MUST be renamed to match the browse view model.
- **FR-002**: Each feature's views and view model MUST live together in one feature folder (browse, search, forecast).
- **FR-003**: The shared load-state type and its view MUST live together in one dedicated folder for shared views. Formatting helpers, preview data and the fake weather service stay in the shared folder.
- **FR-004**: The browse view model MUST expose a selection that a list can bind to directly. Setting it MUST follow the existing selection rules: re-selecting keeps the forecast, a new place gets a fresh forecast, and clearing removes the forecast.
- **FR-005**: The search view MUST bind its list selection to that view-model selection, with no hand-written selection binding.
- **FR-006**: The forecast view model MUST expose the presented day as a value a sheet can bind to directly. It MUST provide an intent to show a day's detail. Dismissing the sheet clears the presented day through that same value (research R3).
- **FR-007**: The forecast view MUST present the day-detail sheet from that view-model value and route day taps through the show intent. No private presentation wrapper or mapping may remain in the view.
- **FR-008**: The search debounce MUST stay driven by the view, unchanged (specs/003 research R5).
- **FR-009**: Apart from the FR-012 fix, no user-visible behaviour MAY change: the screens, states, the adaptive layout, keeping state across a resize, accessibility and the release binary's contents.
- **FR-010**: The new view-model behaviours (FR-004, FR-006) MUST be developed test-first, with red and green commits. All view-model tests that existed before the change MUST still pass under their new names, except two deliberate changes: `selectedDayRoundTrip` is replaced by the presentation tests (FR-006), and the two cancellation tests are rewritten for FR-012 (`cancelledResultDropped` cancels through the view model, and `cancelledLoadIfNeededRestarts` becomes `cancelledViewTaskKeepsLoading`).
- **FR-011**: The living project documentation (the project guide and the README) MUST describe the new names and layout. Earlier feature specs stay unchanged as history. This feature's data model records the mapping from old names to new.
- **FR-012**: A forecast request MUST NOT be stopped by the screen's own appear/disappear cycle. It is cancelled only when the place is deselected or replaced (Back, or picking another place), or when a retry supersedes it; a cancelled request's result is never shown. A second load request while one is running joins it instead of fetching again.

### Key Entities

- **Browse view model**: owns the search, the selected place, and that place's forecast. It now exposes a bindable selection.
- **Search view model**: the query and the place-search state. It is renamed only.
- **Forecast view model**: one place's week and the day presented in the detail sheet. It now exposes a show intent; dismissing clears the presented day. It owns its fetch, which can be cancelled when the place is deselected (FR-012).
- **Presented day**: the day whose detail sheet is open, in a form a sheet can identify. It replaces the view's private wrapper.
- **Load state**: unchanged. It moves to the shared-views folder together with its view.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After the renames (US1), the view-model test list equals the baseline exactly. At the end it differs only by the replacements and rewrites listed in FR-010 and by the new tests.
- **SC-002**: At least 5 new view-model tests cover selection (3) and day presentation (2 or more). They are written first, with red then green commits.
- **SC-003**: The views contain 0 hand-written bindings for selection or the day sheet, and 0 private presentation wrapper types.
- **SC-004**: All four quality gates pass: lint with 0 violations, package tests, app tests, and a clean build with 0 warnings. The release binary still contains 0 preview or fake-service symbols.
- **SC-005**: The manual layout checks (iPhone, iPhone Duo outer and inner displays, iPad full screen and Split View) show no behavioural difference from before the change.
- **SC-006**: Tests prove that a cancelled view task does not stop a forecast request, that a second load joins the running one (one fetch), and that selecting another place cancels the old request. They are written red, then green. On the iPhone 18 Pro, picking a city after an already-loaded one shows its forecast with no endless spinner.

## Assumptions

- The project uses file-system-synchronised groups, so moving files needs no project-file edits.
- `ForecastKit` and its public interface do not change.
- No constitution amendment is needed. Principle IV, test-first view models, covers the new intents. Principle V, no speculative abstractions, is respected: no new protocols or layers are added.
- Code comments that cite earlier specs by old type names (for example "specs/003 data-model.md › BrowseModel") stay valid through the name mapping in this feature's data model.
- The `005` number is also used by the unmerged `005-map-place-selection` branch. If that branch is merged later, one of the two spec folders must be renumbered.
