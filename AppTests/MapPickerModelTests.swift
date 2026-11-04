import MapKit
import SwiftUI
import Testing
import ForecastKit
@testable import ActivityForecast

/// Map taps, naming and the first map view (specs/005 data-model.md › MapPickerModel).
@MainActor
@Suite("MapPickerModel: tap, name, last tap wins (specs/005 FR-002…FR-007, FR-011)")
struct MapPickerModelTests {
    nonisolated static let alps = Coordinate(latitude: 45.95, longitude: 6.87)
    nonisolated static let atlantic = Coordinate(latitude: 40, longitude: -35)
    nonisolated static let france = GeoRegion(center: Coordinate(latitude: 46.6, longitude: 2.4),
                                              latitudeDelta: 9, longitudeDelta: 11)

    /// A locality about 3 km north of `coordinate`.
    nonisolated static func locality(near coordinate: Coordinate) -> Place {
        Place(id: 0, name: "Chamonix-Mont-Blanc", region: "Auvergne-Rhône-Alpes", country: "France",
              latitude: coordinate.latitude + 0.027, longitude: coordinate.longitude, timeZone: "Europe/Paris")
    }

    nonisolated static let namingLocator = StubPlaceLocator(nearest: { locality(near: $0) })

    static func isWorld(_ camera: MapCameraPosition) -> Bool {
        guard let region = camera.region else { return false }
        let world = MapPickerModel.worldRegion
        return region.center.latitude == world.center.latitude
            && region.center.longitude == world.center.longitude
            && region.span.latitudeDelta == world.span.latitudeDelta
            && region.span.longitudeDelta == world.span.longitudeDelta
    }

    // MARK: - Tap and name

    @Test("Starts with no pin and the whole world in view")
    func initialState() {
        let model = MapPickerModel(locator: StubPlaceLocator(), regionCode: nil)
        #expect(model.pin == nil)
        #expect(Self.isWorld(model.camera))
    }

    @Test("A tap shows a locating pin at once, before any lookup (FR-004)")
    func tapShowsLocatingPin() {
        let model = MapPickerModel(locator: Self.namingLocator, regionCode: nil)
        model.tap(at: Self.alps)
        #expect(model.pin == MapPin(coordinate: Self.alps, place: nil))
        #expect(model.pin?.isLocating == true)
    }

    @Test("locatePin names the pin after the nearby locality, at the tapped point (FR-003, FR-006)")
    func locateNamesPin() async {
        let model = MapPickerModel(locator: Self.namingLocator, regionCode: nil)
        model.tap(at: Self.alps)
        let place = await model.locatePin()
        let expected = MapSelection.place(at: Self.alps, nearest: Self.locality(near: Self.alps))
        #expect(place == expected)
        #expect(model.pin == MapPin(coordinate: Self.alps, place: expected))
        #expect(model.pin?.isLocating == false)
    }

    @Test("No locality names the pin by its coordinates")
    func noLocalityUsesCoordinates() async {
        let model = MapPickerModel(locator: StubPlaceLocator(), regionCode: nil)
        model.tap(at: Self.atlantic)
        let place = await model.locatePin()
        #expect(place?.name == "40.00° N, 35.00° W")
        #expect(model.pin?.place == place)
    }

    @Test("The locator receives exactly the tapped coordinate")
    func locatorGetsTap() async {
        let calls = Recorder<Coordinate>()
        let model = MapPickerModel(locator: StubPlaceLocator(nearest: { coordinate in
            await calls.append(coordinate)
            return nil
        }), regionCode: nil)
        model.tap(at: Self.alps)
        _ = await model.locatePin()
        #expect(await calls.values == [Self.alps])
    }

    @Test("Last tap wins: a lookup for an earlier tap never names a newer pin (FR-007)")
    func lastTapWins() async {
        let started = Gate()
        let release = Gate()
        let model = MapPickerModel(locator: StubPlaceLocator(nearest: { coordinate in
            if coordinate == Self.alps {
                started.open()
                await release.wait()
            }
            return Self.locality(near: coordinate)
        }), regionCode: nil)

        model.tap(at: Self.alps)
        let first = Task { await model.locatePin() }
        await started.wait()
        model.tap(at: Self.atlantic)
        release.open()
        #expect(await first.value == nil)
        #expect(model.pin == MapPin(coordinate: Self.atlantic, place: nil))

        let second = await model.locatePin()
        #expect(second?.latitude == Self.atlantic.latitude)
        #expect(model.pin?.place == second)
    }

    @Test("A cancelled lookup leaves the pin locating and shows no error")
    func cancelledLookup() async {
        let started = Gate()
        let model = MapPickerModel(locator: StubPlaceLocator(nearest: { _ in
            started.open()
            try await Task.sleep(for: .seconds(3600))
            return nil
        }), regionCode: nil)
        model.tap(at: Self.alps)
        let task = Task { await model.locatePin() }
        await started.wait()
        task.cancel()
        #expect(await task.value == nil)
        #expect(model.pin == MapPin(coordinate: Self.alps, place: nil))
    }

    @Test("locatePin on a named pin returns it without another lookup (FR-009)")
    func locateIsIdempotent() async {
        let calls = Recorder<Coordinate>()
        let model = MapPickerModel(locator: StubPlaceLocator(nearest: { coordinate in
            await calls.append(coordinate)
            return Self.locality(near: coordinate)
        }), regionCode: nil)
        model.tap(at: Self.alps)
        let first = await model.locatePin()
        let again = await model.locatePin()
        #expect(again == first)
        #expect(await calls.values.count == 1)
    }

    @Test("locatePin without a pin does nothing")
    func locateWithoutPin() async {
        let model = MapPickerModel(locator: Self.namingLocator, regionCode: nil)
        #expect(await model.locatePin() == nil)
        #expect(model.pin == nil)
    }

    // MARK: - First map view (FR-011)

    @Test("An ISO country region moves the first view to that country")
    func initialRegionForCountry() async {
        let codes = Recorder<String>()
        let model = MapPickerModel(locator: StubPlaceLocator(region: { code in
            await codes.append(code)
            return Self.france
        }), regionCode: "FR")
        await model.loadInitialRegionIfNeeded()
        #expect(await codes.values == ["FR"])
        #expect(model.camera.region?.center.latitude == 46.6)
        #expect(model.camera.region?.span.longitudeDelta == 11)
    }

    @Test("A region that is not a country keeps the whole world, without a lookup",
          arguments: ["001", "150", nil] as [String?])
    func nonCountryKeepsWorld(code: String?) async {
        let model = MapPickerModel(locator: StubPlaceLocator(region: { _ in
            Issue.record("no lookup for a non-country region")
            return Self.france
        }), regionCode: code)
        await model.loadInitialRegionIfNeeded()
        #expect(Self.isWorld(model.camera))
    }

    @Test("A failed region lookup keeps the whole world")
    func failedRegionKeepsWorld() async {
        let model = MapPickerModel(locator: StubPlaceLocator(region: { _ in throw UserFacingError.offline }),
                                   regionCode: "FR")
        await model.loadInitialRegionIfNeeded()
        #expect(Self.isWorld(model.camera))
    }

    @Test("The country never overrides a tap or a camera the user already moved")
    func regionDoesNotOverrideUser() async {
        let tapped = MapPickerModel(locator: StubPlaceLocator(region: { _ in Self.france }), regionCode: "FR")
        tapped.tap(at: Self.alps)
        await tapped.loadInitialRegionIfNeeded()
        #expect(Self.isWorld(tapped.camera))

        let moved = MapPickerModel(locator: StubPlaceLocator(region: { _ in Self.france }), regionCode: "FR")
        let elsewhere = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 10, longitude: 10),
                                           span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1))
        moved.camera = .region(elsewhere)
        await moved.loadInitialRegionIfNeeded()
        #expect(moved.camera.region?.center.latitude == 10)
    }

    @Test("The country is looked up once per session")
    func regionLookedUpOnce() async {
        let codes = Recorder<String>()
        let model = MapPickerModel(locator: StubPlaceLocator(region: { code in
            await codes.append(code)
            return nil
        }), regionCode: "GB")
        await model.loadInitialRegionIfNeeded()
        await model.loadInitialRegionIfNeeded()
        #expect(await codes.values == ["GB"])
    }

    // MARK: - Search selection on the map (US2, FR-008)

    nonisolated static let paris = SearchModelTests.parisFrance

    @Test("show(place) marks a named pin and centres the camera on it at city zoom")
    func showCentresOnPlace() throws {
        let model = MapPickerModel(locator: StubPlaceLocator(), regionCode: nil)
        model.show(Self.paris)
        #expect(model.pin == MapPin(coordinate: Self.paris.coordinate, place: Self.paris))
        let region = try #require(model.camera.region)
        #expect(abs(region.center.latitude - Self.paris.latitude) < 0.0001)
        #expect(abs(region.center.longitude - Self.paris.longitude) < 0.0001)
        #expect(region.span.latitudeDelta <= 0.5)
        #expect(region.span.longitudeDelta <= 0.5)
    }

    @Test("The device-region country never overrides a place picked from search")
    func regionDoesNotOverrideShownPlace() async {
        let model = MapPickerModel(locator: StubPlaceLocator(region: { _ in Self.france }), regionCode: "FR")
        model.show(Self.paris)
        await model.loadInitialRegionIfNeeded()
        #expect(model.camera.region?.center.latitude == Self.paris.latitude)
    }
}
