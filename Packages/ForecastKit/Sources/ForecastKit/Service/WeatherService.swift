/// Data-layer boundary used by the view models.
/// Implementations throw `UserFacingError` for failures; cancellation propagates as `CancellationError`.
public protocol WeatherService: Sendable {
    /// Places matching `query` (at least 2 characters). An empty array means no matches.
    func searchPlaces(matching query: String) async throws -> [Place]
    /// Up to 7 local days, today first.
    func forecast(for place: Place) async throws -> [DailyWeather]
}
