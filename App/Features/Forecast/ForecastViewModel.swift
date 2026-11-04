import ForecastKit
import Observation

/// View model for one place's ranked week (contracts/ui.md › Forecast).
///
/// The view calls `load()` from `.task`, so leaving the screen cancels the request; a
/// cancelled load never changes the state.
@Observable
final class ForecastViewModel {
    let place: Place
    /// Starts as `.loading`: the screen begins fetching as soon as it appears.
    private(set) var state: LoadState<WeeklyRanking> = .loading
    /// The day whose detail sheet is open; `nil` when closed. Kept here rather than in the view
    /// so a fold or window resize that rebuilds the column keeps the sheet open (specs/003 US3).
    var selectedDay: DaySuitability?

    private let service: any WeatherService

    init(place: Place, service: any WeatherService) {
        self.place = place
        self.service = service
    }

    /// Fetches the forecast and ranks the activities for the week.
    /// A forecast with no days cannot be ranked, so it is shown as a retryable failure.
    func load() async {
        state = .loading
        let outcome: LoadState<WeeklyRanking>
        do {
            let days = try await service.forecast(for: place)
            outcome = days.isEmpty ? .failed(.unexpected) : .loaded(WeeklyRanker.rank(days, for: place))
        } catch is CancellationError {
            return
        } catch let error as UserFacingError {
            outcome = .failed(error)
        } catch {
            outcome = .failed(.unexpected)
        }
        guard !Task.isCancelled else { return }
        state = outcome
    }

    /// Loads unless the week is already loaded. Views call this from `.task`, which reruns when
    /// a fold or resize rebuilds them, so a loaded week is never fetched again (specs/003 FR-007,
    /// research.md R3). A load cancelled mid-flight leaves `.loading`, so the next call retries.
    func loadIfNeeded() async {
        if case .loaded = state { return }
        await load()
    }

    /// Loads again after a failure (FR-011).
    func retry() async {
        await load()
    }
}
