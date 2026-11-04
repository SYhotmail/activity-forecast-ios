import Testing
@testable import ForecastKit

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
        }))
        #expect(model.selectedPlace == nil)
        #expect(model.forecast == nil)

        model.search.query = "Paris"
        await model.search.search()
        #expect(await calls.values == ["Paris"])
    }

    @Test("Selecting a place creates its forecast in the loading state")
    func selectCreatesForecast() {
        let model = BrowseModel(service: StubWeatherService())
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
        }))
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
        let model = BrowseModel(service: StubWeatherService())
        model.select(Self.paris)
        let first = try #require(model.forecast)
        model.select(Self.texas)
        #expect(model.forecast !== first)
        #expect(model.forecast?.place == Self.texas)
    }

    @Test("Clearing the selection drops the forecast")
    func selectNilClears() {
        let model = BrowseModel(service: StubWeatherService())
        model.select(Self.paris)
        model.select(nil)
        #expect(model.selectedPlace == nil)
        #expect(model.forecast == nil)
    }

    @Test("The forecast always belongs to the selected place")
    func invariantHolds() {
        let model = BrowseModel(service: StubWeatherService())
        for place in [Self.paris, Self.texas, nil, Self.paris] {
            model.select(place)
            #expect(model.forecast?.place == model.selectedPlace)
        }
    }

    @Test("The search model is the same instance for the model's lifetime")
    func searchIsStable() {
        let model = BrowseModel(service: StubWeatherService())
        let search = model.search
        model.select(Self.paris)
        model.select(nil)
        #expect(model.search === search)
    }
}
