import SwiftUI
import ForecastKit

/// Adaptive root (specs/003 contracts/ui.md): search in the sidebar, the selected place's
/// forecast in the detail column. In compact width the split view collapses into a stack,
/// giving the narrow search → forecast → Back flow (research.md R1, FR-004…FR-006).
struct RootView: View {
    @Bindable var browse: BrowseModel
    /// Both columns visible by default, including iPad portrait, where `.automatic` would hide
    /// the search behind a button (FR-006). The user can still collapse the sidebar.
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    /// The column a collapsed (compact) split view shows. The map's Show forecast sets it to
    /// `.detail` to push the forecast, since the map is not a selectable list (specs/005 research R5).
    @State private var compactColumn = NavigationSplitViewColumn.sidebar

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $compactColumn) {
            SearchView(browse: browse, compactColumn: $compactColumn)
        } detail: {
            // One stable NavigationStack for the whole detail column. Without it, a forecast pushed
            // in compact width (folded Duo) stopped redrawing when its state changed; re-creating
            // the stack per place (an `.id` on the stack) lost the Back button. Only the content
            // inside is swapped per place.
            NavigationStack {
                if let forecast = browse.forecast {
                    ForecastView(model: forecast)
                        .id(forecast.place)
                } else {
                    ContentUnavailableView(
                        "Pick a place",
                        systemImage: "map",
                        description: Text("Search for a city or town, or tap the map, to see its week.")
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview("Nothing selected") {
    RootView(browse: PreviewData.browse())
}

#Preview("Place selected") {
    let browse = PreviewData.browse()
    browse.search.query = "Paris"
    browse.select(PreviewData.paris)
    return RootView(browse: browse)
}
