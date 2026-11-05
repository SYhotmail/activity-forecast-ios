import Foundation
import OSLog

extension Logger {
    /// A logger under the app's subsystem (the bundle identifier). Only the composition root
    /// creates these (specs/010 FR-001, FR-006).
    init(category: String) {
        self.init(subsystem: Bundle.main.bundleIdentifier ?? "ActivityForecast", category: category)
    }

    /// Logs nowhere: previews and app tests pass it. Production code never uses it
    /// (specs/010 FR-002, FR-006).
    static let disabled = Logger(OSLog.disabled)
}
