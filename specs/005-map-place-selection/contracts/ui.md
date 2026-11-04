# Contract: Map in the search sidebar

Extends [003 contracts/ui.md](../../003-universal-adaptive-layout/contracts/ui.md). Every search state, string and label defined in 001 and 003 is unchanged; when the search text is not empty they show in a drop-down card over the top of the map (FR-001).

## Sidebar content
| Search text (trimmed) | Sidebar shows |
|---|---|
| empty | **Map** (this contract) |
| 1 character | the existing idle hint "Type at least 2 letters to search" |
| ≥ 2 characters | the existing loading / results / "No places found…" / error + Retry |

The search field stays at the top in every case. Clearing the text returns to the map at the same camera position, with the same marker.

## Map
- Pan and pinch-zoom as standard. No user-location dot and no location prompt.
- First appearance: the whole world, then the device-region country if known (R6).
- **Marker**: a system marker at the selected point.
  - Title: the place name; while locating: "Locating…".
  - VoiceOver label: "Selected place, <name>" or "Selected place, locating".
- Tap on empty map → the marker moves there (locating).
- Tap on the current marker (within 22 pt) → nothing happens.

## Wide layout (regular width)
Once the marker is named, the detail column shows that place's forecast. There is no extra button.

## Narrow layout (compact width)
Once named, a callout under the marker shows:

| Element | Content |
|---|---|
| Title | place name (or coordinate label) |
| Subtitle | "region, country" when known |
| Button | **Show forecast**: pushes the forecast (same screen as from search); Back returns to the map |

Tapping elsewhere moves the marker and pushes nothing.

## Search selection on the map
A place picked from search results is the marker the next time the map shows, with the map centred on it at city zoom.

## Size changes
Fold/unfold, rotation and window resize keep the camera, the marker (including a locating one, which resumes naming), the selection and the forecast. A pin named in the narrow layout but not yet shown (its callout still open) is selected when the window becomes wide, so the map and the detail column show the same place (spec US2). Going wide → narrow never pushes anything by itself.
