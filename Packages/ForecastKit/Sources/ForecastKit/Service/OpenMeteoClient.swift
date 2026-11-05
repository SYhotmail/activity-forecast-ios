import Foundation

/// `WeatherService` backed by the Open-Meteo Geocoding and Forecast APIs (contracts/open-meteo.md).
/// No API key is needed. Failures are thrown as `UserFacingError`; cancellation as `CancellationError`.
/// Copies share the rate limiters, so the app's one client keeps one budget per API.
public struct OpenMeteoClient: WeatherService {
    private let session: URLSession
    private let units: ForecastUnits
    private let geocodingLimiter: RateLimiter
    private let forecastLimiter: RateLimiter

    /// Open-Meteo's free-tier minutely limit, applied to each API separately (specs/008 FR-001,
    /// research R1). The hourly and daily limits are left to the service's 429, after which the
    /// API cools down until the reset (FR-007).
    static let rateLimit = (requests: 600, per: Duration.seconds(60))

    /// - Parameter units: what the forecast is requested in. Values are decoded in the units the
    ///   response states, whatever was asked (specs/006 FR-001, FR-004).
    public init(session: URLSession = .shared, units: ForecastUnits = .metric) {
        self.init(session: session, units: units, rateLimit: Self.rateLimit)
    }

    init(session: URLSession, units: ForecastUnits = .metric, rateLimit: (requests: Int, per: Duration)) {
        self.session = session
        self.units = units
        geocodingLimiter = RateLimiter(limit: rateLimit.requests, per: rateLimit.per)
        forecastLimiter = RateLimiter(limit: rateLimit.requests, per: rateLimit.per)
    }

    /// A search the service rejects with 400 while sending a language is retried once without
    /// it, so a code it does not accept degrades to an English search (specs/008 FR-006).
    public func searchPlaces(matching query: String, language: String?) async throws -> [Place] {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = Self.searchRequest(name: name, language: language)
        let withoutLanguage = Self.languageCode(language) == nil ? nil : Self.searchRequest(name: name, language: nil)
        let response: GeocodingResponseDTO = try await fetch(
            request, limiter: geocodingLimiter, onBadRequest: withoutLanguage)
        return response.places
    }

    public func forecast(for place: Place) async throws -> [DailyWeather] {
        let request = Self.forecastRequest(latitude: place.latitude, longitude: place.longitude, units: units)
        let response: ForecastResponseDTO = try await fetch(request, limiter: forecastLimiter)
        return try response.dailyWeather()
    }

    // MARK: - Requests

    static let dailyVariables = [
        "weather_code", "temperature_2m_max", "temperature_2m_min",
        "precipitation_sum", "rain_sum", "snowfall_sum", "precipitation_probability_max",
        "wind_speed_10m_max", "wind_gusts_10m_max", "sunshine_duration"
    ].joined(separator: ",")

    /// `language` decides which names the query is matched against, not only the language of
    /// the results: "Мінск" finds Minsk with `be` and nothing with `en` (specs/007). Only a valid
    /// code other than `en`, the API default, is sent (`languageCode(_:)`).
    static func searchRequest(name: String, language: String?) -> URLRequest {
        let languageParameter = languageCode(language).map { ("language", $0) }
        return request(host: "geocoding-api.open-meteo.com", path: "/v1/search", query: [
            ("name", name), ("count", "10"), ("format", "json")
        ] + [languageParameter].compactMap { $0 })
    }

    /// The ISO 639 code to send for `language`, or `nil` to leave the parameter out (specs/008
    /// FR-005): the lower-cased primary subtag (`be-BY`, `BE`, `be_BY` → `be`) when it is a known
    /// ISO 639 code and not `en`. The service accepts any value and matches unknown ones (`xx`)
    /// like English, so they are dropped here rather than sent (research R2).
    static func languageCode(_ language: String?) -> String? {
        guard let primary = language?
            .split(omittingEmptySubsequences: false, whereSeparator: { $0 == "-" || $0 == "_" })
            .first?.lowercased(),
              primary != "en", isoLanguageCodes.contains(primary)
        else { return nil }
        return primary
    }

    /// Lower-case ISO 639 codes Foundation knows (`be`, `yue`, …).
    private static let isoLanguageCodes = Set(Locale.LanguageCode.isoLanguageCodes.map(\.identifier))

    static func forecastRequest(latitude: Double, longitude: Double, units: ForecastUnits) -> URLRequest {
        request(host: "api.open-meteo.com", path: "/v1/forecast", query: [
            ("latitude", String(latitude)),
            ("longitude", String(longitude)),
            ("daily", dailyVariables),
            ("hourly", "snow_depth"),
            // Not defaults, so always sent: `timezone` defaults to GMT, which would cut days and
            // daily maxima at UTC midnight; `auto` uses the place's zone (FR-003). `timeformat`
            // defaults to ISO 8601 strings; Unix seconds are dated with that zone, DST-safe.
            ("timezone", "auto"),
            ("timeformat", "unixtime")
            // `forecast_days` is left out: the default is 7, today + 6 (FR-003, verified live).
        ] + unitParameters(units))
    }

    /// Only the unit parameters that differ from Open-Meteo's defaults (specs/006 FR-001).
    /// A default unit is left out instead of sent, so a metric request stays the plain contract URL:
    /// - `temperature_unit` defaults to `celsius`;
    /// - `wind_speed_unit` defaults to `kmh`;
    /// - `precipitation_unit` defaults to `mm` (snowfall then in cm, snow depth in m).
    /// The response states its units either way, and decoding reads those (FR-004).
    static func unitParameters(_ units: ForecastUnits) -> [(String, String)] {
        let defaults = ForecastUnits.metric
        var parameters: [(String, String)] = []
        if units.temperature != defaults.temperature {
            parameters.append(("temperature_unit", units.temperature.rawValue))
        }
        if units.windSpeed != defaults.windSpeed {
            parameters.append(("wind_speed_unit", units.windSpeed.rawValue))
        }
        if units.precipitation != defaults.precipitation {
            parameters.append(("precipitation_unit", units.precipitation.rawValue))
        }
        return parameters
    }

    private static func request(host: String, path: String, query: [(String, String)]) -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        // Built from constant parts, so a URL always results.
        var request = URLRequest(url: components.url!)
        assert(request.httpMethod == "GET")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    // MARK: - Transport and error mapping

    /// Sends `request` once `limiter` has a slot. On HTTP 400, sends `fallback` instead when given.
    /// During a cooldown after a 429 nothing is sent (specs/008 FR-008).
    private func fetch<Response: Decodable>(_ request: URLRequest, limiter: RateLimiter,
                                            onBadRequest fallback: URLRequest? = nil) async throws -> Response {
        if let end = await limiter.cooldownEnd(at: .now) {
            throw UserFacingError.rateLimited(until: end)
        }
        let data: Data
        let response: URLResponse
        do {
            try await limiter.acquire()
            (data, response) = try await session.data(for: request)
        } catch {
            throw Self.map(error)
        }
        guard let http = response as? HTTPURLResponse else { throw UserFacingError.unexpected }
        if http.statusCode == 400, let fallback {
            return try await fetch(fallback, limiter: limiter)
        }
        if http.statusCode == 429 {
            let end = Self.retryDate(from: http, now: .now)
            await limiter.coolDown(until: end)
            throw UserFacingError.rateLimited(until: end)
        }
        guard (200..<300).contains(http.statusCode) else { throw UserFacingError.serviceUnavailable }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw UserFacingError.unexpected
        }
    }

    /// Cooldown when a 429 states no reset: the shortest of the service's windows (specs/008 R3).
    static let defaultCooldown: TimeInterval = 60

    /// When requests may start again after a 429 (specs/008 FR-007): `Retry-After` in seconds,
    /// else `X-RateLimit-Reset` (Unix seconds) when it is later than `now`, else `defaultCooldown`.
    static func retryDate(from response: HTTPURLResponse, now: Date) -> Date {
        if let seconds = response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init),
           seconds >= 0 {
            return now.addingTimeInterval(seconds)
        }
        if let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(TimeInterval.init),
           Date(timeIntervalSince1970: reset) > now {
            return Date(timeIntervalSince1970: reset)
        }
        return now.addingTimeInterval(defaultCooldown)
    }

    /// Transport errors → `UserFacingError`, except cancellation which stays `CancellationError`.
    static func map(_ error: any Error) -> any Error {
        if error is CancellationError { return error }
        guard let urlError = error as? URLError else { return UserFacingError.unexpected }
        switch urlError.code {
        case .cancelled:
            return CancellationError()
        case .notConnectedToInternet, .networkConnectionLost, .timedOut,
             .dataNotAllowed, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
             .internationalRoamingOff:
            return UserFacingError.offline
        default:
            return UserFacingError.serviceUnavailable
        }
    }
}
