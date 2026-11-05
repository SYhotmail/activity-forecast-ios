/// Failures the user can understand and retry (FR-011, contracts/open-meteo.md › Error mapping).
public enum UserFacingError: Error, Sendable, Hashable {
    case offline
    case serviceUnavailable
    case unexpected
}
