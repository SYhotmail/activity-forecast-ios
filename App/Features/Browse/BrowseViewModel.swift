import ForecastKit
import Observation
import os

/// Navigation state shared by the narrow (stack) and wide (side-by-side) layouts
/// (specs/003 contracts/ui.md, data-model.md › BrowseModel; renamed in specs/005 data-model.md).
///
/// It outlives any single view, so when a fold, rotation or window resize rebuilds the
/// columns, they reattach to the same search, selection and forecast instead of starting
/// over (FR-006, FR-007, research.md R2).
@Observable
final class BrowseViewModel {
    /// The sidebar's search. One instance for the model's lifetime.
    let search: SearchViewModel
    /// The place whose forecast is shown; `nil` when nothing is selected.
    private(set) var selectedPlace: Place?
    /// The forecast for `selectedPlace`. Invariant: `forecast?.place == selectedPlace`.
    private(set) var forecast: ForecastViewModel?

    /// The search list's selection, bound directly by the list. Setting it applies `select(_:)`,
    /// so a rebuilt list reporting its current row again never restarts the forecast
    /// (specs/005 FR-004).
    var selection: Place? {
        get { selectedPlace }
        set { select(newValue) }
    }

    private let service: any WeatherService
    private let logger: Logger

    /// - Parameter logger: where the screen's lifecycle is logged; the creator chooses it,
    ///   previews and tests pass `.disabled` (specs/010 FR-006).
    init(service: any WeatherService, logger: Logger) {
        self.service = service
        self.logger = logger
        search = SearchViewModel(service: service)
    }

    /// Selects `place`. Re-selecting the current place keeps its forecast as it is, so a
    /// loaded week is never fetched again; any other place gets a fresh forecast, and the old
    /// forecast's request is cancelled (specs/005 FR-012).
    func select(_ place: Place?) {
        guard place != selectedPlace else { return }
        forecast?.cancel()
        selectedPlace = place
        forecast = place.map { ForecastViewModel(place: $0, service: service) }
    }

    /// Diagnostic only: logs that the browse screen appeared (specs/010 FR-006).
    func onAppear() {
        logger.info("BrowseVM will appear")
    }

    /// Diagnostic only: logs that the browse screen disappeared (specs/010 FR-006).
    func onDisappear() {
        logger.info("BrowseVM will disappear")
    }
}
