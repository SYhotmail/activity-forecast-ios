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

    private static func expectApproximately(_ actual: Double?, _ expected: Double,
                                            sourceLocation: SourceLocation = #_sourceLocation) {
        guard let actual else {
            Issue.record("Expected \(expected), got nil", sourceLocation: sourceLocation)
            return
        }
        #expect(abs(actual - expected) < 0.0001, "\(actual) ≉ \(expected)", sourceLocation: sourceLocation)
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

    @Test("Forecast request asks for the daily and hourly variables of the contract")
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
            "forecast_days": "7"
        ])
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
        #expect(texas.displayName == "Paris, Texas, United States")
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

    @Test("Chamonix decodes 7 local days with unit conversions")
    func forecastDecodes() async throws {
        try Self.serve("forecast-chamonix")

        let days = try await client.forecast(for: chamonix)

        #expect(days.count == 7)
        #expect(days.map(\.date) == (3...9).map { LocalDate(year: 2026, month: 11, day: $0)! })
        let first = try #require(days.first)
        #expect(first.weatherCode == 45)
        #expect(first.temperatureMax == 8.7)
        #expect(first.temperatureMin == -3.9)
        #expect(first.precipitation == 0)
        #expect(first.rain == 0)
        #expect(first.snowfall == 0)
        #expect(first.snowDepth == 0)
        #expect(first.precipitationProbability == 0)
        #expect(first.windSpeedMax == 6.8)
        #expect(first.windGustsMax == 13.0)
        Self.expectApproximately(first.sunshine, 34028.68 / 3600)
        let last = try #require(days.last)
        #expect(last.weatherCode == 61)
        #expect(last.rain == 11.3)
        #expect(last.precipitationProbability == 78)
    }

    @Test("Null values decode as nil and snow depth is the daily maximum in cm")
    func forecastNulls() async throws {
        try Self.serve("forecast-nulls")

        let days = try await client.forecast(for: chamonix)

        try #require(days.count == 3)
        let (first, second, third) = (days[0], days[1], days[2])

        #expect(first.date == LocalDate(year: 2026, month: 1, day: 10))
        Self.expectApproximately(first.snowDepth, 55)
        Self.expectApproximately(first.sunshine, 2)
        #expect(first.snowfall == 4.48)
        #expect(first.precipitationProbability == 80)

        #expect(second.weatherCode == nil)
        #expect(second.temperatureMax == nil)
        #expect(second.temperatureMin == -6.0)
        #expect(second.precipitation == nil)
        #expect(second.rain == nil)
        #expect(second.snowfall == nil)
        #expect(second.snowDepth == nil)
        #expect(second.precipitationProbability == nil)
        #expect(second.windSpeedMax == nil)
        #expect(second.windGustsMax == 41.0)
        #expect(second.sunshine == nil)

        Self.expectApproximately(third.snowDepth, 125)
        #expect(third.temperatureMin == nil)
        #expect(third.windGustsMax == nil)
        #expect(third.sunshine == 0)
    }

    @Test("Days with an unparsable date are dropped")
    func forecastDropsBadDates() async throws {
        Self.serve(json: """
        {"daily":{"time":["2026-11-03","not-a-date"],"weather_code":[1,2]},
         "hourly":{"time":[],"snow_depth":[]}}
        """)

        let days = try await client.forecast(for: chamonix)

        #expect(days.map(\.date) == [LocalDate(year: 2026, month: 11, day: 3)!])
        #expect(days.first?.weatherCode == 1)
        #expect(days.first?.snowDepth == nil)
    }

    @Test("A forecast with zero days is unexpected")
    func forecastZeroDays() async throws {
        Self.serve(json: #"{"daily":{"time":[]},"hourly":{"time":[],"snow_depth":[]}}"#)

        await #expect(throws: UserFacingError.unexpected) {
            try await client.forecast(for: chamonix)
        }
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
