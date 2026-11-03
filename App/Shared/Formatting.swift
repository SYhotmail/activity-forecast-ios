import SwiftUI
import ForecastKit

/// Display-only helpers shared by the views. No decisions are made here, only formatting.
enum Formatting {
    /// Forecast days are calendar days stored as GMT midnight (`LocalDate.date`), so they are
    /// always formatted in GMT to show the place's own day, whatever the device time zone.
    private static let dayStyle = Date.FormatStyle(timeZone: .gmt)

    /// "Tue"
    static func shortWeekday(_ date: LocalDate) -> String {
        date.date.formatted(dayStyle.weekday(.abbreviated))
    }

    /// "1 · Skiing — Excellent 86", or "4 · Skiing — No data" when no day could be scored.
    static func sectionHeader(_ ranking: ActivityRanking) -> String {
        let rating = if let score = ranking.weeklyScore, let label = ranking.weeklyLabel {
            "\(label.title) \(score)"
        } else {
            "No data"
        }
        return "\(ranking.rank) · \(ranking.activity.title) — \(rating)"
    }
}

extension SuitabilityLabel {
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
