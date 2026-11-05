import Foundation
import Testing
@testable import ForecastKit

/// Scores depend on the weather, not on the units it arrived in (specs/006 FR-005, SC-001).
@Suite("Scoring is unit-independent (specs/006)")
struct UnitIndependenceTests {
    /// What a user sees of a ranking, minus the measured values themselves.
    struct Outcome: Equatable {
        let activity: Activity
        let rank: Int
        let weeklyScore: Int?
        let bestDay: LocalDate?
        let dayScores: [Int?]
        let reasonKinds: [[Reason.Kind]]
    }

    private static func outcome(_ week: [DailyWeather]) -> [Outcome] {
        WeeklyRanker.rank(week, for: WeeklyRankerTests.place).rankings.map { ranking in
            Outcome(activity: ranking.activity, rank: ranking.rank, weeklyScore: ranking.weeklyScore,
                    bestDay: ranking.bestDay, dayScores: ranking.days.map(\.score),
                    reasonKinds: ranking.days.map { day in
                        if case let .scored(_, _, reasons) = day.result { reasons.map(\.kind) } else { [] }
                    })
        }
    }

    @Test("each reference week ranks identically in °F, inches, feet and mph (SC-001)",
          arguments: [WeeklyRankerTests.snowyAlpine, WeeklyRankerTests.rainyCity,
                      WeeklyRankerTests.sunnyDry, WeeklyRankerTests.breezyCoast])
    func referenceWeeks(week: [DailyWeather]) {
        #expect(Self.outcome(week.map(\.imperial)) == Self.outcome(week))
    }

    @Test("every activity scores the same day the same in both unit systems",
          arguments: Activity.allCases)
    func everyActivity(activity: Activity) {
        for day in ActivityScorerTests.indoorCases + [ActivityScorerTests.perfectSkiing] {
            #expect(ActivityScorer.suitability(for: activity, on: day.imperial).score
                    == ActivityScorer.suitability(for: activity, on: day).score)
        }
    }

    @Test("snow depth in feet or metres gives the skiing score of the same depth in cm")
    func snowDepthUnits() {
        let base = DailyWeather.metric(date: ActivityScorerTests.date, weatherCode: 3,
                                       temperatureMax: -2, precipitation: 0, rain: 0,
                                       snowfall: 0, snowDepth: 50, windGustsMax: 20)
        var feet = base
        feet.snowDepth = Measurement(value: 50 / 30.48, unit: .feet)
        var metres = base
        metres.snowDepth = .metres(0.5)
        let expected = ActivityScorer.suitability(for: .skiing, on: base).score
        #expect(expected == 75)
        #expect(ActivityScorer.suitability(for: .skiing, on: feet).score == expected)
        #expect(ActivityScorer.suitability(for: .skiing, on: metres).score == expected)
    }

    @Test("caps hold at their converted thresholds: 2 cm snowfall stops outdoor sightseeing")
    func capInOtherUnits() {
        let snowy = DailyWeather.metric(date: ActivityScorerTests.date, weatherCode: 1,
                                        temperatureMax: 20, precipitation: 0, rain: 0, snowfall: 0,
                                        precipitationProbability: 0, windSpeedMax: 10, sunshine: 9)
        var under = snowy
        under.snowfall = .inches(0.7)   // 1.78 cm
        var over = snowy
        over.snowfall = .inches(0.8)    // 2.03 cm
        #expect(ActivityScorer.suitability(for: .outdoorSightseeing, on: under).score == 100)
        #expect(ActivityScorer.suitability(for: .outdoorSightseeing, on: over).score == 20)
    }
}
