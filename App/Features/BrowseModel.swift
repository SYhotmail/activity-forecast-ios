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
    /// The sidebar's map, shown while the search is empty (specs/005). One instance for the
    /// model's lifetime, so its camera and marker survive rebuilt views (FR-009).
    let map: MapPickerModel
    /// The place whose forecast is shown; `nil` when nothing is selected.
    private(set) var selectedPlace: Place?
    /// The forecast for `selectedPlace`. Invariant: `forecast?.place == selectedPlace`.
    private(set) var forecast: ForecastModel?

    private let service: any WeatherService

    /// `locator` names map taps; `regionCode` (e.g. "GB") picks the map's first view (specs/005 FR-011).
    /// No defaults: production code must never fall back to a test double (constitution Principle V).
    init(service: any WeatherService, locator: any PlaceLocating, regionCode: String?) {
        self.service = service
        search = SearchModel(service: service)
        map = MapPickerModel(locator: locator, regionCode: regionCode)
    }

    /// Selects `place` from search results (or clears the selection with `nil`). The map marks it
    /// and centres on it, so map and search agree (specs/005 FR-008).
    func select(_ place: Place?) {
        if let place {
            map.show(place)
        }
        apply(place)
    }

    /// Names the map's pin and, in a wide layout, selects it so the detail column shows its week
    /// as soon as it is named (specs/005 FR-005). A narrow layout waits for `selectMapPin()`.
    /// The view calls this from `.task(id: pin)`, so a newer tap cancels it (research R4).
    func locateMapPin(selectingWhenNamed: Bool) async {
        guard let place = await map.locatePin(), selectingWhenNamed else { return }
        apply(place)
    }

    /// The narrow layout's Show forecast: selects the named pin's place (specs/005 FR-005).
    /// Does nothing while the pin is still locating.
    func selectMapPin() {
        guard let place = map.pin?.place else { return }
        apply(place)
    }

    /// Makes `place` the selection without moving the map. Re-selecting the current place keeps its
    /// forecast as it is, so a loaded week is never fetched again; any other place gets a fresh one.
    private func apply(_ place: Place?) {
        guard place != selectedPlace else { return }
        selectedPlace = place
        forecast = place.map { ForecastModel(place: $0, service: service) }
    }
}
