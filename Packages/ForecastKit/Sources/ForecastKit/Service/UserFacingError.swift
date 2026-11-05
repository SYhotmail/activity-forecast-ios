import Foundation

/// Failures the user can understand and retry (FR-011, contracts/open-meteo.md › Error mapping).
public enum UserFacingError: Error, Sendable, Hashable {
    case offline
    case serviceUnavailable
    case unexpected
    /// The service refused requests for too many of them (HTTP 429); none are sent before
    /// `until`, when it allows them again (specs/008 FR-003, FR-007–FR-009).
    case rateLimited(until: Date)
}
