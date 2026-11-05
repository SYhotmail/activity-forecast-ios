/// Failures the user can understand and retry (FR-011, contracts/open-meteo.md › Error mapping).
public enum UserFacingError: Error, Sendable, Hashable {
    case offline
    case serviceUnavailable
    case unexpected
    /// The service refused the request for too many requests (HTTP 429, specs/008 FR-003).
    case rateLimited
}
