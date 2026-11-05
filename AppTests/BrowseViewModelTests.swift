import Testing
import ForecastKit
@testable import ActivityForecast

/// Selection and forecast ownership for the adaptive layout (specs/003 data-model.md › BrowseModel).
@MainActor
@Suite("BrowseViewModel: selection and forecast ownership (FR-006, FR-007)")
struct BrowseViewModelTests {
    nonisolated static let paris = SearchViewModelTests.parisFrance
    nonisolated static let texas = SearchViewModelTests.parisTexas

    @Test("Starts with nothing selected and a search model using the same service")
    func startsEmpty() async {
        let calls = Recorder<String>()
        let model = BrowseViewModel(service: StubWeatherService(search: { query, _ in
            await calls.append(query)
            return [Self.paris]
        }), logger: .disabled)
        #expect(model.selectedPlace == nil)
        #expect(model.forecast == nil)

        model.search.query = "Paris"
        await model.search.search()
        #expect(await calls.values == ["Paris"])
    }

    @Test("Selecting a place creates its forecast in the loading state")
    func selectCreatesForecast() {
        let model = BrowseViewModel(service: StubWeatherService(), logger: .disabled)
        model.select(Self.paris)
        #expect(model.selectedPlace == Self.paris)
        #expect(model.forecast?.place == Self.paris)
        #expect(model.forecast?.state == .loading)
    }

    @Test("Selecting the same place again keeps the forecast and never fetches twice")
    func reselectKeepsForecast() async throws {
        let fetches = Recorder<Place>()
        let model = BrowseViewModel(service: StubWeatherService(forecast: { place in
            await fetches.append(place)
            return ForecastViewModelTests.alpineWeek
        }), logger: .disabled)
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
        let model = BrowseViewModel(service: StubWeatherService(), logger: .disabled)
        model.select(Self.paris)
        let first = try #require(model.forecast)
        model.select(Self.texas)
        #expect(model.forecast !== first)
        #expect(model.forecast?.place == Self.texas)
    }

    @Test("Clearing the selection drops the forecast")
    func selectNilClears() {
        let model = BrowseViewModel(service: StubWeatherService(), logger: .disabled)
        model.select(Self.paris)
        model.select(nil)
        #expect(model.selectedPlace == nil)
        #expect(model.forecast == nil)
    }

    @Test("The forecast always belongs to the selected place")
    func invariantHolds() {
        let model = BrowseViewModel(service: StubWeatherService(), logger: .disabled)
        for place in [Self.paris, Self.texas, nil, Self.paris] {
            model.select(place)
            #expect(model.forecast?.place == model.selectedPlace)
        }
    }

    @Test("The search model is the same instance for the model's lifetime")
    func searchIsStable() {
        let model = BrowseViewModel(service: StubWeatherService(), logger: .disabled)
        let search = model.search
        model.select(Self.paris)
        model.select(nil)
        #expect(model.search === search)
    }

    // MARK: - Bindable selection for the search list (specs/005 FR-004)

    @Test("Setting the selection selects the place and starts its forecast")
    func selectionSelects() {
        let model = BrowseViewModel(service: StubWeatherService(), logger: .disabled)
        model.selection = Self.paris
        #expect(model.selectedPlace == Self.paris)
        #expect(model.selection == Self.paris)
        #expect(model.forecast?.place == Self.paris)
        #expect(model.forecast?.state == .loading)
    }

    @Test("Setting the selection to the current place keeps its loaded forecast and never refetches")
    func selectionReselectKeepsForecast() async throws {
        let fetches = Recorder<Place>()
        let model = BrowseViewModel(service: StubWeatherService(forecast: { place in
            await fetches.append(place)
            return ForecastViewModelTests.alpineWeek
        }), logger: .disabled)
        model.selection = Self.paris
        let first = try #require(model.forecast)
        await first.load()

        model.selection = Self.paris
        #expect(model.forecast === first)
        #expect(model.forecast?.state != .loading)
        #expect(await fetches.values == [Self.paris])
    }

    @Test("Clearing the selection clears the place and its forecast")
    func selectionNilClears() {
        let model = BrowseViewModel(service: StubWeatherService(), logger: .disabled)
        model.selection = Self.paris
        model.selection = nil
        #expect(model.selectedPlace == nil)
        #expect(model.forecast == nil)
    }

    @Test("Selecting another place cancels the previous forecast's request (specs/005 FR-012)")
    func selectOtherCancelsPreviousLoad() async throws {
        let started = Gate()
        let release = Gate()
        let model = BrowseViewModel(service: StubWeatherService(forecast: { _ in
            started.open()
            await release.wait()
            return ForecastViewModelTests.alpineWeek
        }), logger: .disabled)
        model.select(Self.paris)
        let previous = try #require(model.forecast)
        let load = Task { await previous.loadIfNeeded() }
        await started.wait()

        model.select(Self.texas)
        release.open()
        await load.value
        #expect(previous.state == .loading)
    }
}
