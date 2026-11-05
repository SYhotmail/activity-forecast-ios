import Foundation
import Testing
@testable import ForecastKit

/// Language codes, the service's rate limit and on-device limiting (specs/008). An extension of
/// the serialized `OpenMeteoClientTests` suite, because `StubURLProtocol` holds a process-wide handler.
extension OpenMeteoClientTests {
    // MARK: - Language codes (specs/008 FR-005, FR-006)

    @Test("A region form or upper case is sent as its ISO 639 code (specs/008 FR-005)",
          arguments: [("be-BY", "be"), ("BE", "be"), ("be_BY", "be"), ("zh-Hans-CN", "zh"), ("yue", "yue"),
                      ("EN-gb", nil)] as [(String, String?)])
    func searchRequestNormalisesLanguage(language: String, expected: String?) async throws {
        try Self.serve("geocoding-empty")

        _ = try await client.searchPlaces(matching: "Мінск", language: language)

        #expect(try Self.queryItems(of: StubURLProtocol.requests.first)["language"] == expected)
    }

    @Test("A value that is not a known ISO 639 code is not sent (specs/008 FR-005)",
          arguments: ["", "klingon", "1", "b", "be by", "бе", "-BY", "xx", "qq-QQ", "zzz"])
    func searchRequestDropsBadLanguage(language: String) async throws {
        try Self.serve("geocoding-empty")

        _ = try await client.searchPlaces(matching: "Мінск", language: language)

        #expect(try Self.queryItems(of: StubURLProtocol.requests.first)["language"] == nil)
    }

    @Test("A search rejected with 400 for its language is retried once without it (specs/008 FR-006)")
    func searchRetriesWithoutLanguage() async throws {
        let places = try Self.fixture("geocoding-paris")
        StubURLProtocol.stub { request in
            let hasLanguage = request.url?.query?.contains("language=") ?? false
            return hasLanguage
                ? .response(status: 400, body: Data(#"{"error":true,"reason":"Invalid language"}"#.utf8))
                : .response(status: 200, body: places)
        }

        let result = try await client.searchPlaces(matching: "Paris", language: "fr")

        #expect(!result.isEmpty)
        #expect(StubURLProtocol.requests.count == 2)
        #expect(try Self.queryItems(of: StubURLProtocol.requests.last)["language"] == nil)
    }

    @Test("A 400 without a language is not retried")
    func searchBadRequestWithoutLanguage() async throws {
        Self.serve(json: #"{"error":true,"reason":"Boom"}"#, status: 400)

        await #expect(throws: UserFacingError.serviceUnavailable) {
            try await client.searchPlaces(matching: "Paris", language: nil)
        }
        #expect(StubURLProtocol.requests.count == 1)
    }

    @Test("HTTP 429 maps to rateLimited (specs/008 FR-003)")
    func tooManyRequests() async throws {
        Self.serve(json: #"{"error":true,"reason":"Minutely API request limit exceeded."}"#, status: 429)

        await #expect(throws: UserFacingError.rateLimited) {
            try await client.searchPlaces(matching: "Paris", language: "fr")
        }
        await #expect(throws: UserFacingError.rateLimited) {
            try await client.forecast(for: chamonix)
        }
    }

    // MARK: - Rate limiting (specs/008 FR-001, FR-002)

    @Test("Each API has its own limit; a request over it waits without being sent")
    func rateLimitedPerAPI() async throws {
        try Self.serve("geocoding-empty")
        let client = OpenMeteoClient(session: StubURLProtocol.makeSession(),
                                     rateLimit: (requests: 1, per: .seconds(60)))
        _ = try await client.searchPlaces(matching: "Paris", language: nil)

        let waiting = Task { try await client.searchPlaces(matching: "Lyon", language: nil) }
        try await Task.sleep(for: .milliseconds(200))
        #expect(StubURLProtocol.requests.count == 1)

        _ = try? await client.forecast(for: chamonix)
        #expect(StubURLProtocol.requests.count == 2, "the forecast limit is separate")

        waiting.cancel()
        await #expect(throws: CancellationError.self) { try await waiting.value }
        #expect(StubURLProtocol.requests.count == 2)
    }
}
