import SwiftUI
import OSLog
import ForecastKit

/// Composition root: the only place that chooses the live `WeatherService`. The forecast is
/// fetched in the user's units (specs/006 FR-002); scores do not depend on them. Requests are
/// logged under the app's subsystem, category `network` (specs/010 FR-001); the browse screen's
/// lifecycle under category `browse` (FR-006).
@main
struct ActivityForecastApp: App {
    @State private var browse = BrowseViewModel(
        service: OpenMeteoClient(
            units: ForecastUnits(locale: .autoupdatingCurrent),
            logger: Logger(category: "network")),
        logger: Logger(category: "browse"))

    var body: some Scene {
        WindowGroup {
            BrowseView(browse: browse)
        }
    }
}
