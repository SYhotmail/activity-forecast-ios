import Testing
@testable import ForecastKit

/// Every expected number below is hand-computed from research.md R9:
/// factor value (0…1) × weight, summed, rounded, clamped to 0…100, then capped.
/// Each parameterised case starts from a "perfect" day for the activity (score 100)
/// and moves exactly one input, so the expected drop is that factor's weight × (1 − value).
@Suite("ActivityScorer: daily suitability per activity (FR-004, FR-009, FR-010, FR-013)")
struct ActivityScorerTests {
    static let date = LocalDate(year: 2026, month: 11, day: 3)!

    /// Snowy, cold, calm: Skiing 100.
    static let perfectSkiing = DailyWeather.metric(
        date: date, weatherCode: 73, temperatureMax: -5, temperatureMin: -10,
        precipitation: 2, rain: 0, snowfall: 20, snowDepth: 80,
        precipitationProbability: 80, windSpeedMax: 15, windGustsMax: 25, sunshine: 2)

    /// 22 °C, 25 km/h breeze, dry: Surfing 100.
    static let perfectSurfing = DailyWeather.metric(
        date: date, weatherCode: 1, temperatureMax: 22, temperatureMin: 15,
        precipitation: 0, rain: 0, snowfall: 0, snowDepth: 0,
        precipitationProbability: 0, windSpeedMax: 25, windGustsMax: 40, sunshine: 9)

    /// 20 °C, dry, light wind, 9 h sun: Outdoor sightseeing 100.
    static let perfectOutdoor = DailyWeather.metric(
        date: date, weatherCode: 1, temperatureMax: 20, temperatureMin: 12,
        precipitation: 0, rain: 0, snowfall: 0, snowDepth: 0,
        precipitationProbability: 0, windSpeedMax: 10, windGustsMax: 20, sunshine: 9)

    private func score(_ activity: Activity, _ weather: DailyWeather) -> Int? {
        ActivityScorer.suitability(for: activity, on: weather).score
    }

    func with(_ base: DailyWeather, _ change: (inout DailyWeather) -> Void) -> DailyWeather {
        var copy = base
        change(&copy)
        return copy
    }

    // MARK: - Perfect days

    @Test("a perfect day for each outdoor activity scores 100 and is Excellent")
    func perfectDays() {
        for (activity, weather) in [(Activity.skiing, Self.perfectSkiing),
                                    (.surfing, Self.perfectSurfing),
                                    (.outdoorSightseeing, Self.perfectOutdoor)] {
            let result = ActivityScorer.suitability(for: activity, on: weather)
            #expect(result.activity == activity)
            #expect(result.weather == weather)
            #expect(result.score == 100)
            if case let .scored(_, label, _) = result.result {
                #expect(label == .excellent)
            } else {
                Issue.record("\(activity) should be scored")
            }
        }
    }

    // MARK: - Skiing

    @Test("skiing snow factor: min(1, snowfall/10 + depth/100), weight 50", arguments: [
        (0.0, 0.0, 10), (5.0, 0.0, 75), (0.0, 50.0, 75), (10.0, 0.0, 100), (0.0, 100.0, 100), (30.0, 200.0, 100)
    ])
    func skiingSnow(snowfall: Double, depth: Double, expected: Int) {
        // Zero snow hits the no-snow cap (raw 50 → 10); any snow lifts it.
        let weather = with(Self.perfectSkiing) {
            $0.snowfall = .centimetres(snowfall); $0.snowDepth = .centimetres(depth)
        }
        #expect(score(.skiing, weather) == expected)
    }

    @Test("skiing cold factor: tmax ≤ 0 → 1, ≥ 5 → 0, weight 25", arguments: [
        (-20.0, 100), (0.0, 100), (2.0, 90), (5.0, 75), (15.0, 75)
    ])
    func skiingCold(tmax: Double, expected: Int) {
        #expect(score(.skiing, with(Self.perfectSkiing) { $0.temperatureMax = .celsius(tmax) }) == expected)
    }

    @Test("skiing wind factor uses gusts: ≤ 30 → 1, ≥ 70 → 0, weight 15", arguments: [
        (0.0, 100), (30.0, 100), (60.0, 89), (70.0, 85), (120.0, 85)
    ])
    func skiingWind(gusts: Double, expected: Int) {
        #expect(score(.skiing, with(Self.perfectSkiing) { $0.windGustsMax = .kilometresPerHour(gusts) }) == expected)
    }

    @Test("skiing no-rain factor: 1 − min(rain/10, 1), weight 10", arguments: [
        (0.0, 100), (5.0, 95), (10.0, 90), (25.0, 90)
    ])
    func skiingRain(rain: Double, expected: Int) {
        #expect(score(.skiing, with(Self.perfectSkiing) { $0.rain = .millimetres(rain) }) == expected)
    }

    @Test("skiing cap: no snowfall and no snow depth → at most 10, whatever the temperature")
    func skiingCap() {
        // Raw: snow 0 + cold 0.6×25 + wind 15 + rain 10 = 40.
        let mild = with(Self.perfectSkiing) {
            $0.snowfall = .centimetres(0); $0.snowDepth = .centimetres(0)
            $0.temperatureMax = .celsius(2); $0.temperatureMin = .celsius(1)
        }
        let capped = ActivityScorer.suitability(for: .skiing, on: mild)
        #expect(capped.score == 10)
        if case let .scored(_, label, reasons) = capped.result {
            #expect(label == .poor)
            #expect(reasons.first?.kind == .cap)
        }

        // Found in a live check (Chamonix, 0 cm snow, tmin −3.9 °C scored Fair 25 with a ★ best day):
        // you cannot ski without snow, so a freezing night must not lift the cap.
        #expect(score(.skiing, with(mild) { $0.temperatureMin = .celsius(-4) }) == 10)
        #expect(score(.skiing, with(mild) { $0.temperatureMax = .celsius(-2); $0.temperatureMin = .celsius(-8) }) == 10)
        // The skiing score does not read tmin, so a missing tmin is not "No data".
        #expect(score(.skiing, with(mild) { $0.temperatureMin = nil }) == 10)

        // Any snow on its own lifts the cap.
        #expect(score(.skiing, with(mild) { $0.snowDepth = .centimetres(10) }) == 45)
        #expect(score(.skiing, with(mild) { $0.snowfall = .centimetres(1) }) == 45)

        // A raw score already below the cap is kept.
        let awful = with(mild) {
            $0.temperatureMax = .celsius(20); $0.temperatureMin = .celsius(10)
            $0.rain = .millimetres(20); $0.windGustsMax = .kilometresPerHour(100)
        }
        #expect(score(.skiing, awful) == 0)
    }

    // MARK: - Surfing

    @Test("surfing wind factor: 0 → 0.3, 15–35 → 1, ≥ 50 → 0, weight 40", arguments: [
        (0.0, 72), (7.5, 86), (15.0, 100), (35.0, 100), (42.5, 80), (50.0, 60), (90.0, 60)
    ])
    func surfingWind(wind: Double, expected: Int) {
        #expect(score(.surfing, with(Self.perfectSurfing) { $0.windSpeedMax = .kilometresPerHour(wind) }) == expected)
    }

    @Test("surfing warmth factor: ≤ 5 → 0, 18–30 → 1, ≥ 38 → 0.5, weight 30", arguments: [
        (-5.0, 70), (5.0, 70), (11.5, 85), (18.0, 100), (30.0, 100), (36.0, 89), (38.0, 85), (45.0, 85)
    ])
    func surfingWarmth(tmax: Double, expected: Int) {
        #expect(score(.surfing, with(Self.perfectSurfing) { $0.temperatureMax = .celsius(tmax) }) == expected)
    }

    @Test("surfing dry factor: 1 − min(precipitation/10, 1), weight 30", arguments: [
        (0.0, 100), (5.0, 85), (10.0, 70), (40.0, 70)
    ])
    func surfingDry(precipitation: Double, expected: Int) {
        let weather = with(Self.perfectSurfing) { $0.precipitation = .millimetres(precipitation) }
        #expect(score(.surfing, weather) == expected)
    }

    @Test("surfing cap: thunderstorm (WMO 95–99) → at most 10", arguments: [
        (94, 100), (95, 10), (96, 10), (99, 10)
    ])
    func surfingCap(code: Int, expected: Int) {
        let result = ActivityScorer.suitability(for: .surfing, on: with(Self.perfectSurfing) { $0.weatherCode = code })
        #expect(result.score == expected)
        if expected == 10, case let .scored(_, _, reasons) = result.result {
            #expect(reasons.first?.kind == .cap)
        }
    }

    // MARK: - Outdoor sightseeing

    @Test("outdoor comfort factor: tmax ≤ 0 or ≥ 38 → 0, 15–25 → 1, weight 35", arguments: [
        (-5.0, 65), (0.0, 65), (12.0, 93), (15.0, 100), (25.0, 100), (35.0, 73), (38.0, 65), (45.0, 65)
    ])
    func outdoorComfort(tmax: Double, expected: Int) {
        let weather = with(Self.perfectOutdoor) { $0.temperatureMax = .celsius(tmax) }
        #expect(score(.outdoorSightseeing, weather) == expected)
    }

    @Test("outdoor dry factor: 1 − max(min(precip/10, 1), probability/100 × 0.5), weight 35", arguments: [
        (0.0, 0.0, 100), (4.0, 0.0, 86), (10.0, 0.0, 65), (30.0, 100.0, 65),
        (0.0, 40.0, 93), (2.0, 80.0, 86), (8.0, 20.0, 72)
    ])
    func outdoorDry(precipitation: Double, probability: Double, expected: Int) {
        let weather = with(Self.perfectOutdoor) {
            $0.precipitation = .millimetres(precipitation); $0.precipitationProbability = probability
        }
        #expect(score(.outdoorSightseeing, weather) == expected)
    }

    @Test("outdoor calm factor: wind ≤ 20 → 1, ≥ 50 → 0, weight 15", arguments: [
        (0.0, 100), (20.0, 100), (30.0, 95), (50.0, 85), (80.0, 85)
    ])
    func outdoorCalm(wind: Double, expected: Int) {
        let weather = with(Self.perfectOutdoor) { $0.windSpeedMax = .kilometresPerHour(wind) }
        #expect(score(.outdoorSightseeing, weather) == expected)
    }

    @Test("outdoor sun factor: min(sunshine hours / 8, 1), weight 15", arguments: [
        (0.0, 85), (2.0, 89), (8.0, 100), (12.0, 100)
    ])
    func outdoorSun(hours: Double, expected: Int) {
        #expect(score(.outdoorSightseeing, with(Self.perfectOutdoor) { $0.sunshine = .hours(hours) }) == expected)
    }

    @Test("outdoor cap: thunderstorm or snowfall ≥ 2 cm → at most 20", arguments: [
        (1, 0.0, 100), (95, 0.0, 20), (99, 0.0, 20), (1, 1.9, 100), (1, 2.0, 20), (71, 15.0, 20)
    ])
    func outdoorCap(code: Int, snowfall: Double, expected: Int) {
        let weather = with(Self.perfectOutdoor) { $0.weatherCode = code; $0.snowfall = .centimetres(snowfall) }
        let result = ActivityScorer.suitability(for: .outdoorSightseeing, on: weather)
        #expect(result.score == expected)
        if expected == 20, case let .scored(_, _, reasons) = result.result {
            #expect(reasons.first?.kind == .cap)
        }
    }

    // MARK: - Indoor sightseeing

    static let indoorCases: [DailyWeather] = [
        perfectOutdoor,                                                     // outdoor 100 → indoor 30
        perfectSkiing,                                                      // outdoor capped 20 → 78
        perfectSurfing,
        DailyWeather.metric(date: date, weatherCode: 63, temperatureMax: 40, temperatureMin: 30,
                     precipitation: 20, rain: 20, snowfall: 0, snowDepth: 0,
                     precipitationProbability: 100, windSpeedMax: 80, windGustsMax: 100,
                     sunshine: 0),                                          // outdoor 0 → indoor 90
        DailyWeather.metric(date: date, weatherCode: 61, temperatureMax: 11, temperatureMin: 6,
                     precipitation: 12, rain: 12, snowfall: 0, snowDepth: 0,
                     precipitationProbability: 90, windSpeedMax: 20, windGustsMax: 35,
                     sunshine: 0)                                           // rainy city: outdoor 41 → 65
    ]

    @Test("indoor = 30 + 0.6 × (100 − outdoor), always within 30…90", arguments: indoorCases)
    func indoorFormula(weather: DailyWeather) throws {
        let outdoor = try #require(score(.outdoorSightseeing, weather))
        let indoor = try #require(score(.indoorSightseeing, weather))
        #expect(indoor == Int((30 + 0.6 * Double(100 - outdoor)).rounded()))
        #expect((30...90).contains(indoor))
    }

    @Test("indoor reaches both ends of its band and the rainy-city value from R9")
    func indoorEnds() {
        #expect(score(.indoorSightseeing, Self.indoorCases[0]) == 30)
        #expect(score(.indoorSightseeing, Self.indoorCases[1]) == 78)
        #expect(score(.indoorSightseeing, Self.indoorCases[3]) == 90)
        #expect(score(.outdoorSightseeing, Self.indoorCases[4]) == 41)
        #expect(score(.indoorSightseeing, Self.indoorCases[4]) == 65)
    }

    // MARK: - Missing values (FR-013)

    enum Field: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case weatherCode, temperatureMax, temperatureMin, precipitation, rain, snowfall,
             snowDepth, precipitationProbability, windSpeedMax, windGustsMax, sunshine

        var testDescription: String { rawValue }

        // One line per DailyWeather field; an exhaustive switch keeps the list checked by the compiler.
        // swiftlint:disable:next cyclomatic_complexity
        func clear(_ weather: inout DailyWeather) {
            switch self {
            case .weatherCode: weather.weatherCode = nil
            case .temperatureMax: weather.temperatureMax = nil
            case .temperatureMin: weather.temperatureMin = nil
            case .precipitation: weather.precipitation = nil
            case .rain: weather.rain = nil
            case .snowfall: weather.snowfall = nil
            case .snowDepth: weather.snowDepth = nil
            case .precipitationProbability: weather.precipitationProbability = nil
            case .windSpeedMax: weather.windSpeedMax = nil
            case .windGustsMax: weather.windGustsMax = nil
            case .sunshine: weather.sunshine = nil
            }
        }
    }

    /// The inputs each activity's factors and caps read. Anything else may be missing.
    static let required: [Activity: Set<Field>] = [
        .skiing: [.snowfall, .snowDepth, .temperatureMax, .windGustsMax, .rain],
        .surfing: [.windSpeedMax, .temperatureMax, .precipitation, .weatherCode],
        .outdoorSightseeing: [.temperatureMax, .precipitation, .precipitationProbability,
                              .windSpeedMax, .sunshine, .snowfall, .weatherCode],
        .indoorSightseeing: [.temperatureMax, .precipitation, .precipitationProbability,
                             .windSpeedMax, .sunshine, .snowfall, .weatherCode]
    ]

    @Test("a missing input gives No data only when the activity needs it, never a zero score",
          arguments: Activity.allCases, Field.allCases)
    func missingValue(activity: Activity, field: Field) {
        var weather = Self.perfectSkiing
        field.clear(&weather)
        let result = ActivityScorer.suitability(for: activity, on: weather).result
        if Self.required[activity]!.contains(field) {
            #expect(result == .noData)
        } else {
            #expect(result != .noData)
        }
    }

    @Test("a day with no values at all is No data for every activity", arguments: Activity.allCases)
    func emptyDay(activity: Activity) {
        #expect(ActivityScorer.suitability(for: activity, on: DailyWeather.metric(date: Self.date)).result == .noData)
    }

    // MARK: - Determinism (FR-009)

    @Test("the same input always gives the same result", arguments: Activity.allCases)
    func deterministic(activity: Activity) {
        for weather in Self.indoorCases {
            let first = ActivityScorer.suitability(for: activity, on: weather)
            for _ in 0..<5 {
                #expect(ActivityScorer.suitability(for: activity, on: weather) == first)
            }
        }
    }

    @Test("labels always match the score band", arguments: Activity.allCases)
    func labelMatchesScore(activity: Activity) {
        for weather in Self.indoorCases {
            if case let .scored(score, label, _) = ActivityScorer.suitability(for: activity, on: weather).result {
                #expect(label == SuitabilityLabel(score: score))
                #expect((0...100).contains(score))
            }
        }
    }
}
