import Testing
@testable import ForecastKit

// MARK: - Reasons (FR-008, research.md R9 › Reasons)

/// Rule: a cap reason first; then the biggest negative contributor (weight × (1 − value)) among
/// factors below 0.4; then the biggest positive contributor (weight × value) among factors at or
/// above 0.8; at most two. If none qualifies, the biggest negative contributor is shown so that
/// every scored day has at least one reason (FR-008).
extension ActivityScorerTests {
    private func reasons(_ activity: Activity, _ weather: DailyWeather) -> [Reason] {
        if case let .scored(_, _, reasons) = ActivityScorer.suitability(for: activity, on: weather).result {
            return reasons
        }
        Issue.record("expected a scored day")
        return []
    }

    @Test("US2 scenario 2: a Poor outdoor day caused by heavy rain gives a reason that mentions rain")
    func heavyRainOutdoorReason() {
        let rainy = DailyWeather(
            date: Self.date, weatherCode: 63, temperatureMax: 3, temperatureMin: 1,
            precipitation: 12, rain: 12, snowfall: 0, snowDepth: 0,
            precipitationProbability: 90, windSpeedMax: 20, windGustsMax: 35, sunshine: 0)
        let day = ActivityScorer.suitability(for: .outdoorSightseeing, on: rainy)
        guard case let .scored(_, label, reasons) = day.result else {
            Issue.record("expected a scored day")
            return
        }
        #expect(label == .poor)
        #expect(reasons.first == Reason(kind: .negative, text: "Heavy rain 12 mm"))
        #expect(reasons.first?.text.localizedCaseInsensitiveContains("rain") == true)
    }

    @Test("a perfect day shows its biggest positive contributor, earliest factor on a tie")
    func perfectDayPositives() {
        #expect(reasons(.skiing, Self.perfectSkiing) == [Reason(kind: .positive, text: "Fresh snow 20 cm")])
        #expect(reasons(.surfing, Self.perfectSurfing) == [Reason(kind: .positive, text: "Good breeze 25 km/h")])
        #expect(reasons(.outdoorSightseeing, Self.perfectOutdoor)
                == [Reason(kind: .positive, text: "Comfortable 20 °C")])
    }

    @Test("a factor at 0.5 is not called out as negative; the same factor at 0 is, before the positive")
    func negativeThreshold() {
        // Wind 42.5 km/h → surfing wind factor 0.5: no negative reason.
        let gusty = with(Self.perfectSurfing) { $0.windSpeedMax = 42.5 }
        #expect(reasons(.surfing, gusty) == [Reason(kind: .positive, text: "Warm 22 °C")])
        // Wind 50 km/h → factor 0: negative first, then the biggest positive.
        let stormy = with(Self.perfectSurfing) { $0.windSpeedMax = 50 }
        #expect(reasons(.surfing, stormy) == [
            Reason(kind: .negative, text: "Too windy 50 km/h"),
            Reason(kind: .positive, text: "Warm 22 °C")
        ])
    }

    @Test("skiing: strong gusts are explained with their speed")
    func skiingGustsReason() {
        let windy = with(Self.perfectSkiing) { $0.windGustsMax = 65 }
        #expect(reasons(.skiing, windy) == [
            Reason(kind: .negative, text: "Strong gusts 65 km/h"),
            Reason(kind: .positive, text: "Fresh snow 20 cm")
        ])
    }

    @Test("a cap reason comes first and the list never exceeds two")
    func capFirst() {
        let storm = with(Self.perfectOutdoor) { $0.weatherCode = 95; $0.precipitation = 12 }
        #expect(reasons(.outdoorSightseeing, storm) == [
            Reason(kind: .cap, text: "Thunderstorms expected"),
            Reason(kind: .negative, text: "Heavy rain 12 mm")
        ])
        let thaw = with(Self.perfectSkiing) {
            $0.snowfall = 0; $0.snowDepth = 0; $0.temperatureMin = 4; $0.temperatureMax = 9
        }
        #expect(reasons(.skiing, thaw).first == Reason(kind: .cap, text: "No snow on the ground"))
        #expect(reasons(.skiing, thaw).count <= 2)
    }

    @Test("a middling day with no factor past either threshold still gets one reason (FR-008)")
    func middlingDayFallback() {
        // comfort 0.67, dry 0.6, calm 0.5, sun 0.5: biggest loss is dry (35 × 0.4 = 14).
        let middling = DailyWeather(
            date: Self.date, weatherCode: 2, temperatureMax: 10, temperatureMin: 5,
            precipitation: 4, rain: 4, snowfall: 0, snowDepth: 0,
            precipitationProbability: 0, windSpeedMax: 35, windGustsMax: 50, sunshine: 4)
        #expect(reasons(.outdoorSightseeing, middling) == [Reason(kind: .negative, text: "Rain 4 mm")])
    }

    @Test("indoor sightseeing is explained by the weather outside")
    func indoorReasons() {
        let rainy = with(Self.perfectOutdoor) { $0.precipitation = 12; $0.temperatureMax = 3; $0.sunshine = 0 }
        #expect(reasons(.indoorSightseeing, rainy) == [
            Reason(kind: .positive, text: "Poor weather outside — good day for museums")
        ])
        #expect(reasons(.indoorSightseeing, Self.perfectOutdoor) == [
            Reason(kind: .negative, text: "Great weather outside — better spent outdoors")
        ])
    }

    @Test("every scored day has one or two reasons, for every activity", arguments: Activity.allCases)
    func oneOrTwoReasons(activity: Activity) {
        let days = [Self.perfectSkiing, Self.perfectSurfing, Self.perfectOutdoor,
                    with(Self.perfectOutdoor) { $0.weatherCode = 95; $0.windSpeedMax = 60; $0.precipitation = 20 }]
        for day in days {
            #expect((1...2).contains(reasons(activity, day).count))
        }
    }

    @Test("decimal values keep one decimal place, whole values none")
    func valueFormatting() {
        let drizzle = with(Self.perfectOutdoor) { $0.precipitation = 7.5; $0.rain = 7.5 }
        #expect(reasons(.outdoorSightseeing, drizzle).first == Reason(kind: .negative, text: "Rain 7.5 mm"))
    }
}
