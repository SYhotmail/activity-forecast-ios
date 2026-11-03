/// Scripted `WeatherService` for unit tests and SwiftUI previews (no network).
public struct StubWeatherService: WeatherService {
    public var search: @Sendable (String) async throws -> [Place]
    public var forecast: @Sendable (Place) async throws -> [DailyWeather]

    public init(
        search: @escaping @Sendable (String) async throws -> [Place] = { _ in [] },
        forecast: @escaping @Sendable (Place) async throws -> [DailyWeather] = { _ in [] }
    ) {
        self.search = search
        self.forecast = forecast
    }

    public func searchPlaces(matching query: String) async throws -> [Place] {
        try await search(query)
    }

    public func forecast(for place: Place) async throws -> [DailyWeather] {
        try await forecast(place)
    }
}
