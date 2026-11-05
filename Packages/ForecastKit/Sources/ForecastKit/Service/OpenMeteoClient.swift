import Foundation

/// `WeatherService` backed by the Open-Meteo Geocoding and Forecast APIs (contracts/open-meteo.md).
/// No API key is needed. Failures are thrown as `UserFacingError`; cancellation as `CancellationError`.
public struct OpenMeteoClient: WeatherService {
    private let session: URLSession
    private let units: ForecastUnits

    /// - Parameter units: what the forecast is requested in. Values are decoded in the units the
    ///   response states, whatever was asked (specs/006 FR-001, FR-004).
    public init(session: URLSession = .shared, units: ForecastUnits = .metric) {
        self.session = session
        self.units = units
    }

    public func searchPlaces(matching query: String, language: String?) async throws -> [Place] {
        let request = Self.searchRequest(
            name: query.trimmingCharacters(in: .whitespacesAndNewlines), language: language)
        let response: GeocodingResponseDTO = try await fetch(request)
        return response.places
    }

    public func forecast(for place: Place) async throws -> [DailyWeather] {
        let request = Self.forecastRequest(latitude: place.latitude, longitude: place.longitude, units: units)
        let response: ForecastResponseDTO = try await fetch(request)
        return try response.dailyWeather()
    }

    // MARK: - Requests

    static let dailyVariables = [
        "weather_code", "temperature_2m_max", "temperature_2m_min",
        "precipitation_sum", "rain_sum", "snowfall_sum", "precipitation_probability_max",
        "wind_speed_10m_max", "wind_gusts_10m_max", "sunshine_duration"
    ].joined(separator: ",")

    /// `language` decides which names the query is matched against, not only the language of
    /// the results: "Мінск" finds Minsk with `be` and nothing with `en` (specs/007). It is left
    /// out when absent or `en`, the API default.
    static func searchRequest(name: String, language: String?) -> URLRequest {
        let languageParameter = language.flatMap { $0 == "en" ? nil : ("language", $0) }
        return request(host: "geocoding-api.open-meteo.com", path: "/v1/search", query: [
            ("name", name), ("count", "10"), ("format", "json")
        ] + [languageParameter].compactMap { $0 })
    }

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

    private func fetch<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Self.map(error)
        }
        guard let http = response as? HTTPURLResponse else { throw UserFacingError.unexpected }
        guard (200..<300).contains(http.statusCode) else { throw UserFacingError.serviceUnavailable }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw UserFacingError.unexpected
        }
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
