import ForecastKit
import MapKit
import Observation
import SwiftUI

/// The marker on the map: where the user tapped, and the place once it is named
/// (specs/005 data-model.md › MapPin). It keys the view's naming task, so a new tap cancels
/// the lookup for the previous one (research R4).
nonisolated struct MapPin: Hashable, Sendable {
    let coordinate: Coordinate
    /// `nil` while the point is being named.
    var place: Place?

    var isLocating: Bool { place == nil }
}

/// Screen model for the sidebar map (specs/005 contracts/ui.md › Map, data-model.md › MapPickerModel).
///
/// Owned by `BrowseModel` for the app's lifetime, so the camera and the marker survive the map view
/// being rebuilt by a fold, a resize or typing a search (FR-009, research R7).
@Observable
final class MapPickerModel {
    /// The default view: the whole world.
    static let worldRegion = MKCoordinateRegion(.world)
    /// Degrees shown around a place picked from search: about 30 km, a town and its surroundings.
    static let citySpan = 0.3

    /// What the map shows. Bound to the map, so pans and zooms write back here.
    var camera: MapCameraPosition = .region(worldRegion)
    /// The current marker; `nil` before any tap or selection.
    private(set) var pin: MapPin?

    private let locator: any PlaceLocating
    private let regionCode: String?
    private var didLoadInitialRegion = false

    init(locator: any PlaceLocating, regionCode: String?) {
        self.locator = locator
        self.regionCode = regionCode
    }

    /// Moves the marker to `coordinate` at once, in the locating state (FR-002, FR-004).
    /// The view ignores taps on the current marker before calling this (FR-010, research R8).
    func tap(at coordinate: Coordinate) {
        pin = MapPin(coordinate: coordinate, place: nil)
    }

    /// Names the current pin and returns its place.
    ///
    /// A named pin is returned as it is, with no lookup, so a view rebuilt by a fold can call this
    /// again safely (FR-009). The result is applied only if the pin is still the one that was looked
    /// up and the task was not cancelled; an older tap never names a newer pin (FR-007).
    func locatePin() async -> Place? {
        guard let current = pin else { return nil }
        if let place = current.place { return place }
        let nearest: Place?
        do {
            nearest = try await locator.nearestLocality(to: current.coordinate)
        } catch {
            return nil
        }
        guard !Task.isCancelled, pin == current else { return nil }
        let place = MapSelection.place(at: current.coordinate, nearest: nearest)
        pin = MapPin(coordinate: current.coordinate, place: place)
        return place
    }

    /// Marks `place`, chosen from search results, and centres the map on it at city zoom, so map and
    /// search agree on the selection (specs/005 FR-008). Map taps never call this, so the map never
    /// jumps under the user's finger (research R7).
    func show(_ place: Place) {
        pin = MapPin(coordinate: place.coordinate, place: place)
        camera = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
            span: MKCoordinateSpan(latitudeDelta: Self.citySpan, longitudeDelta: Self.citySpan)))
    }

    /// Moves the first view to the device region's country, once per session (FR-011, research R6).
    ///
    /// Only an ISO country (two letters) is looked up; "World" or "Europe" keep the whole world.
    /// The answer is used only if the map is still on its untouched default with no marker, and a
    /// failure keeps the world view silently.
    func loadInitialRegionIfNeeded() async {
        guard !didLoadInitialRegion else { return }
        didLoadInitialRegion = true
        guard let code = regionCode, code.count == 2, code.allSatisfy({ $0.isASCII && $0.isLetter }),
              showsDefaultView
        else { return }
        guard let region = try? await locator.region(ofCountry: code), !Task.isCancelled, showsDefaultView
        else { return }
        camera = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: region.center.latitude, longitude: region.center.longitude),
            span: MKCoordinateSpan(latitudeDelta: region.latitudeDelta, longitudeDelta: region.longitudeDelta)))
    }

    /// No marker yet, and the camera is still the initial world view.
    private var showsDefaultView: Bool {
        guard pin == nil, !camera.positionedByUser, let region = camera.region else { return false }
        let world = Self.worldRegion
        return region.center.latitude == world.center.latitude
            && region.center.longitude == world.center.longitude
            && region.span.latitudeDelta == world.span.latitudeDelta
            && region.span.longitudeDelta == world.span.longitudeDelta
    }
}
