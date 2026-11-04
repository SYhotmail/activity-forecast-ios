import Testing
import ForecastKit
@testable import ActivityForecast

/// Selection and forecast ownership for the adaptive layout (specs/003 data-model.md › BrowseModel).
@MainActor
@Suite("BrowseModel: selection and forecast ownership (FR-006, FR-007)")
struct BrowseModelTests {
    nonisolated static let paris = SearchModelTests.parisFrance
    nonisolated static let texas = SearchModelTests.parisTexas

    @Test("Starts with nothing selected and a search model using the same service")
    func startsEmpty() async {
        let calls = Recorder<String>()
        let model = BrowseModel(service: StubWeatherService(search: { query in
            await calls.append(query)
            return [Self.paris]
        }), locator: StubPlaceLocator(), regionCode: nil)
        #expect(model.selectedPlace == nil)
        #expect(model.forecast == nil)

        model.search.query = "Paris"
        await model.search.search()
        #expect(await calls.values == ["Paris"])
    }

    @Test("Selecting a place creates its forecast in the loading state")
    func selectCreatesForecast() {
        let model = BrowseModel(service: StubWeatherService(), locator: StubPlaceLocator(), regionCode: nil)
        model.select(Self.paris)
        #expect(model.selectedPlace == Self.paris)
        #expect(model.forecast?.place == Self.paris)
        #expect(model.forecast?.state == .loading)
    }

    @Test("Selecting the same place again keeps the forecast and never fetches twice")
    func reselectKeepsForecast() async throws {
        let fetches = Recorder<Place>()
        let model = BrowseModel(service: StubWeatherService(forecast: { place in
            await fetches.append(place)
            return ForecastModelTests.alpineWeek
        }), locator: StubPlaceLocator(), regionCode: nil)
        model.select(Self.paris)
        let first = try #require(model.forecast)
        await first.load()

        model.select(Self.paris)
        let second = try #require(model.forecast)
        #expect(first === second)
        #expect(second.state != .loading)
        #expect(await fetches.values == [Self.paris])
    }

    @Test("Selecting a different place replaces the forecast")
    func selectOtherReplaces() throws {
        let model = BrowseModel(service: StubWeatherService(), locator: StubPlaceLocator(), regionCode: nil)
        model.select(Self.paris)
        let first = try #require(model.forecast)
        model.select(Self.texas)
        #expect(model.forecast !== first)
        #expect(model.forecast?.place == Self.texas)
    }

    @Test("Clearing the selection drops the forecast")
    func selectNilClears() {
        let model = BrowseModel(service: StubWeatherService(), locator: StubPlaceLocator(), regionCode: nil)
        model.select(Self.paris)
        model.select(nil)
        #expect(model.selectedPlace == nil)
        #expect(model.forecast == nil)
    }

    @Test("The forecast always belongs to the selected place")
    func invariantHolds() {
        let model = BrowseModel(service: StubWeatherService(), locator: StubPlaceLocator(), regionCode: nil)
        for place in [Self.paris, Self.texas, nil, Self.paris] {
            model.select(place)
            #expect(model.forecast?.place == model.selectedPlace)
        }
    }

    @Test("The search model is the same instance for the model's lifetime")
    func searchIsStable() {
        let model = BrowseModel(service: StubWeatherService(), locator: StubPlaceLocator(), regionCode: nil)
        let search = model.search
        model.select(Self.paris)
        model.select(nil)
        #expect(model.search === search)
    }

    // MARK: - Map selection (specs/005)

    private static func mapBrowse(calls: Recorder<Coordinate>? = nil) -> BrowseModel {
        BrowseModel(service: StubWeatherService(), locator: StubPlaceLocator(nearest: { coordinate in
            await calls?.append(coordinate)
            return MapPickerModelTests.locality(near: coordinate)
        }), regionCode: nil)
    }

    @Test("The map model uses the injected locator")
    func mapUsesLocator() async {
        let calls = Recorder<Coordinate>()
        let model = Self.mapBrowse(calls: calls)
        model.map.tap(at: MapPickerModelTests.alps)
        await model.locateMapPin(selectingWhenNamed: false)
        #expect(await calls.values == [MapPickerModelTests.alps])
    }

    @Test("Wide layout: a named map pin is selected and gets its forecast (FR-005)")
    func wideSelectsNamedPin() async throws {
        let model = Self.mapBrowse()
        model.map.tap(at: MapPickerModelTests.alps)
        await model.locateMapPin(selectingWhenNamed: true)
        let place = try #require(model.map.pin?.place)
        #expect(model.selectedPlace == place)
        #expect(model.forecast?.place == place)
    }

    @Test("Narrow layout: naming selects nothing until Show forecast (FR-005)")
    func narrowWaitsForShowForecast() async throws {
        let model = Self.mapBrowse()
        model.map.tap(at: MapPickerModelTests.alps)
        await model.locateMapPin(selectingWhenNamed: false)
        let place = try #require(model.map.pin?.place)
        #expect(model.selectedPlace == nil)

        model.selectMapPin()
        #expect(model.selectedPlace == place)
        #expect(model.forecast?.place == place)
    }

    @Test("Show forecast does nothing while the pin is locating or absent")
    func showForecastNeedsNamedPin() {
        let model = Self.mapBrowse()
        model.selectMapPin()
        #expect(model.selectedPlace == nil)
        model.map.tap(at: MapPickerModelTests.alps)
        model.selectMapPin()
        #expect(model.selectedPlace == nil)
    }

    @Test("Selecting the map pin's place again keeps its forecast (FR-010)")
    func reselectMapPinKeepsForecast() async throws {
        let model = Self.mapBrowse()
        model.map.tap(at: MapPickerModelTests.alps)
        await model.locateMapPin(selectingWhenNamed: true)
        let forecast = try #require(model.forecast)
        await model.locateMapPin(selectingWhenNamed: true)
        model.selectMapPin()
        #expect(model.forecast === forecast)
    }

    @Test("A map selection never moves the camera (research R7)")
    func mapSelectionKeepsCamera() async {
        let model = Self.mapBrowse()
        model.map.tap(at: MapPickerModelTests.alps)
        await model.locateMapPin(selectingWhenNamed: true)
        #expect(MapPickerModelTests.isWorld(model.map.camera))
    }

    @Test("Picking a place from search marks it on the map and centres the map on it (US2, FR-008)")
    func searchSelectionShowsOnMap() {
        let model = Self.mapBrowse()
        model.select(Self.paris)
        #expect(model.map.pin?.place == Self.paris)
        #expect(model.map.camera.region?.center.latitude == Self.paris.latitude)
    }

    @Test("Clearing the selection leaves the map's pin and camera as they were")
    func clearingSelectionKeepsMap() {
        let model = Self.mapBrowse()
        model.select(Self.paris)
        let pin = model.map.pin
        model.select(nil)
        #expect(model.map.pin == pin)
        #expect(model.map.camera.region?.center.latitude == Self.paris.latitude)
    }

    @Test("Offline naming still selects the point by its coordinates and requests its forecast (US3)")
    func offlineNamingStillSelects() async throws {
        let model = BrowseModel(service: StubWeatherService(),
                                locator: StubPlaceLocator(nearest: { _ in throw UserFacingError.offline }),
                                regionCode: nil)
        model.map.tap(at: MapPickerModelTests.atlantic)
        await model.locateMapPin(selectingWhenNamed: true)
        let place = try #require(model.selectedPlace)
        #expect(place.name == "40.00° N, 35.00° W")
        #expect(model.forecast?.place == place)
        #expect(model.forecast?.state == .loading)
    }
}
