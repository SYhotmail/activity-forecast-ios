# Contract: `PlaceLocating` (ForecastKit, public)

Data-layer boundary for map lookups. The live implementation is `MapKitPlaceLocator` (research R2, R6). The double for previews and app tests is the app's internal `StubPlaceLocator` (`App/Shared/`, never public, never used by production code; constitution Principle V).

```swift
public protocol PlaceLocating: Sendable {
    /// The locality containing or nearest to `coordinate`, as a Place at the locality's own
    /// location (name, region, country, time zone). `nil` when there is none (open sea).
    func nearestLocality(to coordinate: Coordinate) async throws -> Place?
    /// Bounding region of the country with ISO 3166-1 alpha-2 `code`, or `nil` if unknown.
    func region(ofCountry code: String) async throws -> GeoRegion?
}
```

## Behaviour
| Case | Result |
|---|---|
| Point inside a town (Chamonix centre) | `Place(name: "Chamonix-Mont-Blanc", region: "Auvergne-Rhône-Alpes", country: "France", …)` |
| Point at sea far from land | `nil` |
| No network | throws `UserFacingError.offline` |
| Any other geocoder failure | throws `UserFacingError.serviceUnavailable` |
| Task cancelled | throws `CancellationError`, never a `UserFacingError` |
| Unknown country code | `nil` |

Callers never show these errors for naming. `MapPickerModel` turns any failure into the coordinate label (spec US3). The 25 km rule is not applied here. It belongs to the pure `MapSelection.place(at:nearest:)` (data-model.md).

## Implementation notes
- iOS/macOS 26+: `MKReverseGeocodingRequest`. Earlier: `CLGeocoder` (research R2). Same error mapping on both paths.
- No `CLLocationManager`, no location permission.
- `MKLocalSearch` for `region(ofCountry:)`, with the query set to the country's English name from `Locale(identifier: "en_US").localizedString(forRegionCode:)`.
- Not unit-tested: it is a thin wrapper around Apple services. It is covered by quickstart Q-2…Q-4 on the simulator. The pure parts (25 km rule, labels, ids) are unit-tested.
