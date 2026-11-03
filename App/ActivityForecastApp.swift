import SwiftUI
import ForecastKit

/// Composition root: the only place that chooses the live `WeatherService`.
@main
struct ActivityForecastApp: App {
    private let service: any WeatherService
    @State private var searchModel: SearchModel

    init() {
        let service = OpenMeteoClient()
        self.service = service
        _searchModel = State(initialValue: SearchModel(service: service))
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SearchView(model: searchModel, service: service)
            }
        }
    }
}
