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

    @Test("reasons read as a phrase plus the value in the user's units (FR-008, FR-016)")
    func measuredReasons() {
        #expect(Reason.Detail.heavyRain(.millimetres(12)).text == "Heavy rain \(Formatting.rainfall(.millimetres(12)))")
        #expect(Reason.Detail.freshSnow(.centimetres(20)).text == "Fresh snow \(Formatting.snow(.centimetres(20)))")
        #expect(Reason.Detail.strongGusts(.kilometresPerHour(65)).text
                == "Strong gusts \(Formatting.windSpeed(.kilometresPerHour(65)))")
        #expect(Reason.Detail.comfortable(.celsius(20)).text == "Comfortable \(Formatting.temperature(.celsius(20)))")
        #expect(Reason.Detail.sunny(.hours(6)).text == "Sunny \(Formatting.hours(.hours(6)))")
        #expect(Reason.Detail.rainLikely(percent: 80).text == "Rain likely \(Formatting.percent(80))")
    }

    private static let unitedStates = Locale(identifier: "en_US")
    private static let germany = Locale(identifier: "de_DE")

    @Test("values convert to the locale's units: °F, in and mph in the US (FR-016)")
    func imperialLocale() {
        #expect(Formatting.temperature(.celsius(20), locale: Self.unitedStates) == "68°F")
        #expect(Formatting.rainfall(.millimetres(12), locale: Self.unitedStates) == "0.47 in")
        #expect(Formatting.snow(.centimetres(20), locale: Self.unitedStates) == "7.87 in")
        #expect(Formatting.windSpeed(.kilometresPerHour(65), locale: Self.unitedStates) == "40.4 mph")
    }

    @Test("metric locales keep °C, mm, cm and km/h with local number formatting (FR-016)")
    func metricLocale() {
        #expect(Formatting.temperature(.celsius(20.46), locale: Self.germany) == "20,5 °C")
        #expect(Formatting.rainfall(.millimetres(12), locale: Self.germany) == "12 mm")
        #expect(Formatting.snow(.centimetres(20), locale: Self.germany) == "20 cm")
        #expect(Formatting.windSpeed(.kilometresPerHour(65), locale: Self.germany) == "65 km/h")
    }

    @Test("values received in US units show in metric for a metric locale (specs/006)")
    func imperialInputMetricLocale() {
        #expect(Formatting.temperature(.fahrenheit(68), locale: Self.germany) == "20 °C")
        #expect(Formatting.rainfall(.inches(0.5), locale: Self.germany) == "12,7 mm")
        #expect(Formatting.snow(.feet(1), locale: Self.germany) == "30,48 cm")
        #expect(Formatting.windSpeed(.milesPerHour(10), locale: Self.germany) == "16,1 km/h")
    }

    @Test("sunshine arrives in seconds and reads in hours")
    func sunshineHours() {
        #expect(Formatting.hours(.seconds(21_600), locale: Self.unitedStates)
                == Formatting.hours(.hours(6), locale: Self.unitedStates))
        #expect(Formatting.hours(.seconds(21_600), locale: Self.unitedStates).contains("6"))
    }

    @Test("the user's temperature setting overrides the region default")
    func temperaturePreference() {
        #expect(Formatting.temperature(.celsius(20), locale: Locale(identifier: "en_US@temperature=celsius")) == "20°C")
    }

    @Test("light rain in inches stays visible instead of rounding to 0")
    func smallPrecipitation() {
        #expect(Formatting.rainfall(.millimetres(1), locale: Self.unitedStates) == "0.04 in")
        #expect(Formatting.rainfall(.millimetres(0), locale: Self.unitedStates) == "0 in")
    }

    @Test("missing values show a dash (FR-013)")
    func missingValues() {
        #expect(Formatting.temperature(nil) == Formatting.missing)
        #expect(Formatting.rainfall(nil) == Formatting.missing)
        #expect(Formatting.snow(nil) == Formatting.missing)
        #expect(Formatting.windSpeed(nil) == Formatting.missing)
        #expect(Formatting.hours(nil) == Formatting.missing)
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
