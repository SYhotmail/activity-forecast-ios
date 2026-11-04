/// Failures the user can understand and retry (FR-011, contracts/open-meteo.md › Error mapping).
public enum UserFacingError: Error, Sendable, Hashable {
    case offline
    case serviceUnavailable
    case unexpected

    public var message: String {
        switch self {
        case .offline: "You appear to be offline. Check your connection and try again."
        case .serviceUnavailable: "The weather service isn't responding right now. Please try again."
        case .unexpected: "Something went wrong reading the forecast. Please try again."
        }
    }
}
