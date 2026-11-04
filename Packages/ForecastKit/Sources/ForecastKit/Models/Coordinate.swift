/// A point on Earth in degrees: latitude −90…90, longitude −180…180 (specs/005 data-model.md).
public struct Coordinate: Sendable, Hashable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
