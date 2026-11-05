import Foundation
import Testing
@testable import ForecastKit

/// Decoding and error mapping of `OpenMeteoClient` against recorded fixtures (contracts/open-meteo.md).
/// Serialized because `StubURLProtocol` holds a process-wide handler.
@Suite("OpenMeteoClient", .serialized)
struct OpenMeteoClientTests {
    private let client = OpenMeteoClient(session: StubURLProtocol.makeSession())

    private let chamonix = Place(id: 3025496, name: "Chamonix", region: "Auvergne-Rhône-Alpes",
                                 country: "France", latitude: 45.92, longitude: 6.87,
                                 timeZone: "Europe/Paris")

    // MARK: - Helpers

    private static func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json",
                                                 subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    private static func serve(_ name: String) throws {
        let body = try fixture(name)
        StubURLProtocol.stub { _ in .response(status: 200, body: body) }
    }

    private static func serve(json: String, status: Int = 200) {
        let body = Data(json.utf8)
        StubURLProtocol.stub { _ in .response(status: status, body: body) }
    }

    private static func queryItems(of request: URLRequest?) throws -> [String: String] {
        let url = try #require(request?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    private static func expectApproximately<U: Dimension>(_ actual: Measurement<U>?, _ expected: Measurement<U>,
                                                          sourceLocation: SourceLocation = #_sourceLocation) {
        guard let actual else {
            Issue.record("Expected \(expected), got nil", sourceLocation: sourceLocation)
            return
        }
        #expect(actual.unit == expected.unit, "unit \(actual.unit.symbol) ≠ \(expected.unit.symbol)",
                sourceLocation: sourceLocation)
        #expect(abs(actual.value - expected.value) < 0.0001, "\(actual) ≉ \(expected)",
                sourceLocation: sourceLocation)
    }

    // MARK: - Requests

    @Test("Search request hits the geocoding endpoint with a trimmed, percent-encoded name")
    func searchRequest() async throws {
        try Self.serve("geocoding-empty")

        _ = try await client.searchPlaces(matching: "  New York ")

        let request = try #require(StubURLProtocol.requests.first)
        let url = try #require(request.url)
        #expect(request.httpMethod == "GET")
        #expect(url.scheme == "https")
        #expect(url.host() == "geocoding-api.open-meteo.com")
        #expect(url.path() == "/v1/search")
        #expect(url.absoluteString.contains("name=New%20York"))
        #expect(try Self.queryItems(of: request) == [
            "name": "New York", "count": "10", "language": "en", "format": "json"
        ])
    }

    @Test("Forecast request asks for the daily and hourly variables of the contract, in metric by default")
    func forecastRequest() async throws {
        try Self.serve("forecast-chamonix")

        _ = try await client.forecast(for: chamonix)

        let request = try #require(StubURLProtocol.requests.first)
        let url = try #require(request.url)
        #expect(url.scheme == "https")
        #expect(url.host() == "api.open-meteo.com")
        #expect(url.path() == "/v1/forecast")
        #expect(try Self.queryItems(of: request) == [
            "latitude": "45.92",
            "longitude": "6.87",
            "daily": "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,rain_sum,"
                + "snowfall_sum,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,"
                + "sunshine_duration",
            "hourly": "snow_depth",
            "timezone": "auto",
            "timeformat": "unixtime",
            "forecast_days": "7",
            "temperature_unit": "celsius",
            "wind_speed_unit": "kmh",
            "precipitation_unit": "mm"
        ])
    }

    @Test("Forecast request asks for the client's units (specs/006 FR-001)", arguments: [
        (ForecastUnits.imperial, "fahrenheit", "mph", "inch"),
        (ForecastUnits(temperature: .celsius, windSpeed: .metresPerSecond, precipitation: .millimetres),
         "celsius", "ms", "mm"),
        (ForecastUnits(temperature: .celsius, windSpeed: .knots, precipitation: .inches), "celsius", "kn", "inch")
    ])
    func forecastRequestUnits(units: ForecastUnits, temperature: String, wind: String, precipitation: String)
        async throws {
        try Self.serve("forecast-chamonix-pair-imperial")
        let client = OpenMeteoClient(session: StubURLProtocol.makeSession(), units: units)

        _ = try await client.forecast(for: chamonix)

        let query = try Self.queryItems(of: StubURLProtocol.requests.first)
        #expect(query["temperature_unit"] == temperature)
        #expect(query["wind_speed_unit"] == wind)
        #expect(query["precipitation_unit"] == precipitation)
    }

    // MARK: - Geocoding decoding

    @Test("Paris decodes same-named places with region and country (FR-002)")
    func searchDecodesPlaces() async throws {
        try Self.serve("geocoding-paris")

        let places = try await client.searchPlaces(matching: "Paris")

        #expect(places.count >= 2)
        let france = try #require(places.first)
        #expect(france == Place(id: 2988507, name: "Paris", region: "Île-de-France Region",
                                country: "France", latitude: 48.85341, longitude: 2.3488,
                                timeZone: "Europe/Paris"))
        let texas = try #require(places.first { $0.id == 4717560 })
        #expect(texas.region == "Texas")
        #expect(texas.country == "United States")
        #expect(texas.timeZone == "America/Chicago")
    }

    @Test("An absent results key decodes as no places")
    func searchEmpty() async throws {
        try Self.serve("geocoding-empty")

        let places = try await client.searchPlaces(matching: "zzqxw")

        #expect(places.isEmpty)
    }

    @Test("Missing admin1 and country decode as nil")
    func searchOptionalFields() async throws {
        Self.serve(json: """
        {"results":[{"id":1,"name":"Nowhere","latitude":1.5,"longitude":-2.5,"timezone":"UTC"}]}
        """)

        let places = try await client.searchPlaces(matching: "Nowhere")

        #expect(places == [Place(id: 1, name: "Nowhere", region: nil, country: nil,
                                 latitude: 1.5, longitude: -2.5, timeZone: "UTC")])
    }

    // MARK: - Forecast decoding

    @Test("Chamonix decodes 7 local days as measurements in the response's units")
    func forecastDecodes() async throws {
        try Self.serve("forecast-chamonix")

        let days = try await client.forecast(for: chamonix)

        #expect(days.count == 7)
        #expect(days.map(\.date) == (3...9).compactMap { LocalDate(year: 2026, month: 11, day: $0) })
        let first = try #require(days.first)
        #expect(first.weatherCode == 45)
        #expect(first.temperatureMax == .celsius(8.7))
        #expect(first.temperatureMin == .celsius(-3.9))
        #expect(first.precipitation == .millimetres(0))
        #expect(first.rain == .millimetres(0))
        #expect(first.snowfall == .centimetres(0))
        #expect(first.snowDepth == .metres(0))
        #expect(first.precipitationProbability == 0)
        #expect(first.windSpeedMax == .kilometresPerHour(6.8))
        #expect(first.windGustsMax == .kilometresPerHour(13.0))
        #expect(first.sunshine == .seconds(34028.68))
        let last = try #require(days.last)
        #expect(last.weatherCode == 61)
        #expect(last.rain == .millimetres(11.3))
        #expect(last.precipitationProbability == 78)
    }

    @Test("Null values decode as nil and snow depth is the daily maximum, in the response's unit")
    func forecastNulls() async throws {
        try Self.serve("forecast-nulls")

        let days = try await client.forecast(for: chamonix)

        try #require(days.count == 3)
        let (first, second, third) = (days[0], days[1], days[2])

        #expect(first.date == LocalDate(year: 2026, month: 1, day: 10))
        Self.expectApproximately(first.snowDepth, .metres(0.55))
        Self.expectApproximately(first.sunshine, .seconds(7200))
        #expect(first.snowfall == .centimetres(4.48))
        #expect(first.precipitationProbability == 80)

        #expect(second.weatherCode == nil)
        #expect(second.temperatureMax == nil)
        #expect(second.temperatureMin == .celsius(-6.0))
        #expect(second.precipitation == nil)
        #expect(second.rain == nil)
        #expect(second.snowfall == nil)
        #expect(second.snowDepth == nil)
        #expect(second.precipitationProbability == nil)
        #expect(second.windSpeedMax == nil)
        #expect(second.windGustsMax == .kilometresPerHour(41.0))
        #expect(second.sunshine == nil)

        Self.expectApproximately(third.snowDepth, .metres(1.25))
        #expect(third.temperatureMin == nil)
        #expect(third.windGustsMax == nil)
        #expect(third.sunshine == .seconds(0))
    }

    @Test("Epoch days map to the place's calendar days across a DST change (FR-003)")
    func forecastAcrossDaylightSaving() async throws {
        // Paris local midnights of 28–30 March 2026; clocks go forward on the 29th, so the
        // response's single utc_offset_seconds (3600) is an hour short for the 30th.
        Self.serve(json: """
        {"timezone":"Europe/Paris","utc_offset_seconds":3600,
         "daily":{"time":[1774652400,1774738800,1774821600],"weather_code":[1,2,3]},
         "hourly_units":{"snow_depth":"m"},"hourly":{"time":[1774864800],"snow_depth":[0.5]}}
        """)

        let days = try await client.forecast(for: chamonix)

        #expect(days.map(\.date) == (28...30).compactMap { LocalDate(year: 2026, month: 3, day: $0) })
        #expect(days.map(\.weatherCode) == [1, 2, 3])
        #expect(days.map(\.snowDepth) == [nil, nil, .metres(0.5)])
    }

    @Test("An unknown time zone identifier falls back to utc_offset_seconds")
    func forecastOffsetFallback() async throws {
        // 2026-11-04T23:00Z is 5 November at UTC+1.
        Self.serve(json: """
        {"timezone":"Not/AZone","utc_offset_seconds":3600,
         "daily":{"time":[1793833200],"weather_code":[1]},"hourly":{"time":[],"snow_depth":[]}}
        """)

        let days = try await client.forecast(for: chamonix)

        #expect(days.map(\.date) == [LocalDate(year: 2026, month: 11, day: 5)])
    }

    @Test("A forecast with zero days is unexpected")
    func forecastZeroDays() async throws {
        Self.serve(json: """
        {"timezone":"GMT","utc_offset_seconds":0,"daily":{"time":[]},"hourly":{"time":[],"snow_depth":[]}}
        """)

        await #expect(throws: UserFacingError.unexpected) {
            try await client.forecast(for: chamonix)
        }
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
                #expect(abs(actual - expected) <= 1, "\(activity) on \(metricDay.date): \(actual) vs \(expected)")
            }
        }
    }

    @Test("A unit the app does not know is unexpected (specs/006 FR-004)", arguments: [
        #""daily_units":{"temperature_2m_max":"K"},"daily":{"time":[1793833200],"temperature_2m_max":[280]}"#,
        #""daily_units":{"wind_speed_10m_max":"bft"},"daily":{"time":[1793833200],"wind_speed_10m_max":[3]}"#,
        #""daily":{"time":[1793833200]},"hourly_units":{"snow_depth":"yd"},"hourly":{"time":[1793833200],"snow_depth":[1]}"#
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

    // MARK: - Error mapping (FR-011)

    @Test("HTTP errors map to serviceUnavailable", arguments: [400, 404, 429, 500, 503])
    func httpError(status: Int) async throws {
        Self.serve(json: #"{"error":true,"reason":"Boom"}"#, status: status)

        await #expect(throws: UserFacingError.serviceUnavailable) {
            try await client.searchPlaces(matching: "Paris")
        }
        await #expect(throws: UserFacingError.serviceUnavailable) {
            try await client.forecast(for: chamonix)
        }
    }

    @Test("Connectivity failures map to offline",
          arguments: [URLError.Code.notConnectedToInternet, .networkConnectionLost, .timedOut])
    func offline(code: URLError.Code) async throws {
        StubURLProtocol.stub { _ in .failure(URLError(code)) }

        await #expect(throws: UserFacingError.offline) {
            try await client.searchPlaces(matching: "Paris")
        }
        await #expect(throws: UserFacingError.offline) {
            try await client.forecast(for: chamonix)
        }
    }

    @Test("Malformed JSON maps to unexpected")
    func malformed() async throws {
        Self.serve(json: "{ not json")

        await #expect(throws: UserFacingError.unexpected) {
            try await client.searchPlaces(matching: "Paris")
        }
        await #expect(throws: UserFacingError.unexpected) {
            try await client.forecast(for: chamonix)
        }
    }

    @Test("A cancelled request surfaces as CancellationError, not a user-facing error")
    func cancelled() async throws {
        StubURLProtocol.stub { _ in .failure(URLError(.cancelled)) }

        await #expect(throws: CancellationError.self) {
            try await client.searchPlaces(matching: "Paris")
        }
        await #expect(throws: CancellationError.self) {
            try await client.forecast(for: chamonix)
        }
    }
}
