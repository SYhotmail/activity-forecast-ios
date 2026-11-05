import Testing
@testable import ForecastKit

@Suite("WeeklyRanker: weekly score, best day and ranking (FR-006, FR-007, FR-013, SC-003)")
struct WeeklyRankerTests {
    static let place = Place(id: 1, name: "Testville", region: nil, country: nil,
                             latitude: 0, longitude: 0, timeZone: "GMT")

    static func date(_ offset: Int) -> LocalDate {
        LocalDate(year: 2026, month: 11, day: 3 + offset)!
    }

    // Mirrors DailyWeather's fields so the reference-week tables read as one labelled row per day.
    // swiftlint:disable function_parameter_count
    /// Builds one fully populated day. Rain equals precipitation unless given.
    static func day(_ offset: Int, code: Int, tmax: Double, tmin: Double,
                    precipitation: Double, rain: Double? = nil, snowfall: Double, depth: Double,
                    probability: Double, wind: Double, gusts: Double, sun: Double) -> DailyWeather {
        DailyWeather.metric(date: date(offset), weatherCode: code, temperatureMax: tmax, temperatureMin: tmin,
                     precipitation: precipitation, rain: rain ?? precipitation,
                     snowfall: snowfall, snowDepth: depth, precipitationProbability: probability,
                     windSpeedMax: wind, windGustsMax: gusts, sunshine: sun)
    }
    // swiftlint:enable function_parameter_count

    private func ranking(_ ranking: WeeklyRanking, of activity: Activity) throws -> ActivityRanking {
        try #require(ranking.rankings.first { $0.activity == activity })
    }

    // MARK: - SC-003 reference weeks

    // swiftlint:disable line_length
    // Reference weeks are tables: one day per row with aligned columns, so rows stay unwrapped.

    /// Fresh snow on a deep base, well below freezing, light-to-moderate wind.
    static let snowyAlpine: [DailyWeather] = [
        day(0, code: 73, tmax: -5, tmin: -12, precipitation: 4, rain: 0, snowfall: 20, depth: 80, probability: 85, wind: 15, gusts: 25, sun: 1),
        day(1, code: 75, tmax: -7, tmin: -14, precipitation: 6, rain: 0, snowfall: 25, depth: 95, probability: 90, wind: 20, gusts: 35, sun: 0),
        day(2, code: 71, tmax: -4, tmin: -10, precipitation: 2, rain: 0, snowfall: 8, depth: 105, probability: 70, wind: 12, gusts: 22, sun: 3),
        day(3, code: 3, tmax: -3, tmin: -9, precipitation: 0, rain: 0, snowfall: 0, depth: 100, probability: 20, wind: 10, gusts: 20, sun: 5),
        day(4, code: 73, tmax: -6, tmin: -13, precipitation: 5, rain: 0, snowfall: 18, depth: 110, probability: 80, wind: 25, gusts: 40, sun: 1),
        day(5, code: 71, tmax: -8, tmin: -15, precipitation: 3, rain: 0, snowfall: 10, depth: 115, probability: 75, wind: 15, gusts: 28, sun: 2),
        day(6, code: 2, tmax: -2, tmin: -8, precipitation: 0, rain: 0, snowfall: 0, depth: 112, probability: 10, wind: 8, gusts: 18, sun: 6)
    ]

    /// Steady heavy rain, cool, breezy, almost no sun.
    static let rainyCity: [DailyWeather] = [
        day(0, code: 63, tmax: 11, tmin: 6, precipitation: 12, snowfall: 0, depth: 0, probability: 95, wind: 20, gusts: 40, sun: 0),
        day(1, code: 61, tmax: 12, tmin: 7, precipitation: 9, snowfall: 0, depth: 0, probability: 90, wind: 18, gusts: 35, sun: 0.5),
        day(2, code: 65, tmax: 10, tmin: 5, precipitation: 18, snowfall: 0, depth: 0, probability: 100, wind: 25, gusts: 50, sun: 0),
        day(3, code: 63, tmax: 13, tmin: 8, precipitation: 11, snowfall: 0, depth: 0, probability: 90, wind: 15, gusts: 30, sun: 1),
        day(4, code: 61, tmax: 11, tmin: 6, precipitation: 10, snowfall: 0, depth: 0, probability: 85, wind: 22, gusts: 42, sun: 0),
        day(5, code: 63, tmax: 9, tmin: 4, precipitation: 14, snowfall: 0, depth: 0, probability: 95, wind: 20, gusts: 38, sun: 0),
        day(6, code: 61, tmax: 12, tmin: 7, precipitation: 10, snowfall: 0, depth: 0, probability: 80, wind: 16, gusts: 32, sun: 1)
    ]

    /// Dry, about 20 °C, light wind, long sunny days.
    static let sunnyDry: [DailyWeather] = [
        day(0, code: 0, tmax: 20, tmin: 11, precipitation: 0, snowfall: 0, depth: 0, probability: 0, wind: 10, gusts: 22, sun: 10),
        day(1, code: 1, tmax: 21, tmin: 12, precipitation: 0, snowfall: 0, depth: 0, probability: 5, wind: 12, gusts: 25, sun: 9.5),
        day(2, code: 0, tmax: 19, tmin: 10, precipitation: 0, snowfall: 0, depth: 0, probability: 0, wind: 8, gusts: 18, sun: 11),
        day(3, code: 1, tmax: 22, tmin: 13, precipitation: 0, snowfall: 0, depth: 0, probability: 10, wind: 14, gusts: 28, sun: 9),
        day(4, code: 0, tmax: 20, tmin: 11, precipitation: 0, snowfall: 0, depth: 0, probability: 0, wind: 9, gusts: 20, sun: 10.5),
        day(5, code: 0, tmax: 18, tmin: 9, precipitation: 0, snowfall: 0, depth: 0, probability: 0, wind: 11, gusts: 24, sun: 10),
        day(6, code: 1, tmax: 21, tmin: 12, precipitation: 0, snowfall: 0, depth: 0, probability: 5, wind: 10, gusts: 21, sun: 9)
    ]

    /// Mild (about 22 °C), breezy (about 25 km/h), dry coast.
    static let breezyCoast: [DailyWeather] = [
        day(0, code: 1, tmax: 22, tmin: 16, precipitation: 0, snowfall: 0, depth: 0, probability: 5, wind: 25, gusts: 40, sun: 8),
        day(1, code: 2, tmax: 23, tmin: 17, precipitation: 0, snowfall: 0, depth: 0, probability: 10, wind: 28, gusts: 45, sun: 7),
        day(2, code: 1, tmax: 21, tmin: 15, precipitation: 0, snowfall: 0, depth: 0, probability: 0, wind: 22, gusts: 36, sun: 9),
        day(3, code: 3, tmax: 22, tmin: 16, precipitation: 0.4, snowfall: 0, depth: 0, probability: 15, wind: 30, gusts: 48, sun: 5),
        day(4, code: 1, tmax: 24, tmin: 17, precipitation: 0, snowfall: 0, depth: 0, probability: 5, wind: 25, gusts: 40, sun: 8),
        day(5, code: 2, tmax: 22, tmin: 16, precipitation: 0, snowfall: 0, depth: 0, probability: 10, wind: 26, gusts: 42, sun: 7),
        day(6, code: 1, tmax: 21, tmin: 15, precipitation: 0, snowfall: 0, depth: 0, probability: 0, wind: 24, gusts: 38, sun: 8)
    ]

    // swiftlint:enable line_length

    @Test("SC-003: snowy alpine week ranks Skiing first")
    func snowyAlpineWeek() {
        #expect(WeeklyRanker.rank(Self.snowyAlpine, for: Self.place).rankings.first?.activity == .skiing)
    }

    @Test("SC-003: rainy city week ranks Indoor sightseeing first")
    func rainyCityWeek() {
        #expect(WeeklyRanker.rank(Self.rainyCity, for: Self.place).rankings.first?.activity == .indoorSightseeing)
    }

    @Test("SC-003: sunny, dry 20 °C week ranks Outdoor sightseeing first")
    func sunnyDryWeek() {
        #expect(WeeklyRanker.rank(Self.sunnyDry, for: Self.place).rankings.first?.activity == .outdoorSightseeing)
    }

    @Test("SC-003: mild, breezy, dry coastal week ranks Surfing above Skiing")
    func breezyCoastWeek() throws {
        let result = WeeklyRanker.rank(Self.breezyCoast, for: Self.place)
        let surfing = try ranking(result, of: .surfing)
        let skiing = try ranking(result, of: .skiing)
        #expect(surfing.rank < skiing.rank)
    }

    @Test("every reference week yields four activities ranked 1…4 with seven dated days each",
          arguments: [snowyAlpine, rainyCity, sunnyDry, breezyCoast])
    func shape(week: [DailyWeather]) {
        let result = WeeklyRanker.rank(week, for: Self.place)
        #expect(result.place == Self.place)
        #expect(result.rankings.map(\.rank) == [1, 2, 3, 4])
        #expect(Set(result.rankings.map(\.activity)) == Set(Activity.allCases))
        for activity in result.rankings {
            #expect(activity.days.count == 7)
            #expect(activity.days.allSatisfy { $0.activity == activity.activity })
            #expect(activity.days.map(\.date) == week.map(\.date))
        }
    }

    @Test("ranking is deterministic (FR-009)")
    func deterministic() {
        for week in [Self.snowyAlpine, Self.rainyCity, Self.sunnyDry, Self.breezyCoast] {
            #expect(WeeklyRanker.rank(week, for: Self.place) == WeeklyRanker.rank(week, for: Self.place))
        }
    }

    // MARK: - Weekly score and No data (FR-006, FR-013)

    /// 20 °C, dry, light wind, 9 h sun: Outdoor sightseeing 100. `sun: 0` gives 85.
    func outdoorDay(_ offset: Int, sun: Double = 9, probability: Double? = 0) -> DailyWeather {
        DailyWeather.metric(date: Self.date(offset), weatherCode: 1, temperatureMax: 20, temperatureMin: 12,
                     precipitation: 0, rain: 0, snowfall: 0, snowDepth: 0,
                     precipitationProbability: probability, windSpeedMax: 10, windGustsMax: 20, sunshine: sun)
    }

    @Test("weekly score is the rounded mean of scored days; No data days are excluded, not zero")
    func weeklyMeanExcludesNoData() throws {
        // Outdoor: 100, 85, No data, 85 → (100 + 85 + 85) / 3 = 90.
        let week = [outdoorDay(0), outdoorDay(1, sun: 0), outdoorDay(2, probability: nil), outdoorDay(3, sun: 0)]
        let outdoor = try ranking(WeeklyRanker.rank(week, for: Self.place), of: .outdoorSightseeing)
        #expect(outdoor.days.map(\.score) == [100, 85, nil, 85])
        #expect(outdoor.weeklyScore == 90)
        #expect(outdoor.weeklyLabel == .excellent)
    }

    @Test("weekly score rounds the mean to the nearest integer")
    func weeklyMeanRounds() throws {
        // Outdoor: 100, 100, 85 → 95; 100, 85, 85 → 90; 100, 100, 100, 85 → 96.25 → 96.
        let rank = { (week: [DailyWeather]) in
            try self.ranking(WeeklyRanker.rank(week, for: Self.place), of: .outdoorSightseeing).weeklyScore
        }
        #expect(try rank([outdoorDay(0), outdoorDay(1), outdoorDay(2, sun: 0)]) == 95)
        #expect(try rank([outdoorDay(0), outdoorDay(1), outdoorDay(2), outdoorDay(3, sun: 0)]) == 96)
        // 100, 85, 85, 85 → 88.75 → 89.
        #expect(try rank([outdoorDay(0), outdoorDay(1, sun: 0), outdoorDay(2, sun: 0), outdoorDay(3, sun: 0)]) == 89)
    }

    @Test("an activity with no scored day has no weekly score and no best day, and ranks last")
    func allNoData() throws {
        // weatherCode missing: surfing, outdoor and indoor need it; skiing does not.
        var weather = Self.snowyAlpine[0]
        weather.weatherCode = nil
        let result = WeeklyRanker.rank([weather], for: Self.place)
        #expect(result.rankings.map(\.activity) == [.skiing, .surfing, .outdoorSightseeing, .indoorSightseeing])
        for activity in result.rankings.dropFirst() {
            #expect(activity.weeklyScore == nil)
            #expect(activity.weeklyLabel == nil)
            #expect(activity.bestDay == nil)
            #expect(activity.days.map(\.result) == [.noData])
        }
    }

    @Test("an empty forecast ranks all four activities without scores, in the fixed order")
    func emptyForecast() {
        let result = WeeklyRanker.rank([], for: Self.place)
        #expect(result.rankings.map(\.activity) == Activity.allCases)
        #expect(result.rankings.map(\.rank) == [1, 2, 3, 4])
        #expect(result.rankings.allSatisfy { $0.weeklyScore == nil && $0.bestDay == nil && $0.days.isEmpty })
    }

    @Test("days are returned in date order whatever the input order")
    func sortsDays() throws {
        let week = [outdoorDay(2), outdoorDay(0, sun: 0), outdoorDay(1)]
        let outdoor = try ranking(WeeklyRanker.rank(week, for: Self.place), of: .outdoorSightseeing)
        #expect(outdoor.days.map(\.date) == [Self.date(0), Self.date(1), Self.date(2)])
    }

    // MARK: - Best day (FR-007)

    @Test("best day is the highest-scoring day, the earliest if tied, regardless of input order")
    func bestDayEarliestIfTied() throws {
        // Outdoor: 85, 100, 100 → day 1.
        let week = [outdoorDay(2), outdoorDay(1), outdoorDay(0, sun: 0)]
        let outdoor = try ranking(WeeklyRanker.rank(week, for: Self.place), of: .outdoorSightseeing)
        #expect(outdoor.bestDay == Self.date(1))
    }

    /// No snowfall, `depth` cm of snow, tmax 5 °C, tmin −1 °C (no cap), gusts 70, no rain:
    /// skiing = depth / 100 × 50 + 10.
    func thinSnowDay(_ offset: Int, depth: Double) -> DailyWeather {
        Self.day(offset, code: 3, tmax: 5, tmin: -1, precipitation: 0, snowfall: 0, depth: depth,
            probability: 0, wind: 40, gusts: 70, sun: 4)
    }

    @Test("best day is marked only when its score reaches 25 (Fair)", arguments: [
        (28.0, 24, false), (30.0, 25, true), (60.0, 40, true)
    ])
    func bestDayThreshold(depth: Double, expectedScore: Int, marked: Bool) throws {
        let week = [thinSnowDay(0, depth: 0), thinSnowDay(1, depth: depth), thinSnowDay(2, depth: 0)]
        let skiing = try ranking(WeeklyRanker.rank(week, for: Self.place), of: .skiing)
        #expect(skiing.days.map(\.score) == [10, expectedScore, 10])
        #expect(skiing.bestDay == (marked ? Self.date(1) : nil))
    }

    @Test("a week of capped skiing days has no best day")
    func noSuitableDay() throws {
        let skiing = try ranking(WeeklyRanker.rank(Self.sunnyDry, for: Self.place), of: .skiing)
        #expect(skiing.days.allSatisfy { ($0.score ?? 0) <= 10 })
        #expect(skiing.bestDay == nil)
    }

    // MARK: - Tie-breaks (FR-006, Edge Cases)

    private static func scored(_ activity: Activity, _ scores: [Int?]) -> [DaySuitability] {
        scores.enumerated().map { offset, score in
            let result: DaySuitability.Result = score.map {
                .scored(score: $0, label: SuitabilityLabel(score: $0), reasons: [])
            } ?? .noData
            return DaySuitability(activity: activity, weather: DailyWeather.metric(date: date(offset)), result: result)
        }
    }

    @Test("equal weekly scores are broken by the higher best daily score")
    func tieBreakByBestDailyScore() {
        let result = WeeklyRanker.rank([
            .skiing: Self.scored(.skiing, [50, 50]),
            .surfing: Self.scored(.surfing, [40, 60]),
            .outdoorSightseeing: Self.scored(.outdoorSightseeing, [70, 70]),
            .indoorSightseeing: Self.scored(.indoorSightseeing, [30, 30])
        ], for: Self.place)
        #expect(result.rankings.map(\.activity) == [.outdoorSightseeing, .surfing, .skiing, .indoorSightseeing])
        #expect(result.rankings.map(\.rank) == [1, 2, 3, 4])
        #expect(result.rankings.map(\.weeklyScore) == [70, 50, 50, 30])
    }

    @Test("a full tie falls back to the fixed activity order")
    func tieBreakByActivityOrder() {
        let result = WeeklyRanker.rank([
            .indoorSightseeing: Self.scored(.indoorSightseeing, [40, 60]),
            .outdoorSightseeing: Self.scored(.outdoorSightseeing, [60, 40]),
            .surfing: Self.scored(.surfing, [50, 50]),
            .skiing: Self.scored(.skiing, [60, nil, 40])
        ], for: Self.place)
        // Weekly 50 for all; best daily 60 for skiing, outdoor and indoor, 50 for surfing.
        #expect(result.rankings.map(\.activity) == [.skiing, .outdoorSightseeing, .indoorSightseeing, .surfing])
    }

    @Test("activities without a weekly score rank after every scored activity")
    func unscoredLast() {
        let result = WeeklyRanker.rank([
            .skiing: Self.scored(.skiing, [nil, nil]),
            .surfing: Self.scored(.surfing, [5, 3]),
            .outdoorSightseeing: Self.scored(.outdoorSightseeing, [nil]),
            .indoorSightseeing: Self.scored(.indoorSightseeing, [30, nil])
        ], for: Self.place)
        #expect(result.rankings.map(\.activity) == [.indoorSightseeing, .surfing, .skiing, .outdoorSightseeing])
        #expect(result.rankings.map(\.weeklyScore) == [30, 4, nil, nil])
        #expect(result.rankings.map(\.bestDay) == [Self.date(0), nil, nil, nil])
    }
}
