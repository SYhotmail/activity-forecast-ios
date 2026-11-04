# Feature Specification: View Models Live in the App

**Feature Branch**: `004-viewmodels-in-app`

**Created**: 2026-11-04

**Status**: Draft

**Input**: User description: "Move out from ForecastKit View Models, place them into the app, Also StubWeatherService shouldn't be exported from the Kit, or placed into separate library inside the package."

## Context

Today the shared package (`ForecastKit`) contains four kinds of code:
- the domain (places, weather, scoring);
- the data layer (Open-Meteo client);
- the screen state models (search, forecast and browse view models, plus the screen load state);
- a fake weather service that is part of the package's public surface, even though only tests and previews use it.

The owner wants clearer ownership:
- The package provides domain and data only.
- The app owns its presentation state.
- The fake service is not part of the package's production surface.

This is a structural change. No user-visible behaviour changes.

This conflicts with the current constitution (v1.1.1):
- Principle V says "`App` holds views only".
- Principle IV's test-first rule and its "runs with `swift test`, no simulator" practice cover view models only while they live in the package.

The spec therefore depends on a constitution amendment (see Clarifications / FR-009).

## Clarifications

### Session 2026-11-04

- Q: Where should the fake weather service live? → A: A separate test-support library inside the package, shared by package tests, app tests and app previews. The release app does not link it.
- Q: Where should view-model tests run once the view models are in the app? → A: A new app unit-test target, run on a simulator as part of the pre-PR gates.

## User Scenarios & Testing *(mandatory)*

The "users" of this change are the developers and reviewers of the codebase. The end user of the app must see no difference.

### User Story 1 - Package exposes only domain and data (Priority: P1)

A developer opening the package sees only domain models, scoring and the weather data layer. Screen state (loading, loaded, empty, failed), search debouncing, retry and selection logic all live in the app, next to the screens that use them.

**Why this priority**: it is the core request, and it fixes the layering so each part owns one concern.

**Independent Test**: list the package's public declarations. None of them is a screen model or a screen load state. The app builds and runs exactly as before.

**Acceptance Scenarios**:

1. **Given** the package's public interface, **When** a reviewer inspects it, **Then** it contains no search, forecast or browse view model and no screen load-state type.
2. **Given** the app after the change, **When** a user searches, selects a place, opens a day and retries after an error, **Then** every screen and state behaves exactly as before on iPhone, iPhone Duo and iPad.
3. **Given** the weather data layer, **When** it reports a failure, **Then** it still uses the same user-facing error categories (offline, service unavailable, unexpected) that the app displays.

---

### User Story 2 - The fake weather service is not production surface (Priority: P1)

The fake service used by tests and previews is no longer part of the package's production interface, so it cannot be used by mistake in the shipping app.

**Why this priority**: it was named explicitly in the request, and it removes a test double from the production surface.

**Independent Test**: build the app's release configuration. The fake service is not reachable from production app code, while tests and previews still compile and run with it.

**Acceptance Scenarios**:

1. **Given** the package's production library, **When** a developer looks for the fake service, **Then** it is not there.
2. **Given** the app's SwiftUI previews and all test suites, **When** they are built and run, **Then** they still use a fake service and pass.

---

### User Story 3 - View-model behaviour stays proven by tests (Priority: P2)

Every rule the view models enforce today is still covered by automated tests after the move, and the tests still run before every pull request. The rules are:
- debounced search, and a stale result never wins;
- retry;
- no refetch on resize;
- the selection invariant;
- the open day survives a resize.

**Why this priority**: moving code must not lose the guarantees the previous features established, but it follows from Stories 1–2.

**Independent Test**: run the full test set. Every view-model behaviour test that exists today (the search, forecast and browse suites) still exists and passes in its new location.

**Acceptance Scenarios**:

1. **Given** the moved view models, **When** the test set runs, **Then** the same behaviours are verified with the same expectations, and none is dropped.
2. **Given** the pre-PR gates, **When** a contributor follows the documented commands, **Then** domain/data tests and view-model tests both run, and failures in either block the PR.

---

### Edge Cases

- Types used by both layers (the user-facing error categories) stay in the package, because the data layer throws them. Only the screen load-state wrapper moves.
- App previews depend on canned data and a fake service. They must keep working in debug builds without the fake service being part of the release app.
- View-model tests that use the timing helpers (the gate and recorder test utilities) must keep them available in their new location.
- No behaviour may change while code moves. Any test whose expectation would need editing (rather than relocating) signals an unintended change.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The package's production library MUST NOT contain the search, forecast or browse view models, or the screen load-state type.
- **FR-002**: The app MUST contain those view models and the screen load-state type, with unchanged behaviour.
- **FR-003**: The user-facing error categories MUST remain available to the data layer and to the app.
- **FR-004**: The fake weather service MUST NOT be part of the package's production library. It MUST live in a separate test-support library inside the package, used by package tests, app tests and app previews. The release app MUST NOT link it.
- **FR-005**: App previews MUST keep working in debug builds with canned data and a fake service.
- **FR-006**: Every existing view-model behaviour test MUST be kept, with unchanged expectations, and MUST run as part of the pre-PR gates, in a new app unit-test target run on a simulator.
- **FR-007**: Domain, scoring and data-layer tests MUST keep running without a simulator, as today.
- **FR-008**: End-user behaviour on iPhone, iPhone Duo and iPad MUST be identical before and after. This covers all screens, states, accessibility wording and state kept across resizes.
- **FR-009**: The project constitution MUST be amended before implementation so that the app may hold view models (Principle V), and so that test-first applies to view models in their new location (Principle IV).
- **FR-010**: Developer documentation (README, contributor guide) MUST describe the new ownership and the test commands.

### Key Entities

- **Screen models**: search, forecast and browse view models, plus the screen load state. They move from the package to the app.
- **User-facing error**: offline, service unavailable, unexpected. It stays in the package, shared by the data layer and the app.
- **Fake weather service**: the test and preview double. It leaves the package's production library.
- **Test support utilities**: the timing gate and argument recorder. They are available wherever the view-model tests run.
- **Test-support library**: a developer-only library in the package holding the fake weather service, linked by tests and debug previews, never by the release app.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The package's public interface contains 0 view-model or screen load-state declarations, and 0 fake-service declarations in its production library.
- **SC-002**: 100% of the view-model behaviour tests that exist today are present after the change with unchanged expectations, and all pass. That is the search, forecast and browse suites, currently 39 test functions across those 3 suites.
- **SC-003**: The full automated test set has at least as many tests as before (108), and all pass.
- **SC-004**: The manual quickstart checks for features 001 and 003 pass unchanged on iPhone, iPhone Duo and iPad.
- **SC-005**: A new contributor can tell where presentation logic belongs from the documentation alone: the README and contributor guide name the layer for view models, domain and data.

## Assumptions

- No new runtime dependencies (constitution Principle V). The new app test target and the test-support library are developer-only.
- Pre-PR gates gain a simulator test run for the app test target, alongside `swift test` for the package.
- The constitution amendment (FR-009) was made on 2026-11-04 as v2.0.0 (MAJOR: Principle V's layer boundary is redefined), before `/speckit-plan`.
- iOS 18 minimum and the Swift 6.4 toolchain are unchanged.
- Spec IDs in code comments (e.g. `specs/003 FR-007`) stay valid. Comments move with their code.
