import Testing
@testable import ForecastKit

@Suite("Domain models")
struct ModelsTests {
    private func place(region: String?, country: String?) -> Place {
        Place(id: 1, name: "Paris", region: region, country: country,
              latitude: 48.85, longitude: 2.35, timeZone: "Europe/Paris")
    }

    @Test("displayName joins name, region and country that are present (FR-002)")
    func displayName() {
        #expect(place(region: "Île-de-France", country: "France").displayName == "Paris, Île-de-France, France")
        #expect(place(region: nil, country: "France").displayName == "Paris, France")
        #expect(place(region: "", country: nil).displayName == "Paris")
        #expect(place(region: "Texas", country: "United States").subtitle == "Texas, United States")
        #expect(place(region: nil, country: nil).subtitle == nil)
    }

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
