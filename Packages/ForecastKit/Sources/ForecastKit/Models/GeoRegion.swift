/// A rectangular area of the map, so the data layer can describe one without MapKit types.
public struct GeoRegion: Sendable, Hashable {
    public let center: Coordinate
    public let latitudeDelta: Double
    public let longitudeDelta: Double

    public init(center: Coordinate, latitudeDelta: Double, longitudeDelta: Double) {
        self.center = center
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }
}
