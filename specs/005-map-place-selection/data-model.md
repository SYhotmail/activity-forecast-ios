# Data Model: Select a Place on a Map

Extends [specs/003 data-model.md](../003-universal-adaptive-layout/data-model.md). `Place`, `ForecastModel`, `SearchModel` and `LoadState` are unchanged unless listed.

## ForecastKit (domain + data, `swift test`)

### Coordinate *(new, Models/)*
| Field | Type | Rule |
|---|---|---|
| latitude | Double | −90…90 |
| longitude | Double | −180…180 |

`Sendable, Hashable`. Foundation only. `Place` gains a computed `coordinate`.

### MapSelection *(new, Models/, pure)*
- `static let namingRadius = 25 km` (spec Clarification Q1).
- `static func place(at tap: Coordinate, nearest: Place?) -> Place`:
  - `nearest` exists and its location is within `namingRadius` of `tap` (great-circle distance) → name, region, country and time zone come from `nearest`.
  - Otherwise → name = `coordinateLabel(tap)`, region = nil, country = nil, time zone = `"GMT"`.
  - Always: latitude and longitude = `tap` (FR-006). id = a negative value derived from `tap` rounded to 4 decimals.
- `static func coordinateLabel(_:) -> String`: `"48.86° N, 2.35° E"`. Two decimals, hemisphere letters, `0.00° N`/`0.00° E` on the equator and the prime meridian, longitude normalised into −180…180.

### PlaceLocating *(new, Service/, protocol)* and MapKitPlaceLocator *(new, Service/)*
See [contracts/place-locating.md](./contracts/place-locating.md).

### GeoRegion *(new, Models/)*
`center: Coordinate`, `latitudeDelta: Double`, `longitudeDelta: Double`. A Foundation-only bounding region, so the protocol does not expose MapKit types.

## App (view models, `ActivityForecastTests`)

### MapPin *(new, value)*
| Field | Type | Meaning |
|---|---|---|
| coordinate | Coordinate | where the user tapped |
| place | Place? | `nil` while locating; set once named (or given its coordinate label) |

`Hashable`. It is the `.task(id:)` key. `isLocating` ⇔ `place == nil`.

### MapPickerModel *(new, `@Observable`, owned by BrowseModel)*
| Member | Meaning |
|---|---|
| `worldRegion` (static) | `MKCoordinateRegion(.world)`, the default view |
| `camera: MapCameraPosition` | Starts at `.region(worldRegion)`; persists for the session (FR-009) |
| `pin: MapPin?` | Current marker; `nil` before any tap or selection |
| `tap(at:)` | If the tap is not on the current pin (R8, decided by the view), replaces `pin` with a new locating pin. Synchronous (FR-004) |
| `locatePin() async -> Place?` | Names a locating pin via `PlaceLocating`. Applies the result only if the pin is unchanged and the task was not cancelled; any thrown error → coordinate label; cancellation → no change. Idempotent: returns the place at once if already named |
| `show(_ place:)` | Pin = that place (named); camera = centred on it with a city-level span (FR-008) |
| `loadInitialRegionIfNeeded() async` | Once per session. If the region code is an ISO country and the camera is still the untouched default with no pin, sets the camera to the country's region; failures ignored (R6) |

### BrowseModel *(changed)*
- `init(service:locator:regionCode:)`. Creates `map = MapPickerModel(locator:regionCode:)`.
- `select(_ place:)` (search path): unchanged, plus `map.show(place)` for non-nil places.
- `locateMapPin(selectingWhenNamed: Bool) async`: awaits `map.locatePin()`. If a place results and the flag is true (wide layout), selects it *without* recentring the map.
- `selectMapPin()`: the narrow layout's **Show forecast** action. Selects the named pin's place without recentring.
- Invariant (unchanged): `forecast?.place == selectedPlace`. Re-selecting the same place keeps the forecast (FR-010).

### SearchModel *(changed)*
- `var showsResults: Bool`: true when the query trimmed of whitespace is not empty and no place has been picked since it last changed (FR-001). With 1 character the drop-down shows the existing idle hint. `dismissResults()` (called by `BrowseModel.select`) closes it; changing the query or `presentResults()` (search field focused) reopens it.

## State transitions (map pin)

```text
none ──tap──▶ locating(c) ──named / failed──▶ named(place at c)
  ▲              │  ▲                          │
  │              └──tap(c′)──▶ locating(c′) ◀──tap(c′)
  └── (never cleared by pan / zoom / typing)
search selection(p) ──▶ named(p)  (camera recentred)
```
Wide layout: `named` also selects the place, including a pin named while narrow when the window widens (the view's task reruns). Narrow: the user's **Show forecast** selects it and pushes the detail.
