import ForecastKit

/// Scripted `WeatherService` for unit tests and SwiftUI previews (no network).
/// A preview and test fixture, shared by SwiftUI previews and by `ActivityForecastTests` through
/// `@testable import`. It compiles into Release because `#Preview` bodies do, but production code
/// MUST never use it: only `ActivityForecastApp` chooses the service, and it uses `OpenMeteoClient`
/// (constitution Principle V).
nonisolated struct StubWeatherService: WeatherService {
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
