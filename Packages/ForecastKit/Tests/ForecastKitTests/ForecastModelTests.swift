import Testing
@testable import ForecastKit

@MainActor
@Suite("ForecastModel: load → ranked week (FR-003, FR-006)")
struct ForecastModelTests {
    nonisolated static let paris = Place(id: 2988507, name: "Paris", region: "Île-de-France Region",
                                         country: "France", latitude: 48.85, longitude: 2.35,
                                         timeZone: "Europe/Paris")

    /// Seven snowy, cold days: a clear Skiing week.
    nonisolated static let alpineWeek: [DailyWeather] = (3...9).map { day in
        DailyWeather(date: LocalDate(year: 2026, month: 11, day: day)!, weatherCode: 73,
                     temperatureMax: -5, temperatureMin: -10, precipitation: 2, rain: 0,
                     snowfall: 20, snowDepth: 80, precipitationProbability: 80,
                     windSpeedMax: 15, windGustsMax: 25, sunshine: 2)
    }

    @Test("Starts loading so the screen never shows a blank idle state")
    func startsLoading() {
        let model = ForecastModel(place: Self.paris, service: StubWeatherService())
        #expect(model.place == Self.paris)
        #expect(model.state == .loading)
    }

    @Test("load() publishes the week ranked by WeeklyRanker")
    func loadRanks() async {
        let model = ForecastModel(place: Self.paris, service: StubWeatherService(forecast: { _ in
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
        let model = ForecastModel(place: Self.paris, service: StubWeatherService(forecast: { place in
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
        let model = ForecastModel(place: Self.paris, service: StubWeatherService(forecast: { _ in
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
