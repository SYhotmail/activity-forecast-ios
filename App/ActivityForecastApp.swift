import SwiftUI
import ForecastKit

/// Composition root: the only place that chooses the live `WeatherService`.
@main
struct ActivityForecastApp: App {
    @State private var browse = BrowseViewModel(service: OpenMeteoClient())

    var body: some Scene {
        WindowGroup {
            BrowseView(browse: browse)
        }
    }
}
