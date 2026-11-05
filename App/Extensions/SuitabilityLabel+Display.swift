import SwiftUI
import ForecastKit

/// Presentation of `SuitabilityLabel` (FR-005, FR-015).
extension SuitabilityLabel {
    var title: String {
        switch self {
        case .poor: "Poor"
        case .fair: "Fair"
        case .good: "Good"
        case .excellent: "Excellent"
        }
    }

    /// Rating colour. Always shown next to the label text, never on its own (FR-015).
    var color: Color {
        switch self {
        case .poor: .red
        case .fair: .orange
        case .good: .yellow
        case .excellent: .green
        }
    }
}
