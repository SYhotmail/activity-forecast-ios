# Feature Specification: Select a Place on a Map

**Feature Branch**: `005-map-place-selection`

**Created**: 2026-11-04

**Status**: Draft

**Input**: User description: "add ability to select city on map in addition to using search bar"

## Context

Today the only way to choose a place is to type its name in the search bar and pick a result. That works when the user knows the name, but not when they know *where* they want to go: a ski slope above a village, a beach between two towns, "somewhere on that coast". This feature adds a map as a second way to choose a place. Search stays exactly as it is.

## Clarifications

### Session 2026-11-04

- Q: What happens when the user taps the map? → A: Any point can be selected. The selection is named after the nearest town or city; if there is none, or naming fails, it is named by its coordinates. Ski slopes and surf beaches away from towns can therefore be picked.
- Q: Where does the map live relative to the search? → A: The map is shown in the search area whenever the search text is empty. Typing replaces it with the existing result list; clearing the text brings the map back.
- Q: How far away can the nearest town or city be and still name a tapped point? → A: Within 25 km. Further away, the point is named by its coordinates.
- Q: On a phone, should one tap open the forecast straight away, or first show the marker with a "Show forecast" button? → A: In a narrow layout (phone, folded Duo), a tap shows the marker and name with a "Show forecast" button, which opens the forecast. In a wide layout, the forecast beside the map updates immediately.
- Q: What should the map show when it first appears? → A: The country from the device's region setting (no permission needed); the whole world if the region is unknown or has no country.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pick a spot on the map (Priority: P1)

A user opens the app with an empty search and sees a map. They pan and zoom to the area they care about and tap a point. A marker appears where they tapped, the spot is named after the nearest town or city, and that spot's ranked 7-day forecast is shown, exactly as if they had picked it from search results. In a wide window the forecast beside the map updates at once. In a narrow layout the user first sees the marker and name with a "Show forecast" button, so a mistaken tap can be corrected without leaving the map.

**Why this priority**: This is the feature. Without it, the map adds nothing.

**Independent Test**: With an empty search, tap a point near a known town and check that a marker appears, the town's name is shown, and the forecast for that spot opens in the same place a search result would open it (side column immediately in a wide window; in a narrow one, a pushed screen with Back after tapping "Show forecast").

**Acceptance Scenarios**:

1. **Given** the search text is empty, **When** the app shows the search area, **Then** an interactive map is shown in place of the "type to search" hint.
2. **Given** the map is shown, **When** the user taps a point close to a town, **Then** a marker appears at that point, the selection is named after that town with its region and country, and the 7-day ranked forecast for the tapped point is shown in the detail column (wide layout) or offered with a "Show forecast" button (narrow layout).
3. **Given** a narrow layout with a point marked, **When** the user taps "Show forecast", **Then** the forecast for that point is pushed with Back returning to the map; **When** they tap a different point instead, **Then** the marker moves and nothing is pushed.
4. **Given** the map is shown, **When** the user taps a point with no town nearby (open sea, remote mountains), **Then** the selection is named by its coordinates and the forecast for that point is still shown.
5. **Given** a point is already selected, **When** the user taps a different point, **Then** the new point replaces the old selection and its forecast replaces the old one (at once in a wide layout; in a narrow layout, once "Show forecast" is chosen).
6. **Given** the map is shown, **When** the user types in the search bar, **Then** the map is replaced by the existing search states (hint, loading, results, empty, error).
7. **Given** the user has typed text, **When** they clear it, **Then** the map returns showing the same area as before.

---

### User Story 2 - The map reflects the current selection (Priority: P2)

A user picks a place from search results, then clears the search. The map shows that place marked and centred, so map and search always agree about which place is selected. Folding, rotating or resizing the window keeps the map where it was.

**Why this priority**: Keeps the two ways of choosing consistent, but the core value (US1) works without it.

**Independent Test**: Search "Paris", pick it, clear the search: the map is centred on Paris with a marker. Fold/unfold or resize the window: the map area and marker stay.

**Acceptance Scenarios**:

1. **Given** a place was selected from search results, **When** the user clears the search text, **Then** the map is centred on that place with a marker on it.
2. **Given** the map shows a selected place, **When** the device is folded or unfolded, rotated, or the window is resized, **Then** the map shows the same area, the same marker and the same forecast.

---

### User Story 3 - Clear feedback while the spot is being named (Priority: P3)

Naming a tapped spot takes a moment. The user sees the marker straight away with a "locating" label, then the name. If naming fails (for example, offline), the spot is shown by its coordinates and its forecast can still be loaded.

**Why this priority**: Polishes the experience and covers failure; US1 is usable without the intermediate label.

**Independent Test**: Tap the map on a slow or offline connection: the marker appears immediately with a locating label, then a name or coordinates; the forecast area shows its existing loading, error and retry states.

**Acceptance Scenarios**:

1. **Given** the user taps the map, **When** the name is not yet known, **Then** the marker is shown at once with a "locating" label.
2. **Given** naming fails, **When** the failure is known, **Then** the selection is named by its coordinates, no naming error is shown, and the forecast is still requested (at once in a wide layout, or on "Show forecast" in a narrow one).
3. **Given** the forecast request fails, **When** the forecast area is shown, **Then** it shows the existing error message with retry.

### Edge Cases

- The user taps several points in quick succession: only the last tap counts; a name for an earlier tap never appears on the later marker.
- The user taps while offline: the marker appears, the name falls back to coordinates, and the forecast shows its existing offline error with retry.
- The user taps the open sea, near a pole or across the date line: coordinates are shown correctly (latitude and longitude with hemisphere) and a forecast is requested.
- The user taps the marker of the place already selected: the loaded forecast stays as it is, with no reload.
- The nearest town or city is more than 25 km away: the point is named by its coordinates, not after that town.
- The device's region is unknown or names no country: the map first shows the whole world.
- The user pans or zooms: nothing is selected.
- The search text is one character: the existing "type at least 2 letters" hint is shown, not the map (the map appears only when the text is empty).
- A VoiceOver user cannot aim at a map point: search remains a complete way to choose a place, and the marker is announced with the place's name.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The search area MUST show an interactive map (pan and zoom) whenever the search text, ignoring surrounding spaces, is empty. When the text is not empty, it MUST show the existing search states unchanged (specs/001).
- **FR-002**: Users MUST be able to select any point on the map, on land or at sea, by tapping it.
- **FR-003**: A selected point MUST be named after the nearest town or city, with region and country, displayed the same way as a search result (name, then "region, country"). If no town or city is found within 25 km of the point, or naming fails, it MUST be named by its coordinates (latitude and longitude, with hemisphere).
- **FR-004**: A marker MUST appear at the tapped point immediately, before naming finishes, with a "locating" label until the name is known.
- **FR-005**: Selecting a point on the map MUST show the same ranked 7-day forecast as selecting a search result. In a wide layout, the forecast in the detail column MUST update without any further action as soon as the point is named (or falls back to its coordinates). In a narrow layout, a tap MUST only mark and name the point and offer a "Show forecast" control. Choosing it MUST push the forecast with Back returning to the map. Tapping another point instead MUST move the marker without pushing anything.
- **FR-006**: The forecast for a map-selected point MUST be for that exact point, with its 7 days counted in that point's own local time zone (today + 6, as in specs/001).
- **FR-007**: Only the most recent tap MAY change the selection and its name. Naming for an earlier tap MUST be abandoned, MUST NOT overwrite a newer selection, and MUST NOT show an error.
- **FR-008**: A place selected from search results MUST be marked on the map, and when the search text is cleared the map MUST be centred on it.
- **FR-009**: The visible map area, the marker and the selection MUST be kept when the device is folded or unfolded, rotated or the window resized, and when the user switches between typing (results list) and an empty search (map).
- **FR-010**: Panning or zooming the map MUST NOT change the selection. Tapping the marker of the currently selected place MUST NOT reload its forecast.
- **FR-011**: The app MUST NOT ask for the user's location. Until the user moves the map or selects a place, it MUST show the country from the device's region setting, or the whole world when that region is unknown or names no country.
- **FR-012**: Search MUST remain a complete way to choose a place, so the feature never depends on precise pointing. The marker MUST have a screen-reader label with the place's name, and the map area MUST work with Dynamic Type and in Light and Dark appearance.

### Key Entities

- **Map selection**: a point the user tapped (latitude, longitude), its display name (nearest town or city with region and country, or a coordinate label) and whether naming is still in progress. Once chosen it becomes the app's selected place, exactly like a search result, and drives the forecast.
- **Map view area**: the part of the world currently visible (centre and zoom). Kept for the current session only.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From an empty search, a user gets a place's forecast in a single tap on the map in a wide layout, or a tap plus "Show forecast" in a narrow one (plus any panning and zooming to reach the area).
- **SC-002**: On a typical connection, the name of a tapped point is shown within 2 seconds in at least 95% of taps.
- **SC-003**: 100% of map taps produce a selection, named or by coordinates, and a forecast attempt (immediately in a wide layout, on "Show forecast" in a narrow one); no tap leaves the user without feedback.
- **SC-004**: In 100% of the manual layout checks (iPhone, both iPhone Duo displays, iPad window sizes), folding, rotating or resizing keeps the map area, marker and forecast.
- **SC-005**: Every check in the existing search and layout checklists (specs/001 and specs/003 quickstarts) still passes.

## Assumptions

- The map is the platform's built-in map: no third-party dependency and no API key, in line with the project constitution.
- Naming the nearest town or city may use a source other than the weather service's place search, since that search works by name only. The choice is made and documented in the plan and must stay keyless and free of extra dependencies.
- An internet connection is required, as for the rest of the app.
- The map area is not saved between launches (no persistence, per intent.md).
- Out of scope: showing the user's current location, favourites or history, drawing activity scores on the map, and searching map points of interest.
