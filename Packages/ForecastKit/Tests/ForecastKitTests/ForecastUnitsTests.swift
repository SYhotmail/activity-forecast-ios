import Foundation
import Testing
@testable import ForecastKit

/// Request units follow the user's locale (specs/006 FR-002, research R2).
@Suite("ForecastUnits from the locale")
struct ForecastUnitsTests {
    @Test("the US gets °F, mph and inches")
    func unitedStates() {
        #expect(ForecastUnits(locale: Locale(identifier: "en_US")) == .imperial)
    }

    @Test("metric regions get °C, km/h and mm", arguments: ["de_DE", "fr_FR", "ja_JP", "en_AU"])
    func metric(identifier: String) {
        #expect(ForecastUnits(locale: Locale(identifier: identifier)) == .metric)
    }

    @Test("the UK keeps °C and mm but measures wind in mph")
    func unitedKingdom() {
        #expect(ForecastUnits(locale: Locale(identifier: "en_GB"))
                == ForecastUnits(temperature: .celsius, windSpeed: .milesPerHour, precipitation: .millimetres))
    }

    @Test("the user's temperature setting overrides the region default")
    func temperatureOverride() {
        #expect(ForecastUnits(locale: Locale(identifier: "en_US@temperature=celsius")).temperature == .celsius)
        #expect(ForecastUnits(locale: Locale(identifier: "de_DE@temperature=fahrenheit")).temperature == .fahrenheit)
    }
}
