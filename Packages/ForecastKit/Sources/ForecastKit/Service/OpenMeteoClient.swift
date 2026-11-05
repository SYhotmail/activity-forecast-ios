import Foundation

/// `WeatherService` backed by the Open-Meteo Geocoding and Forecast APIs (contracts/open-meteo.md).
/// No API key is needed. Failures are thrown as `UserFacingError`; cancellation as `CancellationError`.
public struct OpenMeteoClient: WeatherService {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func searchPlaces(matching query: String) async throws -> [Place] {
        let request = Self.searchRequest(
            name: query.trimmingCharacters(in: .whitespacesAndNewlines))
        let response: GeocodingResponseDTO = try await fetch(request)
        return response.places
    }

    public func forecast(for place: Place) async throws -> [DailyWeather] {
        let request = Self.forecastRequest(latitude: place.latitude, longitude: place.longitude)
        let response: ForecastResponseDTO = try await fetch(request)
        return try response.dailyWeather()
    }

    // MARK: - Requests

    static let dailyVariables = [
        "weather_code", "temperature_2m_max", "temperature_2m_min",
        "precipitation_sum", "rain_sum", "snowfall_sum", "precipitation_probability_max",
        "wind_speed_10m_max", "wind_gusts_10m_max", "sunshine_duration"
    ].joined(separator: ",")

    static func searchRequest(name: String) -> URLRequest {
        request(host: "geocoding-api.open-meteo.com", path: "/v1/search", query: [
            ("name", name), ("count", "10"), ("language", "en"), ("format", "json")
        ])
    }

    static func forecastRequest(latitude: Double, longitude: Double) -> URLRequest {
        request(host: "api.open-meteo.com", path: "/v1/forecast", query: [
            ("latitude", String(latitude)),
            ("longitude", String(longitude)),
            ("daily", dailyVariables),
            ("hourly", "snow_depth"),
            ("timezone", "auto"),
            ("timeformat", "unixtime"),
            ("forecast_days", "7")
        ])
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
