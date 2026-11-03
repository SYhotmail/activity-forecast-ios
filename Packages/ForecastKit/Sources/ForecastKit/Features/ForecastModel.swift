import Observation

/// Screen model for one place's ranked week (contracts/ui.md › Forecast).
///
/// The view calls `load()` from `.task`, so leaving the screen cancels the request.
@MainActor
@Observable
public final class ForecastModel {
    public let place: Place
    /// Starts as `.loading`: the screen begins fetching as soon as it appears.
    public private(set) var state: LoadState<WeeklyRanking> = .loading

    private let service: any WeatherService

    public init(place: Place, service: any WeatherService) {
        self.place = place
        self.service = service
    }

    /// Fetches the forecast and ranks the activities for the week.
    public func load() async {
        state = .loading
        do {
            let days = try await service.forecast(for: place)
            state = .loaded(WeeklyRanker.rank(days, for: place))
        } catch {
            state = .failed(.unexpected)
        }
    }
}
