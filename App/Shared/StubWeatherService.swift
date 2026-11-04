#if DEBUG
import ForecastKit

/// Scripted `WeatherService` for unit tests and SwiftUI previews (no network).
/// Compiled only in Debug, so it never ships in the release app (constitution Principle V).
/// Shared by SwiftUI previews and by `ActivityForecastTests` through `@testable import`.
struct StubWeatherService: WeatherService {
    var search: @Sendable (String) async throws -> [Place]
    var forecast: @Sendable (Place) async throws -> [DailyWeather]

    init(
        search: @escaping @Sendable (String) async throws -> [Place] = { _ in [] },
        forecast: @escaping @Sendable (Place) async throws -> [DailyWeather] = { _ in [] }
    ) {
        self.search = search
        self.forecast = forecast
    }

    func searchPlaces(matching query: String) async throws -> [Place] {
        try await search(query)
    }

    func forecast(for place: Place) async throws -> [DailyWeather] {
        try await forecast(place)
    }
}
#endif
