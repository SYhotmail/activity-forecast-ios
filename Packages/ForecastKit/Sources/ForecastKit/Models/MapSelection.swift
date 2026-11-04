import Foundation

/// Turns a point tapped on the map into the `Place` whose forecast is shown
/// (specs/005 FR-003, FR-006, research R3).
public enum MapSelection {
    /// A locality further than this from the tap does not name it (spec Clarification Q1), in metres.
    public static let namingRadius: Double = 25_000

    /// The place for a tap at `tap`, given the nearest locality the geocoder found (if any).
    ///
    /// The forecast is always for the tapped point itself, so latitude and longitude are the tap's
    /// (FR-006). The name, region, country and time zone come from `nearest` only when it lies within
    /// `namingRadius`; otherwise the place is named by its coordinates. The time zone is display only:
    /// forecast days already arrive in the point's local time.
    public static func place(at tap: Coordinate, nearest: Place?) -> Place {
        let id = identifier(for: tap)
        if let nearest, distance(from: tap, to: nearest.coordinate) <= namingRadius {
            return Place(id: id, name: nearest.name, region: nearest.region, country: nearest.country,
                         latitude: tap.latitude, longitude: tap.longitude, timeZone: nearest.timeZone)
        }
        return Place(id: id, name: coordinateLabel(tap), region: nil, country: nil,
                     latitude: tap.latitude, longitude: tap.longitude, timeZone: "GMT")
    }

    /// "48.86° N, 2.35° E": two decimals with hemisphere letters. Values that round to zero read
    /// N/E, and longitudes outside ±180 are wrapped first.
    public static func coordinateLabel(_ coordinate: Coordinate) -> String {
        let latitude = component(coordinate.latitude, positive: "N", negative: "S")
        let longitude = component(normalised(longitude: coordinate.longitude), positive: "E", negative: "W")
        return "\(latitude), \(longitude)"
    }

    // MARK: - Private

    private static let earthRadius: Double = 6_371_000

    private static func component(_ value: Double, positive: String, negative: String) -> String {
        let digits = String(format: "%.2f", abs(value))
        let hemisphere = value < 0 && digits != "0.00" ? negative : positive
        return "\(digits)° \(hemisphere)"
    }

    private static func normalised(longitude: Double) -> Double {
        let wrapped = (longitude + 180).truncatingRemainder(dividingBy: 360)
        return (wrapped < 0 ? wrapped + 360 : wrapped) - 180
    }

    /// Negative, so it never clashes with Open-Meteo (GeoNames) ids, which are positive. Taps that
    /// round to the same 4 decimals (about 11 m) get the same id.
    private static func identifier(for coordinate: Coordinate) -> Int {
        let latitudeIndex = Int(((coordinate.latitude + 90) * 10_000).rounded())
        let longitudeIndex = Int(((normalised(longitude: coordinate.longitude) + 180) * 10_000).rounded())
        return -(latitudeIndex * 3_600_001 + longitudeIndex + 1)
    }

    /// Great-circle (haversine) distance in metres.
    private static func distance(from a: Coordinate, to b: Coordinate) -> Double {
        let radians = Double.pi / 180
        let deltaLatitude = (b.latitude - a.latitude) * radians
        let deltaLongitude = (b.longitude - a.longitude) * radians
        let h = sin(deltaLatitude / 2) * sin(deltaLatitude / 2)
            + cos(a.latitude * radians) * cos(b.latitude * radians)
            * sin(deltaLongitude / 2) * sin(deltaLongitude / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }
}
