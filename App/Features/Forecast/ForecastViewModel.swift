import ForecastKit
import Observation

/// View model for one place's ranked week (contracts/ui.md › Forecast).
///
/// The view calls `loadIfNeeded()` from `.task`. The model owns the request: deselecting the
/// place cancels it (`cancel()`), and a cancelled request never changes the state.
@Observable
final class ForecastViewModel {
    let place: Place
    /// Starts as `.loading`: the screen begins fetching as soon as it appears.
    private(set) var state: LoadState<WeeklyRanking> = .loading
    /// The day whose detail sheet is open; `nil` when closed. Kept here rather than in the view
    /// so a fold or window resize that rebuilds the column keeps the sheet open (specs/003 US3).
    /// The sheet binds to it directly and clears it on dismiss (specs/005 FR-006).
    var presentedDay: PresentedDay?

    private let service: any WeatherService
    /// The fetch in flight, if any (see `load()`).
    private var loadTask: Task<Void, Never>?

    init(place: Place, service: any WeatherService) {
        self.place = place
        self.service = service
    }

    /// Opens the detail sheet for `day`, replacing any day already shown.
    func showDetail(for day: DaySuitability) {
        presentedDay = PresentedDay(day: day)
    }

    /// Fetches the forecast and ranks the activities for the week, superseding any fetch already
    /// running. A forecast with no days cannot be ranked, so it is shown as a retryable failure.
    ///
    /// The fetch runs in a task this model owns, and the caller only waits for it. SwiftUI can
    /// cancel a view's `.task` with a stray disappear while the screen stays visible, so a fetch
    /// tied to it could stop with nothing left to restart it (specs/005 FR-012). Only `cancel()`,
    /// called when the place is deselected, or a newer `load()` stops a fetch.
    func load() async {
        loadTask?.cancel()
        state = .loading
        let task = Task { await fetch() }
        loadTask = task
        await task.value
        if loadTask == task { loadTask = nil }
    }

    /// Loads unless the week is already loaded, joining a fetch already in flight. Views call this
    /// from `.task`, which reruns when a fold or resize rebuilds them, so a loaded week is never
    /// fetched twice (specs/003 FR-007, research.md R3; specs/005 FR-012).
    func loadIfNeeded() async {
        if case .loaded = state { return }
        if let loadTask {
            await loadTask.value
            return
        }
        await load()
    }

    /// Stops the fetch in flight; its result is dropped and the state is left as it is. Called when
    /// this forecast's place is deselected or replaced (specs/005 FR-012).
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }

    /// Loads again after a failure (FR-011).
    func retry() async {
        await load()
    }

    private func fetch() async {
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
}

/// The day whose detail sheet is open, identified by the day itself so `.sheet(item:)` can
/// present it. Wraps the `ForecastKit` value instead of adding a retroactive `Identifiable`
/// conformance to it (specs/005 research R2).
nonisolated struct PresentedDay: Identifiable, Hashable, Sendable {
    let day: DaySuitability
    var id: DaySuitability { day }
}
