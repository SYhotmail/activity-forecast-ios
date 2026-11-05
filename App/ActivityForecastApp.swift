import SwiftUI
import OSLog
import ForecastKit

/// Composition root: the only place that chooses the live `WeatherService`. The forecast is
/// fetched in the user's units (specs/006 FR-002); scores do not depend on them. Requests are
/// logged under the app's subsystem, category `network` (specs/010 FR-001).
@main
struct ActivityForecastApp: App {
    @State private var browse = BrowseViewModel(
        service: OpenMeteoClient(
            units: ForecastUnits(locale: .autoupdatingCurrent),
            logger: .init(category: "Network")),
        logger: .init(category: "BrowseViewModel"))

    var body: some Scene {
        WindowGroup {
            BrowseView(browse: browse)
        }
    }
}
