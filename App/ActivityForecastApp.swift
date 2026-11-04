import SwiftUI
import ForecastKit

/// Composition root: the only place that chooses the live `WeatherService`.
@main
struct ActivityForecastApp: App {
    @State private var browse = BrowseModel(
        service: OpenMeteoClient(),
        locator: MapKitPlaceLocator(),
        regionCode: Locale.current.region?.identifier
    )

    var body: some Scene {
        WindowGroup {
            RootView(browse: browse)
        }
    }
}
