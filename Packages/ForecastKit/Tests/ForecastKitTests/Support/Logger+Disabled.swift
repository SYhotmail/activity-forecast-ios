import OSLog

extension Logger {
    /// Logs nowhere: tests construct the client with it (specs/010 FR-002).
    static let disabled = Logger(OSLog.disabled)
}
