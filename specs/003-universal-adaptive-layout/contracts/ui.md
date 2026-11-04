# Contract: Adaptive layout (wide vs narrow)

Extends [001 contracts/ui.md](../../001-activity-forecast-ranking/contracts/ui.md) and [002 contracts/ui.md](../../002-app-icons/contracts/ui.md). Every screen state, string and VoiceOver label defined there is unchanged. Only the arrangement changes.

## Width classes
- **Narrow** (compact width): any iPhone, iPhone Duo outer display, iPad Slide Over, narrow Split View or Stage Manager windows.
- **Wide** (regular width): iPad full screen in either orientation, wide Split View or Stage Manager windows, iPhone Duo inner display.

The class comes from the app window's width at that moment, never the device model.

## Narrow layout (unchanged)
Search screen → tap a place → forecast pushed with Back → tap a day → detail sheet.

## Wide layout
| Area | Shows |
|---|---|
| Left column (sidebar) | Title "Activity Forecast", search field, and the search states from 001 (idle hint, loading, results, "No places found…", error + Retry). The selected place is highlighted |
| Right column (detail), nothing selected | "Pick a place" placeholder with a short hint to search on the left |
| Right column, place selected | The forecast screen from 001/002 (title = place name, ranked activity sections, loading/error + Retry) |

Selecting another place replaces the right column in place. There is no Back button between columns.

## Day detail
A sheet over the forecast on every width (FR-012). On wide windows it appears as a centred card. Done closes it and returns to the same forecast.

## Size changes
Going narrow ↔ wide keeps the query, results, selected place, loaded forecast and open sheet, with no refetch:
- narrow with a forecast pushed → wide shows the same place selected;
- wide with a selection → narrow shows that forecast pushed, and Back returns to the same results.

## Input and accessibility
- iPad hardware keyboard: the search field can be focused, results selected with arrow keys and Return, the sheet dismissed with Escape.
- Pointer: hover highlight on results and day cells.
- Dynamic Type at every size, with no truncation or overlap. At the largest accessibility sizes the system may collapse the sidebar behind its toggle rather than squeeze both columns.
