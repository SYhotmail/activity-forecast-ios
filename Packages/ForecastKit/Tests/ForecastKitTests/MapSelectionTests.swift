import Testing
@testable import ForecastKit

/// Naming a point tapped on the map (specs/005 FR-003, FR-006, research R3).
@Suite("MapSelection: naming a tapped point (specs/005 FR-003, FR-006)")
struct MapSelectionTests {
    /// One degree of latitude on the 6371 km sphere used for distances, in metres.
    private static let metresPerDegree = 111_194.93

    private static let chamonix = Place(id: 0, name: "Chamonix-Mont-Blanc", region: "Auvergne-Rhône-Alpes",
                                        country: "France", latitude: 45.92, longitude: 6.87,
                                        timeZone: "Europe/Paris")

    /// A tap `metres` due north of Chamonix.
    private static func tap(northOfChamonix metres: Double) -> Coordinate {
        Coordinate(latitude: chamonix.latitude + metres / metresPerDegree, longitude: chamonix.longitude)
    }

    @Test("A locality nearby names the point, but the forecast is for the tapped point (FR-006)")
    func nearbyLocalityNamesThePoint() {
        let tap = Self.tap(northOfChamonix: 3_000)
        let place = MapSelection.place(at: tap, nearest: Self.chamonix)
        #expect(place.name == "Chamonix-Mont-Blanc")
        #expect(place.region == "Auvergne-Rhône-Alpes")
        #expect(place.country == "France")
        #expect(place.timeZone == "Europe/Paris")
        #expect(place.latitude == tap.latitude)
        #expect(place.longitude == tap.longitude)
    }

    @Test("The naming radius is 25 km (Clarification Q1)")
    func namingRadius() {
        #expect(MapSelection.namingRadius == 25_000)
        let inside = MapSelection.place(at: Self.tap(northOfChamonix: 24_900), nearest: Self.chamonix)
        #expect(inside.name == "Chamonix-Mont-Blanc")

        let outsideTap = Self.tap(northOfChamonix: 25_100)
        let outside = MapSelection.place(at: outsideTap, nearest: Self.chamonix)
        #expect(outside.name == MapSelection.coordinateLabel(outsideTap))
        #expect(outside.region == nil)
        #expect(outside.country == nil)
        #expect(outside.timeZone == "GMT")
    }

    @Test("No locality gives the coordinate label")
    func noLocality() {
        let tap = Coordinate(latitude: 40, longitude: -35)
        let place = MapSelection.place(at: tap, nearest: nil)
        #expect(place.name == "40.00° N, 35.00° W")
        #expect(place.subtitle == nil)
        #expect(place.latitude == 40)
        #expect(place.longitude == -35)
    }

    @Test("Coordinate labels use two decimals and hemisphere letters", arguments: [
        (48.8566, 2.3522, "48.86° N, 2.35° E"),
        (-33.87, -151.21, "33.87° S, 151.21° W"),
        (0, 0, "0.00° N, 0.00° E"),
        (-0.001, -0.001, "0.00° N, 0.00° E"),
        (10, 190, "10.00° N, 170.00° W"),
        (10, -190, "10.00° N, 170.00° E")
    ])
    func coordinateLabel(latitude: Double, longitude: Double, expected: String) {
        #expect(MapSelection.coordinateLabel(Coordinate(latitude: latitude, longitude: longitude)) == expected)
    }

    @Test("Ids are negative, stable within about 11 m, and distinct for different points")
    func ids() {
        let a = MapSelection.place(at: Coordinate(latitude: 45.12341, longitude: 6.12341), nearest: nil)
        let b = MapSelection.place(at: Coordinate(latitude: 45.12344, longitude: 6.12339), nearest: nil)
        let c = MapSelection.place(at: Coordinate(latitude: 45.12441, longitude: 6.12341), nearest: nil)
        let d = MapSelection.place(at: Coordinate(latitude: -89.9999, longitude: -179.9999), nearest: nil)
        #expect(a.id < 0)
        #expect(d.id < 0)
        #expect(a.id == b.id)
        #expect(a.id != c.id)
    }

    @Test("Place exposes its coordinate")
    func placeCoordinate() {
        #expect(Self.chamonix.coordinate == Coordinate(latitude: 45.92, longitude: 6.87))
    }
}

