import Foundation
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

    @Test("LocalDate rejects invalid days and orders chronologically")
    func localDate() throws {
        let a = try #require(LocalDate(year: 2026, month: 11, day: 3))
        let b = try #require(LocalDate(year: 2026, month: 11, day: 10))
        #expect(a < b)
        #expect(LocalDate(year: 2026, month: 13, day: 1) == nil)
        #expect(LocalDate(year: 2026, month: 2, day: 30) == nil)
    }

    @Test("an instant becomes the calendar day of the given time zone, not the device's (FR-003)")
    func localDateFromInstant() throws {
        let instant = Date(timeIntervalSince1970: 1793833200) // 2026-11-04T23:00Z
        let paris = try #require(TimeZone(identifier: "Europe/Paris"))
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        #expect(LocalDate(instant, in: paris) == LocalDate(year: 2026, month: 11, day: 5))
        #expect(LocalDate(instant, in: .gmt) == LocalDate(year: 2026, month: 11, day: 4))
        #expect(LocalDate(instant, in: newYork) == LocalDate(year: 2026, month: 11, day: 4))
    }

    @Test("activities keep the fixed tie-break order")
    func activityOrder() {
        #expect(Activity.allCases == [.skiing, .surfing, .outdoorSightseeing, .indoorSightseeing])
    }
}
