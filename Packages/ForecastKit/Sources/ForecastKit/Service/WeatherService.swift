/// Data-layer boundary used by the view models.
/// Implementations throw `UserFacingError` for failures; cancellation propagates as `CancellationError`.
public protocol WeatherService: Sendable {
    /// Places matching `query` (at least 2 characters). An empty array means no matches.
    /// - Parameter language: lower-case ISO 639 code of the query's language, e.g. `be`, which
    ///   also sets the language of the results; `nil` for the service default, English
    ///   (specs/007 FR-001).
    func searchPlaces(matching query: String, language: String?) async throws -> [Place]
    /// Up to 7 local days, today first.
    func forecast(for place: Place) async throws -> [DailyWeather]
}
