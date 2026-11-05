import Foundation
import Testing
@testable import ForecastKit

/// Units of the forecast request and response (specs/006). An extension of the serialized
/// `OpenMeteoClientTests` suite, because `StubURLProtocol` holds a process-wide handler.
extension OpenMeteoClientTests {
    /// The unit parameters a request should carry; `nil` means left out (the API default).
    struct ExpectedUnitQuery: Sendable {
        let units: ForecastUnits
        let temperature: String?
        let wind: String?
        let precipitation: String?
    }

    @Test("Forecast request sends only the units that differ from Open-Meteo's defaults (specs/006 FR-001)",
          arguments: [
              ExpectedUnitQuery(units: .imperial, temperature: "fahrenheit", wind: "mph", precipitation: "inch"),
              ExpectedUnitQuery(units: ForecastUnits(temperature: .celsius, windSpeed: .metresPerSecond,
                                                     precipitation: .millimetres),
                                temperature: nil, wind: "ms", precipitation: nil),
              ExpectedUnitQuery(units: ForecastUnits(temperature: .celsius, windSpeed: .knots, precipitation: .inches),
                                temperature: nil, wind: "kn", precipitation: "inch"),
              ExpectedUnitQuery(units: .metric, temperature: nil, wind: nil, precipitation: nil)
          ])
    func forecastRequestUnits(expected: ExpectedUnitQuery) async throws {
        try Self.serve("forecast-chamonix-pair-imperial")
        let client = OpenMeteoClient(session: StubURLProtocol.makeSession(), units: expected.units)

        _ = try await client.forecast(for: chamonix)

        let query = try Self.queryItems(of: StubURLProtocol.requests.first)
        #expect(query["temperature_unit"] == expected.temperature)
        #expect(query["wind_speed_unit"] == expected.wind)
        #expect(query["precipitation_unit"] == expected.precipitation)
    }

    @Test("An imperial response decodes as °F, inches, feet and mph (specs/006 FR-004)")
    func forecastDecodesImperial() async throws {
        try Self.serve("forecast-chamonix-pair-imperial")

        let days = try await client.forecast(for: chamonix)

        let first = try #require(days.first)
        #expect(first.date == LocalDate(year: 2026, month: 11, day: 5))
        #expect(first.temperatureMax == .fahrenheit(56.0))
        #expect(first.temperatureMin == .fahrenheit(44.7))
        #expect(first.precipitation == .inches(0.008))
        #expect(first.snowfall == .inches(0))
        #expect(first.snowDepth?.unit == .feet)
        #expect(first.windSpeedMax == .milesPerHour(12.8))
        #expect(first.windGustsMax == .milesPerHour(24.4))
        #expect(first.sunshine == .seconds(34405.35))
    }

    @Test("Metric and imperial responses recorded together score alike (specs/006 SC-002)")
    func imperialScoresLikeMetric() async throws {
        try Self.serve("forecast-chamonix-pair-metric")
        let metric = try await client.forecast(for: chamonix)
        try Self.serve("forecast-chamonix-pair-imperial")
        let imperial = try await client.forecast(for: chamonix)

        try #require(metric.count == 7 && imperial.count == 7)
        for (metricDay, imperialDay) in zip(metric, imperial) {
            for activity in Activity.allCases {
                let expected = try #require(ActivityScorer.suitability(for: activity, on: metricDay).score)
                let actual = try #require(ActivityScorer.suitability(for: activity, on: imperialDay).score)
                // Open-Meteo rounds each unit system separately, so allow one point.
                #expect(abs(actual - expected) <= 1,
                        "\(activity) on \(metricDay.date): \(actual) vs \(expected)")
            }
        }
    }

    @Test("A unit the app does not know is unexpected (specs/006 FR-004)", arguments: [
        #""daily_units":{"temperature_2m_max":"K"},"daily":{"time":[1793833200],"temperature_2m_max":[280]}"#,
        #""daily_units":{"wind_speed_10m_max":"bft"},"daily":{"time":[1793833200],"wind_speed_10m_max":[3]}"#,
        #""daily":{"time":[1793833200]},"hourly_units":{"snow_depth":"yd"},"#
            + #""hourly":{"time":[1793833200],"snow_depth":[1]}"#
    ])
    func forecastUnknownUnit(body: String) async throws {
        Self.serve(json: #"{"timezone":"Europe/Paris","utc_offset_seconds":3600,"# + body + "}")

        await #expect(throws: UserFacingError.unexpected) {
            try await client.forecast(for: chamonix)
        }
    }

    @Test("A series without its unit is unexpected; an absent series needs none")
    func forecastMissingUnit() async throws {
        Self.serve(json: """
        {"timezone":"Europe/Paris","utc_offset_seconds":3600,
         "daily":{"time":[1793833200],"temperature_2m_max":[12.0]}}
        """)
        await #expect(throws: UserFacingError.unexpected) {
            try await client.forecast(for: chamonix)
        }

        Self.serve(json: """
        {"timezone":"Europe/Paris","utc_offset_seconds":3600,"daily":{"time":[1793833200],"weather_code":[3]}}
        """)
        let days = try await client.forecast(for: chamonix)
        #expect(days.map(\.weatherCode) == [3])
    }
}
