import SwiftUI
import ForecastKit

/// Composition root: the only place that chooses the live `WeatherService`. The forecast is
/// fetched in the user's units (specs/006 FR-002); scores do not depend on them.
@main
struct ActivityForecastApp: App {
    @State private var browse = BrowseViewModel(
        service: OpenMeteoClient(units: ForecastUnits(locale: .autoupdatingCurrent)))

    var body: some Scene {
        WindowGroup {
            BrowseView(browse: browse)
        }
    }
}
