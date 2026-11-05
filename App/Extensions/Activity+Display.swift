import ForecastKit

/// Presentation of `Activity`. ForecastKit stays free of display text and UI concerns.
extension Activity {
    var title: String {
        switch self {
        case .skiing: "Skiing"
        case .surfing: "Surfing"
        case .outdoorSightseeing: "Outdoor sightseeing"
        case .indoorSightseeing: "Indoor sightseeing"
        }
    }

    /// SF Symbol shown next to the activity name (specs/002-app-icons research.md D4).
    var symbolName: String {
        switch self {
        case .skiing: "figure.skiing.downhill"
        case .surfing: "figure.surfing"
        case .outdoorSightseeing: "figure.hiking"
        case .indoorSightseeing: "building.columns"
        }
    }
}
