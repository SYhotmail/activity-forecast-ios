import Foundation
import Testing
import ForecastKit
@testable import ActivityForecast

/// Display text the app derives from ForecastKit's typed values (ForecastKit carries no UI strings).
@MainActor
@Suite("Display text for domain values")
struct DisplayTextTests {
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

    @Test("activity and label titles")
    func titles() {
        #expect(Activity.allCases.map(\.title)
                == ["Skiing", "Surfing", "Outdoor sightseeing", "Indoor sightseeing"])
        #expect(SuitabilityLabel.allCases.map(\.title) == ["Poor", "Fair", "Good", "Excellent"])
    }

    @Test("every error has a retry-friendly message (FR-011)")
    func errorMessages() {
        #expect(UserFacingError.offline.message.contains("offline"))
        #expect(UserFacingError.serviceUnavailable.message.contains("weather service"))
        #expect(UserFacingError.unexpected.message.contains("Something went wrong"))
    }

    @Test("reasons read as a phrase plus the value in its metric unit (FR-008, FR-016)")
    func measuredReasons() {
        let millimetres = Formatting.metric(12, UnitLength.millimeters)
        #expect(Reason.Detail.heavyRain(millimetres: 12).text == "Heavy rain \(millimetres)")
        #expect(Reason.Detail.freshSnow(centimetres: 20).text
                == "Fresh snow \(Formatting.metric(20, UnitLength.centimeters))")
        #expect(Reason.Detail.strongGusts(kilometresPerHour: 65).text
                == "Strong gusts \(Formatting.metric(65, UnitSpeed.kilometersPerHour))")
        #expect(Reason.Detail.comfortable(celsius: 20).text
                == "Comfortable \(Formatting.metric(20, UnitTemperature.celsius))")
        #expect(Reason.Detail.rainLikely(percent: 80).text == "Rain likely \(Formatting.percent(80))")
    }

    @Test("decimal values keep one decimal place at most")
    func decimals() {
        let rounded = Formatting.metric(7.5, UnitLength.millimeters)
        #expect(Reason.Detail.rain(millimetres: 7.54).text == "Rain \(rounded)")
        #expect(!Formatting.metric(12, UnitLength.millimeters).contains("12.0"))
        #expect(!Formatting.metric(12, UnitLength.millimeters).contains("12,0"))
    }

    @Test("caps and indoor reasons are fixed phrases")
    func fixedPhrases() {
        #expect(Reason.Detail.thunderstorms.text == "Thunderstorms expected")
        #expect(Reason.Detail.noSnowOnGround.text == "No snow on the ground")
        #expect(Reason.Detail.snowfallExpected.text == "Snowfall expected")
        #expect(Reason.Detail.poorWeatherOutside.text == "Poor weather outside — good day for museums")
        #expect(Reason.Detail.greatWeatherOutside.text == "Great weather outside — better spent outdoors")
    }
}
