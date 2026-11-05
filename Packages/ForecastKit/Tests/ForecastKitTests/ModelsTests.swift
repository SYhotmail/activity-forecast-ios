import Testing
@testable import ForecastKit

@Suite("Domain models")
struct ModelsTests {
    @Test("score bands map to labels at every edge (FR-005)", arguments: [
        (0, SuitabilityLabel.poor), (24, .poor), (25, .fair), (49, .fair),
        (50, .good), (74, .good), (75, .excellent), (100, .excellent)
    ])
    func labelBands(score: Int, expected: SuitabilityLabel) {
        #expect(SuitabilityLabel(score: score) == expected)
    }

    @Test("LocalDate parses yyyy-MM-dd and orders chronologically")
    func localDate() throws {
        let a = try #require(LocalDate(iso8601: "2026-11-03"))
        let b = try #require(LocalDate(iso8601: "2026-11-10"))
        #expect(a.year == 2026 && a.month == 11 && a.day == 3)
        #expect(a < b)
        #expect(LocalDate(iso8601: "2026-13-01") == nil)
        #expect(LocalDate(iso8601: "nonsense") == nil)
    }

    @Test("activities keep the fixed tie-break order")
    func activityOrder() {
        #expect(Activity.allCases == [.skiing, .surfing, .outdoorSightseeing, .indoorSightseeing])
    }
}
