import ForecastKit
import Observation

/// Navigation state shared by the narrow (stack) and wide (side-by-side) layouts
/// (specs/003 contracts/ui.md, data-model.md › BrowseModel).
///
/// It outlives any single view, so when a fold, rotation or window resize rebuilds the
/// columns, they reattach to the same search, selection and forecast instead of starting
/// over (FR-006, FR-007, research.md R2).
@Observable
final class BrowseModel {
    /// The sidebar's search. One instance for the model's lifetime.
    let search: SearchModel
    /// The place whose forecast is shown; `nil` when nothing is selected.
    private(set) var selectedPlace: Place?
    /// The forecast for `selectedPlace`. Invariant: `forecast?.place == selectedPlace`.
    private(set) var forecast: ForecastModel?

    private let service: any WeatherService
    /// Names map taps and finds the initial map region (specs/005). Used from T014 on.
    private let locator: any PlaceLocating
    /// The device region's code, e.g. "GB"; decides the map's first view (specs/005 FR-011).
    private let regionCode: String?

    /// No defaults: production code must never fall back to a test double (constitution Principle V).
    init(service: any WeatherService, locator: any PlaceLocating, regionCode: String?) {
        self.service = service
        self.locator = locator
        self.regionCode = regionCode
        search = SearchModel(service: service)
    }

    /// Selects `place`. Re-selecting the current place keeps its forecast as it is, so a
    /// loaded week is never fetched again; any other place gets a fresh forecast.
    func select(_ place: Place?) {
        guard place != selectedPlace else { return }
        selectedPlace = place
        forecast = place.map { ForecastModel(place: $0, service: service) }
    }
}
