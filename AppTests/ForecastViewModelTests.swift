import Testing
import ForecastKit
@testable import ActivityForecast

@MainActor
@Suite("ForecastViewModel: load → ranked week (FR-003, FR-006)")
struct ForecastViewModelTests {
    nonisolated static let paris = Place(id: 2988507, name: "Paris", region: "Île-de-France Region",
                                         country: "France", latitude: 48.85, longitude: 2.35,
                                         timeZone: "Europe/Paris")

    /// Seven snowy, cold days: a clear Skiing week.
    nonisolated static let alpineWeek: [DailyWeather] = (3...9).map { day in
        DailyWeather(date: LocalDate(year: 2026, month: 11, day: day)!, weatherCode: 73,
                     temperatureMax: .celsius(-5), temperatureMin: .celsius(-10),
                     precipitation: .millimetres(2), rain: .millimetres(0),
                     snowfall: .centimetres(20), snowDepth: .centimetres(80), precipitationProbability: 80,
                     windSpeedMax: .kilometresPerHour(15), windGustsMax: .kilometresPerHour(25),
                     sunshine: .hours(2))
    }

    @Test("Starts loading so the screen never shows a blank idle state")
    func startsLoading() {
        let model = ForecastViewModel(place: Self.paris, service: StubWeatherService())
        #expect(model.place == Self.paris)
        #expect(model.state == .loading)
    }

    @Test("load() publishes the week ranked by WeeklyRanker")
    func loadRanks() async {
        let model = ForecastViewModel(place: Self.paris, service: StubWeatherService(forecast: { _ in
            Self.alpineWeek
        }))
        await model.load()
        #expect(model.state == .loaded(WeeklyRanker.rank(Self.alpineWeek, for: Self.paris)))
        if case let .loaded(ranking) = model.state {
            #expect(ranking.rankings.first?.activity == .skiing)
            #expect(ranking.rankings.allSatisfy { $0.days.count == 7 })
        }
    }

    @Test("Requests the forecast for its own place")
    func requestsOwnPlace() async {
        let requested = Recorder<Place>()
        let model = ForecastViewModel(place: Self.paris, service: StubWeatherService(forecast: { place in
            await requested.append(place)
            return Self.alpineWeek
        }))
        await model.load()
        #expect(await requested.values == [Self.paris])
    }

    @Test("Is loading while the forecast request is in flight")
    func loadingWhileInFlight() async {
        let started = Gate()
        let release = Gate()
        let model = ForecastViewModel(place: Self.paris, service: StubWeatherService(forecast: { _ in
            started.open()
            await release.wait()
            return Self.alpineWeek
        }))
        let load = Task { await model.load() }
        await started.wait()
        #expect(model.state == .loading)
        release.open()
        await load.value
        #expect(model.state == .loaded(WeeklyRanker.rank(Self.alpineWeek, for: Self.paris)))
    }
}

// MARK: - Failures and retry (FR-011)

extension ForecastViewModelTests {
    @Test("A UserFacingError from the service is shown as that error",
          arguments: [UserFacingError.offline, .serviceUnavailable, .unexpected, .rateLimited])
    func userFacingError(error: UserFacingError) async {
        let model = ForecastViewModel(place: Self.paris, service: StubWeatherService(forecast: { _ in throw error }))
        await model.load()
        #expect(model.state == .failed(error))
    }

    @Test("Any other error is shown as unexpected")
    func otherError() async {
        struct Boom: Error {}
        let model = ForecastViewModel(place: Self.paris, service: StubWeatherService(forecast: { _ in throw Boom() }))
        await model.load()
        #expect(model.state == .failed(.unexpected))
    }

    @Test("A forecast with no days is a failure the user can retry, not an empty ranking")
    func noDaysIsFailure() async {
        let model = ForecastViewModel(place: Self.paris, service: StubWeatherService(forecast: { _ in [] }))
        await model.load()
        #expect(model.state == .failed(.unexpected))
    }

    @Test("retry() after a failure loads again and recovers")
    func retryRecovers() async {
        let attempts = Recorder<Place>()
        let model = ForecastViewModel(place: Self.paris, service: StubWeatherService(forecast: { place in
            await attempts.append(place)
            if await attempts.values.count == 1 { throw UserFacingError.offline }
            return Self.alpineWeek
        }))
        await model.load()
        #expect(model.state == .failed(.offline))

        await model.retry()
        #expect(model.state == .loaded(WeeklyRanker.rank(Self.alpineWeek, for: Self.paris)))
        #expect(await attempts.values.count == 2)
    }

    @Test("A CancellationError from the service never changes the state")
    func cancellationErrorIgnored() async {
        let model = ForecastViewModel(place: Self.paris, service: StubWeatherService(forecast: { _ in
            throw CancellationError()
        }))
        await model.load()
        #expect(model.state == .loading)
    }

    @Test("cancel() drops the in-flight result even when the service still answers (specs/005 FR-012)")
    func cancelledResultDropped() async {
        let started = Gate()
        let release = Gate()
        let model = ForecastViewModel(place: Self.paris, service: StubWeatherService(forecast: { _ in
            started.open()
            await release.wait()
            return Self.alpineWeek
        }))
        let load = Task { await model.load() }
        await started.wait()
        model.cancel()
        release.open()
        await load.value
        #expect(model.state == .loading)
    }
}

// MARK: - Surviving view rebuilds (specs/003 FR-007, data-model.md › ForecastModel)

/// A fold or window resize can rebuild the forecast column, which reruns its `.task`.
extension ForecastViewModelTests {
    private static func countingService(_ calls: Recorder<Place>) -> StubWeatherService {
        StubWeatherService(forecast: { place in
            await calls.append(place)
            return Self.alpineWeek
        })
    }

    @Test("loadIfNeeded() on a fresh model loads once")
    func loadIfNeededLoads() async {
        let calls = Recorder<Place>()
        let model = ForecastViewModel(place: Self.paris, service: Self.countingService(calls))
        await model.loadIfNeeded()
        #expect(await calls.values == [Self.paris])
        #expect(model.state == .loaded(WeeklyRanker.rank(Self.alpineWeek, for: Self.paris)))
    }

    @Test("loadIfNeeded() after the week is loaded makes no request")
    func loadIfNeededSkipsWhenLoaded() async {
        let calls = Recorder<Place>()
        let model = ForecastViewModel(place: Self.paris, service: Self.countingService(calls))
        await model.loadIfNeeded()
        await model.loadIfNeeded()
        #expect(await calls.values.count == 1)
    }

    @Test("retry() always loads again, even when loaded")
    func retryReloadsWhenLoaded() async {
        let calls = Recorder<Place>()
        let model = ForecastViewModel(place: Self.paris, service: Self.countingService(calls))
        await model.loadIfNeeded()
        await model.retry()
        #expect(await calls.values.count == 2)
    }

    @Test("A view task cancelled mid-flight does not stop the load; the next call joins it (specs/005 FR-012)")
    func cancelledViewTaskKeepsLoading() async {
        let started = Gate()
        let release = Gate()
        let calls = Recorder<Place>()
        let model = ForecastViewModel(place: Self.paris, service: StubWeatherService(forecast: { place in
            await calls.append(place)
            started.open()
            await release.wait()
            return Self.alpineWeek
        }))

        // SwiftUI can send a stray disappear during a push, cancelling the view's `.task`
        // while the screen stays visible (bug: endless spinner on iPhone 18 Pro).
        let first = Task { await model.loadIfNeeded() }
        await started.wait()
        first.cancel()
        release.open()
        await first.value

        await model.loadIfNeeded()
        #expect(await calls.values.count == 1)
        #expect(model.state == .loaded(WeeklyRanker.rank(Self.alpineWeek, for: Self.paris)))
    }

    // MARK: - Day detail presentation (specs/005 FR-006)

    @Test("showDetail(for:) presents the day, and showing another replaces it")
    func showDetailPresentsDay() throws {
        let model = ForecastViewModel(place: Self.paris, service: StubWeatherService())
        #expect(model.presentedDay == nil)
        let days = WeeklyRanker.rank(Self.alpineWeek, for: Self.paris).rankings[0].days
        let day = try #require(days.first)
        let other = try #require(days.last)

        model.showDetail(for: day)
        #expect(model.presentedDay?.day == day)
        #expect(model.presentedDay?.id == day)

        model.showDetail(for: other)
        #expect(model.presentedDay?.day == other)
    }

    @Test("Dismissing clears the presented day, and the day can be shown again")
    func dismissClearsPresentedDay() throws {
        let model = ForecastViewModel(place: Self.paris, service: StubWeatherService())
        let day = try #require(WeeklyRanker.rank(Self.alpineWeek, for: Self.paris).rankings[0].days.first)

        model.showDetail(for: day)
        model.presentedDay = nil
        #expect(model.presentedDay == nil)

        model.showDetail(for: day)
        #expect(model.presentedDay?.day == day)
    }

    @Test("A presented day survives a rebuild's loadIfNeeded() without a refetch (specs/003 US3)")
    func presentedDaySurvivesReload() async throws {
        let fetches = Recorder<Place>()
        let model = ForecastViewModel(place: Self.paris, service: StubWeatherService(forecast: { place in
            await fetches.append(place)
            return Self.alpineWeek
        }))
        await model.loadIfNeeded()
        let day = try #require(WeeklyRanker.rank(Self.alpineWeek, for: Self.paris).rankings[0].days.first)
        model.showDetail(for: day)

        await model.loadIfNeeded()
        #expect(model.presentedDay?.day == day)
        #expect(await fetches.values == [Self.paris])
    }
}
