import ForecastKit

/// Message shown with a retry button for each failure category (FR-011).
extension UserFacingError {
    var message: String {
        switch self {
        case .offline: "You appear to be offline. Check your connection and try again."
        case .serviceUnavailable: "The weather service isn't responding right now. Please try again."
        case .unexpected: "Something went wrong reading the forecast. Please try again."
        case .rateLimited(let until):
            "Too many requests to the weather service. Try again \(until.formatted(.relative(presentation: .named)))."
        }
    }
}
