import Testing
@testable import ForecastKit

@MainActor
@Suite("SearchModel: query → idle / loading / loaded (FR-001, FR-002)")
struct SearchModelTests {
    nonisolated static let parisFrance = Place(id: 2988507, name: "Paris", region: "Île-de-France Region",
                                   country: "France", latitude: 48.85, longitude: 2.35,
                                   timeZone: "Europe/Paris")
    nonisolated static let parisTexas = Place(id: 4717560, name: "Paris", region: "Texas",
                                  country: "United States", latitude: 33.66, longitude: -95.56,
                                  timeZone: "America/Chicago")

    @Test("Starts idle with an empty query")
    func startsIdle() {
        let model = SearchModel(service: StubWeatherService())
        #expect(model.query.isEmpty)
        #expect(model.state == .idle)
    }

    @Test("A query shorter than 2 characters (after trimming) is idle and never hits the service",
          arguments: ["", "P", "  P  ", "   "])
    func shortQueryIsIdle(query: String) async {
        let service = StubWeatherService(search: { _ in
            Issue.record("service must not be called for a short query")
            return []
        })
        let model = SearchModel(service: service)
        model.query = query
        await model.search()
        #expect(model.state == .idle)
    }

    @Test("Moves through loading, then loaded with the places from the service")
    func loadingThenLoaded() async {
        let started = Gate()
        let release = Gate()
        let service = StubWeatherService(search: { _ in
            started.open()
            await release.wait()
            return [Self.parisFrance, Self.parisTexas]
        })
        let model = SearchModel(service: service)
        model.query = "Paris"

        let search = Task { await model.search() }
        await started.wait()
        #expect(model.state == .loading)

        release.open()
        await search.value
        #expect(model.state == .loaded([Self.parisFrance, Self.parisTexas]))
    }

    @Test("Sends the trimmed query to the service")
    func trimsQuery() async {
        let received = Recorder<String>()
        let model = SearchModel(service: StubWeatherService(search: { query in
            await received.append(query)
            return [Self.parisFrance]
        }))
        model.query = "  Paris \n"
        await model.search()
        #expect(await received.values == ["Paris"])
    }

    @Test("No matches is the empty state, not an empty list")
    func noMatchesIsEmpty() async {
        let model = SearchModel(service: StubWeatherService(search: { _ in [] }))
        model.query = "zzqxw"
        await model.search()
        #expect(model.state == .empty)
    }

    @Test("Loaded results carry displayName so same-named places can be told apart (FR-002)")
    func resultsCarryDisplayName() async {
        let model = SearchModel(service: StubWeatherService(search: { _ in
            [Self.parisFrance, Self.parisTexas]
        }))
        model.query = "Paris"
        await model.search()
        guard case let .loaded(places) = model.state else {
            Issue.record("expected loaded, got \(model.state)")
            return
        }
        #expect(places.map(\.displayName) == [
            "Paris, Île-de-France Region, France",
            "Paris, Texas, United States"
        ])
    }

    @Test("Shortening the query back below 2 characters returns to idle")
    func backToIdle() async {
        let model = SearchModel(service: StubWeatherService(search: { _ in [Self.parisFrance] }))
        model.query = "Paris"
        await model.search()
        model.query = "P"
        await model.search()
        #expect(model.state == .idle)
    }
}
