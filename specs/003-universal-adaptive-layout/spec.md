# Feature Specification: Universal App with Adaptive Layouts

**Feature Branch**: `003-universal-adaptive-layout`

**Created**: 2026-11-04

**Status**: Draft

**Input**: User description: "Make the app universal with native iPad layouts for all window sizes, including iPhone Duo displays"

## Context

Constitution v1.1.1 (Principle III) requires the app to run natively on iPhone, on both displays of the foldable iPhone Duo, and on iPad at every window size. Today the app is iPhone-only: on iPad it runs as an enlarged iPhone app. It uses a single push-style flow (search, then forecast, then a day detail sheet) designed for a narrow portrait screen.

## Clarifications

### Session 2026-11-04

- Q: On wide windows, how should a day's detail open? → A: As a sheet over the forecast, as today, on every window size (no popover, no third column).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Use the app natively on iPad (Priority: P1)

An iPad user installs the app and gets a real iPad app that fills the screen at full resolution in portrait and landscape, not a magnified phone app with black borders.

**Why this priority**: without it the app is not available as an iPad app at all, and the constitution is not met. Everything else builds on it.

**Independent Test**: install on an iPad (simulator or device), rotate between portrait and landscape, and complete search → select a place → view the forecast → open a day's detail.

**Acceptance Scenarios**:

1. **Given** an iPad, **When** the user opens the app, **Then** it fills the whole screen at native resolution, with no compatibility scaling or letterboxing.
2. **Given** a loaded forecast on iPad, **When** the user rotates the device, **Then** the layout reflows to the new orientation and the user stays on the same place and forecast.
3. **Given** iPad full screen in either orientation, **When** the user searches, picks a place and taps a day, **Then** every step works as it does on iPhone, with all text and controls readable and reachable.

---

### User Story 2 - Make good use of wide windows (Priority: P2)

On a wide window (iPad full screen, iPad landscape, a wide Stage Manager window, or the iPhone Duo inner display), the user sees search results and the selected place's forecast side by side. They can switch places without navigating back.

**Why this priority**: it is the main reason to have a native wide layout, but the app is already usable on iPad after Story 1.

**Independent Test**: on a wide window, search "Paris", pick a result, then pick another result. Both the result list and the forecast stay visible throughout.

**Acceptance Scenarios**:

1. **Given** a wide window, **When** the user selects a search result, **Then** the forecast appears next to the result list, which stays visible.
2. **Given** a wide window showing a forecast, **When** the user selects a different place, **Then** the forecast is replaced in place, with no back navigation.
3. **Given** a wide window with no place selected, **When** the forecast area is shown, **Then** it shows a prompt to pick a place instead of being empty.
4. **Given** a narrow window (any iPhone, iPhone Duo outer display, iPad Slide Over, a narrow Split View or Stage Manager window), **When** the user uses the app, **Then** it behaves exactly as today: search, then forecast, then back.

---

### User Story 3 - Keep my place when the window changes size (Priority: P3)

A user is looking at a forecast and folds or unfolds an iPhone Duo, or resizes the app on iPad (enters or leaves Split View, drags a Stage Manager window, rotates). They stay on the same search, place, forecast and any open day detail, presented to suit the new size.

**Why this priority**: losing context on a fold or resize is jarring, and the constitution requires state to be kept, but it only matters once Stories 1–2 exist.

**Independent Test**: with a forecast loaded and a day detail open, fold or unfold (or resize between narrow and wide). The same place, the same forecast without reloading, and the same day detail are still shown.

**Acceptance Scenarios**:

1. **Given** a forecast is shown in a narrow window, **When** the window becomes wide, **Then** the side-by-side layout shows the same search results with that place selected and its forecast.
2. **Given** the side-by-side layout with a place selected, **When** the window becomes narrow, **Then** the user lands on that place's forecast, and going back shows the same search results.
3. **Given** a day detail is open, **When** the window size changes, **Then** the same day's detail remains open.
4. **Given** a loaded forecast, **When** the window size changes, **Then** the forecast is not fetched again.

---

### Edge Cases

- The window changes size while a search or forecast is loading. The request continues, and its result appears in the new layout without being lost or duplicated.
- The window changes size while an error with Retry is shown. The error and Retry remain available.
- The window changes size during an empty search ("No places found"). The empty state remains, with the query intact.
- The narrowest iPad Slide Over or Stage Manager window is narrower than most iPhones. The forecast's day cells must stay usable, scrolling sideways as on iPhone, with no truncated text.
- The largest accessibility text size on a wide window. Neither column may truncate or overlap text. The system may collapse the sidebar behind its toggle to give the forecast room.
- Keyboard and pointer on iPad: search, result selection and day selection can be done without touching the screen.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST be available on iPad as a native iPad app that fills the screen at native resolution, not in iPhone compatibility mode.
- **FR-002**: The app MUST support portrait and landscape on iPad and keep working when rotated.
- **FR-003**: On iPad the app MUST support multitasking: Split View (all widths), Slide Over and freely resizable Stage Manager windows. It MUST NOT force full screen.
- **FR-004**: The layout MUST be chosen from the space available to the app window, never from the device model. The same window width MUST give the same layout on iPad and iPhone Duo.
- **FR-005**: In a narrow window the app MUST present the current flow: search screen, then forecast screen with back navigation, then day detail.
- **FR-006**: In a wide window the app MUST show the search results and the selected place's forecast side by side, keep the results visible after selection, and show a "pick a place" prompt when nothing is selected.
- **FR-007**: When the window changes between narrow and wide, the app MUST keep the search query, the search results, the selected place, the loaded forecast and any open day detail, without fetching anything again.
- **FR-008**: Search, place selection, day selection and Retry MUST be usable with a hardware keyboard and a pointer on iPad.
- **FR-009**: Dynamic Type, VoiceOver and Light/Dark appearance MUST keep working on every window size. The VoiceOver wording defined in earlier features MUST NOT change.
- **FR-010**: Loading, empty, error-with-Retry and "No suitable day" states MUST appear correctly in both narrow and wide layouts.
- **FR-011**: Search, scoring, ranking and every displayed value MUST be identical on all devices and window sizes. Only the arrangement changes.
- **FR-012**: The day detail MUST open as a sheet over the forecast on every window size, as it does today. On wide windows it MAY appear as a centred card rather than full height, and closing it MUST return the user to the same forecast. On wide windows the sheet zooms out of the tapped day cell and back into it when closed; narrow windows keep the standard sheet presentation.

### Key Entities

- **Window size class**: narrow or wide, derived from the space the app window currently has. It changes at runtime (rotation, fold, Split View, Stage Manager resize) and determines the layout only.
- **Navigation state**: the search query and results, the selected place (if any) and the open day detail (if any). It is the same data in both layouts and is preserved across size changes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On iPad the app shows at native resolution in 100% of tested window configurations: portrait, landscape, Split View ⅓, ½ and ⅔, Slide Over, and three Stage Manager sizes.
- **SC-002**: In every tested configuration a user completes search → place → forecast → day detail with no truncated or overlapping text, including at the largest accessibility text size.
- **SC-003**: Across 10 consecutive size changes (fold/unfold or narrow↔wide resize) with a forecast and day detail open, the place, forecast and day detail are kept 10 out of 10 times, with no reload.
- **SC-004**: On a wide window, switching between two places takes one tap or click per switch, with no back navigation.
- **SC-005**: VoiceOver output for search results, section headers and day cells is word-for-word identical to the current app on every device.
- **SC-006**: Scores, rankings and best days for the same place and forecast are identical on iPhone, iPhone Duo (both displays) and iPad.

## Assumptions

- "Wide" and "narrow" follow the platform's standard width classes. The iPhone Duo inner display and iPad full screen count as wide. The Duo outer display, iPhones and iPad Slide Over count as narrow.
- The iOS 18 minimum stays (constitution Principle II). Multitasking behaviour is what iOS 18+ provides.
- No new content, features or data sources. Search, scoring and the APIs are unchanged (FR-011).
- iPhone Duo behaviour (outer and inner displays, fold and unfold) is verified on the iPhone Duo simulator (Xcode 27.2), and on a device when available.
- Mac (Designed for iPad / Catalyst), external displays and multiple simultaneous windows are out of scope.
- iPhone app icons from feature 002 already cover iPad through the single-size icon set. No new artwork is needed.
