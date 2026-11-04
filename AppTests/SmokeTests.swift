import Foundation
import Testing
@testable import ActivityForecast

/// Proves the hosted test bundle links against the app module. Removed once the view-model
/// suites move here (specs/004 T011).
@Test func appModuleLinks() {
    #expect(Bundle.main.bundleIdentifier == "com.example.ActivityForecast")
}
