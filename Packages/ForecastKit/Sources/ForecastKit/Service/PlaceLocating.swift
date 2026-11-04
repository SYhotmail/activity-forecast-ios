/// Data-layer boundary for map lookups (specs/005 contracts/place-locating.md).
///
/// Implementations throw `UserFacingError.offline` or `.serviceUnavailable` for failures, and
/// `CancellationError` when cancelled. "Nothing found" is `nil`, never an error.
public protocol PlaceLocating: Sendable {
    /// The locality containing or nearest to `coordinate`, as a `Place` at the locality's own location
    /// (name, region, country, time zone), or `nil` when there is none (open sea). The 25 km naming rule
    /// is applied by `MapSelection`, not here.
    func nearestLocality(to coordinate: Coordinate) async throws -> Place?

    /// Bounding region of the country with ISO 3166-1 alpha-2 `code`, or `nil` if unknown.
    func region(ofCountry code: String) async throws -> GeoRegion?
}
