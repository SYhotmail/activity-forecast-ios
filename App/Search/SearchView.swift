import SwiftUI
import ForecastKit

/// Sidebar / root screen: the map, with search results in a drop-down over its top edge
/// (contracts/ui.md › Search, specs/005 contracts/ui.md). Tap the map or pick a result; the
/// selection drives the detail column, or pushes the forecast in compact width
/// (specs/003 research.md R4, specs/005 research R5).
struct SearchView: View {
    @Bindable var browse: BrowseModel
    /// The collapsed split view's visible column: picking a place sets it to `.detail`, which pushes
    /// the forecast in compact width and is ignored when both columns show (specs/005 research R5).
    @Binding var compactColumn: NavigationSplitViewColumn
    @State private var isSearching = false

    private var search: SearchModel { browse.search }

    var body: some View {
        @Bindable var search = search
        MapPickerView(browse: browse, compactColumn: $compactColumn)
            .overlay(alignment: .top) {
                if search.showsResults {
                    SearchResultsDropDown(search: search) { place in
                        browse.select(place)
                        compactColumn = .detail
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: search.showsResults)
            .navigationTitle("Activity Forecast")
            .searchable(text: $search.query,
                        isPresented: $isSearching,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search a city or town")
            .autocorrectionDisabled()
            // Focusing the field again shows the results a pick closed.
            .onChange(of: isSearching) { _, active in
                if active { search.presentResults() }
            }
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
}

/// The search states from specs/001 (hint, loading, results, empty, error with retry) in a card
/// that hugs its content, up to most of the map's height, then scrolls.
private struct SearchResultsDropDown: View {
    let search: SearchModel
    let pick: (Place) -> Void

    var body: some View {
        LoadStateView(
            state: search.state,
            idleMessage: "Type at least 2 letters to search",
            emptyMessage: "No places found for '\(search.query)'",
            retry: { await search.retry() },
            content: { places in
                // Buttons rather than list selection: a pick closes the drop-down, which arrow-key
                // selection would do on the first key press. Rows stay reachable by keyboard
                // (specs/003 FR-008). The card hugs a few rows and scrolls when they don't fit.
                ViewThatFits(in: .vertical) {
                    rows(places)
                    ScrollView { rows(places) }
                        .scrollBounceBehavior(.basedOnSize)
                }
            }
        )
        .frame(minHeight: search.state.isLoaded ? nil : 220)
        .fixedSize(horizontal: false, vertical: !search.state.isLoaded)
        // The shadow goes on the backing shape only: on the whole card it would flatten the rows
        // and lose the material's vibrant secondary text and dividers.
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .containerRelativeFrame(.vertical, alignment: .top) { height, _ in height * 0.6 }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

extension SearchResultsDropDown {
    private func rows(_ places: [Place]) -> some View {
        VStack(spacing: 0) {
            ForEach(places) { place in
                Button { pick(place) } label: {
                    PlaceRow(place: place)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if place.id != places.last?.id {
                    Divider().padding(.leading)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private extension LoadState {
    var isLoaded: Bool {
        if case .loaded = self { true } else { false }
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

#Preview("Map") { searchPreview(PreviewData.service, query: "") }
#Preview("Hint") { searchPreview(PreviewData.service, query: "P") }
#Preview("Loading") { searchPreview(PreviewData.hangingService, query: "Paris") }
#Preview("Loaded") { searchPreview(PreviewData.service, query: "Paris") }
#Preview("Empty") { searchPreview(PreviewData.emptyService, query: "zzqxw") }
#Preview("Failed") { searchPreview(PreviewData.offlineService, query: "Paris") }
