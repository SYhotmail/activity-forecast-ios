import ForecastKit
import MapKit
import SwiftUI

/// The sidebar map shown while the search is empty (specs/005 contracts/ui.md › Map).
///
/// A tap anywhere drops a marker that is named after the nearest locality within 25 km, or its
/// coordinates. In a wide window the detail column then shows that place's week; in a narrow one a
/// callout offers Show forecast, which pushes it (FR-005, research R5). No user location is shown
/// or requested (FR-011).
struct MapPickerView: View {
    @Bindable var browse: BrowseModel
    /// The collapsed split view's visible column; Show forecast sets it to `.detail` (research R5).
    @Binding var compactColumn: NavigationSplitViewColumn
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// A tap this close to the current marker (half a 44 pt touch target) is a tap on the marker,
    /// which keeps the selection as it is (FR-010, research R8).
    private static let markerHitRadius: CGFloat = 22

    private var map: MapPickerModel { browse.map }

    var body: some View {
        @Bindable var map = map
        MapReader { proxy in
            Map(position: $map.camera) {
                if let pin = map.pin {
                    Marker(pin.place?.name ?? "Locating…", coordinate: pin.coordinate.location)
                }
            }
            .onTapGesture { point in
                handleTap(at: point, proxy: proxy)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if horizontalSizeClass == .compact, let place = map.pin?.place {
                ShowForecastCallout(place: place) {
                    browse.selectMapPin()
                    compactColumn = .detail
                }
            }
        }
        // Keyed by the pin, so a newer tap cancels the lookup for the previous one (FR-007). It reruns
        // when a fold rebuilds the view: a named pin returns at once and, once the window is wide,
        // is selected so the map and the detail column agree (contracts/ui.md › Size changes).
        .task(id: map.pin) {
            await browse.locateMapPin(selectingWhenNamed: horizontalSizeClass == .regular)
        }
        .task {
            await map.loadInitialRegionIfNeeded()
        }
    }

    private func handleTap(at point: CGPoint, proxy: MapProxy) {
        if let pin = map.pin, let pinPoint = proxy.convert(pin.coordinate.location, to: .local),
           hypot(pinPoint.x - point.x, pinPoint.y - point.y) <= Self.markerHitRadius {
            return
        }
        guard let tapped = proxy.convert(point, from: .local) else { return }
        map.tap(at: Coordinate(latitude: tapped.latitude, longitude: tapped.longitude))
    }
}

/// The narrow layout's callout under the map: the named place and a Show forecast button
/// (specs/005 contracts/ui.md › Narrow layout).
private struct ShowForecastCallout: View {
    let place: Place
    let showForecast: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.headline)
                if let subtitle = place.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Button("Show forecast", action: showForecast)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .padding()
    }
}

private extension Coordinate {
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private func mapPreview(locator: any PlaceLocating, tapped: Bool) -> some View {
    let browse = PreviewData.browse(locator: locator)
    if tapped {
        browse.map.tap(at: PreviewData.chamonix.coordinate)
    }
    return NavigationStack {
        MapPickerView(browse: browse, compactColumn: .constant(.sidebar))
    }
}

#Preview("Map") { mapPreview(locator: PreviewData.locator, tapped: false) }
#Preview("Map – named pin") { mapPreview(locator: PreviewData.locator, tapped: true) }
#Preview("Map – locating") { mapPreview(locator: PreviewData.hangingLocator, tapped: true) }
