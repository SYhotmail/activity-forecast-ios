import Testing
import ForecastKit
@testable import ActivityForecast

@MainActor
@Suite("SearchViewModel: query → idle / loading / loaded (FR-001, FR-002)")
struct SearchViewModelTests {
    nonisolated static let parisFrance = Place(id: 2988507, name: "Paris", region: "Île-de-France Region",
                                   country: "France", latitude: 48.85, longitude: 2.35,
                                   timeZone: "Europe/Paris")
    nonisolated static let parisTexas = Place(id: 4717560, name: "Paris", region: "Texas",
                                  country: "United States", latitude: 33.66, longitude: -95.56,
                                  timeZone: "America/Chicago")

    @Test("Starts idle with an empty query")
    func startsIdle() {
        let model = SearchViewModel(service: StubWeatherService())
        #expect(model.query.isEmpty)
        #expect(model.state == .idle)
    }

    @Test("A query shorter than 2 characters (after trimming) is idle and never hits the service",
          arguments: ["", "P", "  P  ", "   "])
    func shortQueryIsIdle(query: String) async {
        let service = StubWeatherService(search: { _, _ in
            Issue.record("service must not be called for a short query")
            return []
        })
        let model = SearchViewModel(service: service)
        model.query = query
        await model.search()
        #expect(model.state == .idle)
    }

    @Test("Moves through loading, then loaded with the places from the service")
    func loadingThenLoaded() async {
        let started = Gate()
        let release = Gate()
        let service = StubWeatherService(search: { _, _ in
            started.open()
            await release.wait()
            return [Self.parisFrance, Self.parisTexas]
        })
        let model = SearchViewModel(service: service)
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
        let model = SearchViewModel(service: StubWeatherService(search: { query, _ in
            await received.append(query)
            return [Self.parisFrance]
        }))
        model.query = "  Paris \n"
        await model.search()
        #expect(await received.values == ["Paris"])
    }

    @Test("Sends the language detected for the query with it (specs/007 FR-006)", arguments: [
        ("Мінск", ["en", "be"], "be"),
        ("Paris", ["de", "en"], nil)
    ] as [(String, [String], String?)])
    func sendsQueryLanguage(query: String, candidates: [String], expected: String?) async {
        let received = Recorder<String?>()
        let model = SearchViewModel(
            service: StubWeatherService(search: { _, language in
                await received.append(language)
                return [Self.parisFrance]
            }),
            language: .fixed(candidates))
        model.query = query
        await model.search()
        #expect(await received.values == [expected])
    }

    @Test("No matches is the empty state, not an empty list")
    func noMatchesIsEmpty() async {
        let model = SearchViewModel(service: StubWeatherService(search: { _, _ in [] }))
        model.query = "zzqxw"
        await model.search()
        #expect(model.state == .empty)
    }

    @Test("Loaded results carry displayName so same-named places can be told apart (FR-002)")
    func resultsCarryDisplayName() async {
        let model = SearchViewModel(service: StubWeatherService(search: { _, _ in
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
        let model = SearchViewModel(service: StubWeatherService(search: { _, _ in [Self.parisFrance] }))
        model.query = "Paris"
        await model.search()
        model.query = "P"
        await model.search()
        #expect(model.state == .idle)
    }
}

// MARK: - Failures, retry and stale results (FR-011, FR-012)

extension SearchViewModelTests {
    @Test("A UserFacingError from the service is shown as that error",
          arguments: [UserFacingError.offline, .serviceUnavailable, .unexpected,
                      .rateLimited(until: Date(timeIntervalSince1970: 0))])
    func userFacingError(error: UserFacingError) async {
        let model = SearchViewModel(service: StubWeatherService(search: { _, _ in throw error }))
        model.query = "Paris"
        await model.search()
        #expect(model.state == .failed(error))
    }

    @Test("Any other error is shown as unexpected")
    func otherError() async {
        struct Boom: Error {}
        let model = SearchViewModel(service: StubWeatherService(search: { _, _ in throw Boom() }))
        model.query = "Paris"
        await model.search()
        #expect(model.state == .failed(.unexpected))
    }

    @Test("retry() after a failure searches again and recovers")
    func retryRecovers() async {
        let attempts = Recorder<String>()
        let model = SearchViewModel(service: StubWeatherService(search: { query, _ in
            await attempts.append(query)
            if await attempts.values.count == 1 { throw UserFacingError.offline }
            return [Self.parisFrance]
        }))
        model.query = "Paris"
        await model.search()
        #expect(model.state == .failed(.offline))

        await model.retry()
        #expect(model.state == .loaded([Self.parisFrance]))
        #expect(await attempts.values == ["Paris", "Paris"])
    }

    @Test("A CancellationError from the service never changes the state")
    func cancellationErrorIgnored() async {
        let model = SearchViewModel(service: StubWeatherService(search: { _, _ in throw CancellationError() }))
        model.query = "Paris"
        await model.search()
        #expect(model.state == .loading)
    }

    @Test("A cancelled search drops its result even when the service still answers")
    func cancelledResultDropped() async {
        let started = Gate()
        let release = Gate()
        let model = SearchViewModel(service: StubWeatherService(search: { _, _ in
            started.open()
            await release.wait()
            return [Self.parisFrance]
        }))
        model.query = "Paris"
        let search = Task { await model.search() }
        await started.wait()
        search.cancel()
        release.open()
        await search.value
        #expect(model.state == .loading)
    }

    @Test("A stale result for an older query never replaces the newer query's results (FR-012)")
    func staleResultNeverApplied() async {
        let london = Place(id: 2643743, name: "London", region: "England", country: "United Kingdom",
                           latitude: 51.5, longitude: -0.13, timeZone: "Europe/London")
        let londonderry = Place(id: 2643736, name: "Londonderry", region: "Northern Ireland",
                                country: "United Kingdom", latitude: 55, longitude: -7.3,
                                timeZone: "Europe/London")
        let lonStarted = Gate()
        let releaseLon = Gate()
        let model = SearchViewModel(service: StubWeatherService(search: { query, _ in
            if query == "Lon" {
                lonStarted.open()
                await releaseLon.wait()   // the older request answers last
                return [londonderry, london]
            }
            return [london]
        }))

        model.query = "Lon"
        let older = Task { await model.search() }
        await lonStarted.wait()

        model.query = "London"
        await model.search()
        #expect(model.state == .loaded([london]))

        releaseLon.open()
        await older.value
        #expect(model.state == .loaded([london]))
    }
}

// MARK: - No repeat request for an unchanged query (specs/003 FR-007, data-model.md › SearchModel)

/// The sidebar's `.task(id: query)` runs again whenever a fold or resize rebuilds it, so asking
/// for the results already shown must not reach the service.
extension SearchViewModelTests {
    private static func countingService(_ calls: Recorder<String>, returning places: [Place])
        -> StubWeatherService {
        StubWeatherService(search: { query, _ in
            await calls.append(query)
            return places
        })
    }

    @Test("Searching the same query again keeps the results and makes no request")
    func sameQueryIsNotRequestedAgain() async {
        let calls = Recorder<String>()
        let model = SearchViewModel(service: Self.countingService(calls, returning: [Self.parisFrance]))
        model.query = "Paris"
        await model.search()
        await model.search()
        #expect(await calls.values == ["Paris"])
        #expect(model.state == .loaded([Self.parisFrance]))
    }

    @Test("An empty result for the same query is not requested again either")
    func sameEmptyQueryIsNotRequestedAgain() async {
        let calls = Recorder<String>()
        let model = SearchViewModel(service: Self.countingService(calls, returning: []))
        model.query = "zzqxw"
        await model.search()
        await model.search()
        #expect(await calls.values == ["zzqxw"])
        #expect(model.state == .empty)
    }

    @Test("A changed query searches again; whitespace alone is not a change")
    func changedQuerySearchesAgain() async {
        let calls = Recorder<String>()
        let model = SearchViewModel(service: Self.countingService(calls, returning: [Self.parisFrance]))
        model.query = "Paris"
        await model.search()
        model.query = " Paris "
        await model.search()
        model.query = "London"
        await model.search()
        #expect(await calls.values == ["Paris", "London"])
    }

    @Test("retry() always searches, even when results are loaded")
    func retryAlwaysSearches() async {
        let calls = Recorder<String>()
        let model = SearchViewModel(service: Self.countingService(calls, returning: [Self.parisFrance]))
        model.query = "Paris"
        await model.search()
        await model.retry()
        #expect(await calls.values == ["Paris", "Paris"])
    }
}
