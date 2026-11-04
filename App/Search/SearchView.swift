import SwiftUI
import ForecastKit

/// Sidebar / root screen: search a city or town, or tap the map while the search is empty, and pick
/// one (contracts/ui.md › Search, specs/005 contracts/ui.md).
/// The selection drives the detail column, or pushes the forecast in compact width
/// (specs/003 research.md R4).
struct SearchView: View {
    @Bindable var browse: BrowseModel
    /// The collapsed split view's visible column, for the map's Show forecast (specs/005 research R5).
    @Binding var compactColumn: NavigationSplitViewColumn

    private var search: SearchModel { browse.search }

    var body: some View {
        @Bindable var search = search
        Group {
            if search.showsMap {
                // An empty search shows the map instead of the idle hint (specs/005 FR-001).
                MapPickerView(browse: browse, compactColumn: $compactColumn)
            } else {
                results
            }
        }
        .navigationTitle("Activity Forecast")
        .searchable(text: $search.query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search a city or town")
        .autocorrectionDisabled()
        .task(id: search.query) {
            // Debounce: a newer query cancels this task before the request starts (R5, FR-012).
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            await search.search()
        }
    }

    /// The search states from specs/001: hint, loading, results, empty, error with retry.
    private var results: some View {
        LoadStateView(
            state: search.state,
            idleMessage: "Type at least 2 letters to search",
            emptyMessage: "No places found for '\(search.query)'",
            retry: { await search.retry() },
            content: { places in
                // Rows are value links: in a wide window the link sets the list selection
                // (detail column); in compact width, where a collapsed split view only selects
                // plain rows in edit mode, the same link pushes the forecast (research.md R4).
                List(places, selection: selection) { place in
                    NavigationLink(value: place) {
                        PlaceRow(place: place)
                    }
                }
            }
        )
    }

    /// Selecting a row (tap, click or arrow keys + Return) selects the place (FR-008).
    private var selection: Binding<Place?> {
        Binding(get: { browse.selectedPlace }, set: { browse.select($0) })
    }
}

/// Name first, then "region, country" so same-named places can be told apart (FR-002).
private struct PlaceRow: View {
    let place: Place

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(place.name)
                .font(.body)
            if let subtitle = place.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func searchPreview(_ service: any WeatherService, query: String) -> some View {
    let browse = PreviewData.browse(service: service)
    browse.search.query = query
    return NavigationStack { SearchView(browse: browse, compactColumn: .constant(.sidebar)) }
}

#Preview("Idle") { searchPreview(PreviewData.service, query: "") }
#Preview("Loading") { searchPreview(PreviewData.hangingService, query: "Paris") }
#Preview("Loaded") { searchPreview(PreviewData.service, query: "Paris") }
#Preview("Empty") { searchPreview(PreviewData.emptyService, query: "zzqxw") }
#Preview("Failed") { searchPreview(PreviewData.offlineService, query: "Paris") }
