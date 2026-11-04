import SwiftUI
import ForecastKit

/// Root screen: search a city or town and pick one (contracts/ui.md › Search).
struct SearchView: View {
    @Bindable var model: SearchModel
    /// Handed to each pushed forecast screen.
    let service: any WeatherService

    var body: some View {
        LoadStateView(
            state: model.state,
            idleMessage: "Type at least 2 letters to search",
            emptyMessage: "No places found for '\(model.query)'",
            retry: { await model.retry() },
            content: { places in
                List(places) { place in
                    NavigationLink(value: place) {
                        PlaceRow(place: place)
                    }
                }
            }
        )
        .navigationTitle("Activity Forecast")
        .searchable(text: $model.query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search a city or town")
        .autocorrectionDisabled()
        .task(id: model.query) {
            // Debounce: a newer query cancels this task before the request starts (R5, FR-012).
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            await model.search()
        }
        .navigationDestination(for: Place.self) { place in
            ForecastView(place: place, service: service)
        }
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

#if DEBUG
@MainActor
private func searchPreview(_ service: StubWeatherService, query: String) -> some View {
    let model = SearchModel(service: service)
    model.query = query
    return NavigationStack { SearchView(model: model, service: service) }
}

#Preview("Idle") { searchPreview(PreviewData.service, query: "") }
#Preview("Loading") { searchPreview(PreviewData.hangingService, query: "Paris") }
#Preview("Loaded") { searchPreview(PreviewData.service, query: "Paris") }
#Preview("Empty") { searchPreview(PreviewData.emptyService, query: "zzqxw") }
#Preview("Failed") { searchPreview(PreviewData.offlineService, query: "Paris") }
#endif
