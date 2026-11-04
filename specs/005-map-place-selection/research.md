# Research: Select a Place on a Map

Decisions for [spec.md](./spec.md). The user asked for MapKit ("MapKit should be used"). Every decision below stays inside Apple's system frameworks: no third-party package and no API key.

## R1. Map view
- **Decision**: SwiftUI MapKit `Map(position:)` inside a `MapReader`. A tap gesture converts the tap point to a coordinate with `MapProxy.convert(_:from: .local)`. The selection is drawn as a `Marker`. No `UserAnnotation` and no location button.
- **Rationale**: built into iOS 17+, so it is available at the iOS 18 deployment target without `#available`. Pan, zoom, Dynamic Type for labels and Light/Dark come for free. Leaving out user location means no permission prompt and no Info.plist usage string (FR-011).
- **Alternatives**: `MKMapView` wrapped in `UIViewRepresentable` (more code, and a coordinator would be needed for taps). `Map(selection:)` on map features (would select only Apple's points of interest, not any point; spec Clarification Q1).

## R2. Naming a tapped point (reverse geocoding)
- **Decision**: a new data-layer type in ForecastKit, `MapKitPlaceLocator`, behind a small `PlaceLocating` protocol ([contracts/place-locating.md](./contracts/place-locating.md)):
  - iOS 26+ / macOS 26+: `MKReverseGeocodingRequest(location:)` → `mapItems()`. The name, region and country come from the first item's address representation.
  - iOS 18–25: `CLGeocoder.reverseGeocodeLocation` (CoreLocation, which MapKit re-exports). The name comes from `locality`, the region from `administrativeArea` and the country from `country`.
  - The locator returns the nearest locality as a `Place` *at the locality's location*, or `nil` when there is no locality (open sea, Antarctica).
- **Rationale**: Open-Meteo Geocoding only searches by name and has no reverse lookup (verified in feature 001, contracts/open-meteo.md). MapKit's geocoder is keyless and already on the device. Apple deprecated `CLGeocoder` in iOS 26 in favour of the MapKit request, so the new API is used where it exists. The deprecation applies only from iOS 26. At a deployment target of iOS 18 the fallback compiles without a deprecation warning, and the zero-warning build gate (quickstart Q-G4) confirms this.
- **Verify during implementation**: the exact iOS 26 `MKMapItem` address properties that give city, region and country. Map them in one private function and check them on the simulator against the quickstart cities (Chamonix, Biarritz, mid-Atlantic).
- **Alternatives**:
  - `CLGeocoder` only. Rejected: deprecated API, and the user asked for MapKit.
  - Search Open-Meteo by the locality name and pick the nearest result. Rejected: a second request and ambiguous names, for no gain over the MapKit fields.
  - A third-party or keyed geocoder. Rejected by the constitution.

## R3. The 25 km rule and the selected place
- **Decision**: a pure domain function `MapSelection.place(at:nearest:)` in ForecastKit, tested with `swift test`:
  - The locality is used for the name only if it lies within 25 km (great-circle distance) of the tapped point. Otherwise, or when the locality is `nil`, the place gets a coordinate label such as `48.86° N, 2.35° E`, with no region or country.
  - The resulting `Place` always uses the **tapped** latitude and longitude (FR-006). Its time zone is the locality's when known, else `GMT`.
  - Its `id` is negative and derived from the coordinate rounded to 4 decimals (about 11 m). It can never clash with Open-Meteo/GeoNames ids, which are positive.
- **Rationale**: reverse geocoding returns the locality that *contains* a point, so on land the distance check rarely triggers. It guards against matches far out at sea or in remote areas, and it makes the clarified rule testable without the network. `Place.timeZone` is display only: forecast days already arrive in the point's local time because the forecast request uses `timezone=auto`, so the GMT fallback cannot shift a day (FR-006).
- **Alternatives**: put the rule inside the locator (untestable without MapKit). Add a new `MapPlace` type (every forecast and scoring API takes `Place`; a second type would ripple through them for no behaviour).

## R4. Concurrency and "last tap wins"
- **Decision**:
  - `MapPickerModel.tap(at:)` replaces the pin synchronously, so the marker shows at once (FR-004). The new pin is in the *locating* state.
  - The map view runs `.task(id: pin)` → `BrowseModel.locateMapPin(selectingWhenNamed:)`. A newer tap changes the id, so SwiftUI cancels the older task. The result is applied only if the pin is unchanged and the task was not cancelled.
  - A cancelled lookup never shows an error (FR-007). Any other failure falls back to the coordinate label (US3).
  - Like `ForecastModel.loadIfNeeded()`, the lookup is idempotent. A view rebuilt by a fold reruns the task, and the task resumes a pin still *locating* or does nothing for a named one (FR-009).
- **Rationale**: this is the same pattern as the debounced search (feature 001 R5) and `loadIfNeeded` (feature 003 R3), and it meets constitution Principle I with no manual task bookkeeping.

## R5. Wide vs narrow behaviour of a tap
- **Decision**:
  - **Wide** (`horizontalSizeClass == .regular`): when the pin is named, `BrowseModel` selects the place and the detail column updates.
  - **Narrow**: the pin shows a callout with the name and a **Show forecast** button. The button selects the place and pushes the detail by setting the split view's `preferredCompactColumn` to `.detail`. `RootView` owns that binding (iOS 17+ `NavigationSplitView(columnVisibility:preferredCompactColumn:)`) and passes it to the sidebar. Back returns it to `.sidebar`.
- **Rationale**: the map is not a `List`, so the value-link trick of feature 003 R4 does not apply. `preferredCompactColumn` is the documented way to show the detail of a collapsed split view programmatically. The size class comes from the environment, never from the device (Principle III).
- **Verify during implementation**: in compact width, list rows still push as before and a Back from a map-pushed forecast returns to the map. Check both on the iPhone Duo outer display.
- **Alternatives**: a `NavigationLink(value:)` in the callout. Rejected: a split view's sidebar resolves value links only through `List(selection:)`.

## R6. Initial map area
- **Decision**:
  - The composition root passes `Locale.current.region?.identifier`. The region is used only when it is an ISO country, meaning two letters. Others (`001` World, `150` Europe) and `nil` fall back to the whole world.
  - The locator resolves the country's bounding region with `MKLocalSearch` (natural-language query = the country's English name, `resultTypes = .address`) → `response.boundingRegion`. This is available on iOS 18.
  - The map starts on the whole world and moves to the country only if that answer arrives while the map is still on the default view: not positioned by the user and nothing selected. Failure keeps the world view silently.
- **Rationale**: needs no location permission (FR-011, spec Clarification Q3). MapKit has no offline table of country bounds, and a hard-coded table would be 250 entries of data to maintain.
- **Alternatives**: hard-coded country bounds (maintenance). Request location (forbidden by FR-011).

## R7. Map state ownership across rebuilds
- **Decision**: the camera position (`MapCameraPosition`) and the pin live in `MapPickerModel`, an `@Observable` app view model owned by `BrowseModel` (one instance for the app's lifetime). Selecting a place from search results recentres the camera on it with a city-level span (FR-008). A map tap does not recentre, so the map never jumps under the user's finger.
- **Rationale**: the map view is destroyed whenever the user types (the list replaces it) and whenever a fold rebuilds the sidebar. State in the long-lived model survives both (FR-009), as `BrowseModel` already does for search and selection (feature 003 R2).

## R8. Re-tapping the selected marker; pan and zoom
- **Decision**: the tap handler converts the current pin's coordinate to screen space. A tap within 22 pt of the pin (half the 44 pt minimum touch target) is ignored, so the loaded forecast stays (FR-010). Pans and pinches are not tap gestures, so they never select.
- **Rationale**: the simplest rule that matches the system marker size, and it is testable by hand in quickstart Q-5.

## R9. Constitution fit
- **Finding**: the constitution's Platform constraint says "Data: Open-Meteo Geocoding and Forecast APIs only", and Principle V draws dependencies as `App → ForecastKit → Foundation`. MapKit is an Apple system framework, not a third-party dependency, but it is a new data source and a framework beyond Foundation in the package.
- **Decision**: amend the constitution (MINOR, 2.2.0 → 2.3.0) with `/speckit-constitution` as the first task:
  - Apple MapKit/CoreLocation may be used for map display (App) and reverse geocoding (ForecastKit data layer only), keyless and without location permission.
  - Domain types still import only Foundation.
- **Rationale**: the same route feature 004 took. It records the trade-off where reviewers look, rather than as a silent exception.
