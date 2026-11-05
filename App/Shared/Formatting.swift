import Foundation
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

    /// "Tuesday 4 November" (order follows the device locale).
    static func longDate(_ date: LocalDate) -> String {
        date.date.formatted(dayStyle.weekday(.wide).day().month(.wide))
    }

    /// Shown in place of any value the forecast did not provide (FR-013).
    static let missing = "—"

    // Forecast values arrive as measurements in whatever units were fetched (specs/006). These
    // show them in the units of the user's locale and settings (FR-016): "20 °C" in Germany,
    // "68°F" in the US, whatever unit the value came in.

    /// Air temperature, e.g. "20 °C" / "68°F".
    static func temperature(_ value: Measurement<UnitTemperature>?, locale: Locale = .autoupdatingCurrent) -> String {
        measurement(value, usage: .weather, locale: locale)
    }

    /// Rain or precipitation, e.g. "12 mm" / "0.47 in".
    static func rainfall(_ value: Measurement<UnitLength>?, locale: Locale = .autoupdatingCurrent) -> String {
        measurement(value, usage: .rainfall, fractionDigits: 2, locale: locale)
    }

    /// Snowfall or snow depth, e.g. "20 cm" / "7.87 in".
    static func snow(_ value: Measurement<UnitLength>?, locale: Locale = .autoupdatingCurrent) -> String {
        measurement(value, usage: .snowfall, fractionDigits: 2, locale: locale)
    }

    /// Wind or gust speed, e.g. "65 km/h" / "40.4 mph".
    static func windSpeed(_ value: Measurement<UnitSpeed>?, locale: Locale = .autoupdatingCurrent) -> String {
        measurement(value, usage: .wind, locale: locale)
    }

    /// A duration in hours, e.g. "6 hr" (sunshine arrives in seconds).
    static func hours(_ value: Measurement<UnitDuration>?, locale: Locale = .autoupdatingCurrent) -> String {
        measurement(value?.converted(to: .hours), usage: .asProvided, locale: locale)
    }

    /// Lengths allow two decimals so light rain in inches (1 mm = 0.04 in) never reads as 0;
    /// temperature and speed allow one. "—" when missing (FR-013).
    private static func measurement<U: Dimension>(
        _ value: Measurement<U>?, usage: MeasurementFormatUnitUsage<U>,
        fractionDigits: Int = 1, locale: Locale
    ) -> String {
        guard let value else { return missing }
        return value.formatted(
            .measurement(width: .abbreviated, usage: usage,
                         numberFormatStyle: .number.precision(.fractionLength(0...fractionDigits)))
            .locale(locale))
    }

    /// "90%", or "—" when missing.
    static func percent(_ value: Double?) -> String {
        guard let value else { return missing }
        return (value / 100).formatted(.percent.precision(.fractionLength(0)))
    }

    /// "Skiing, Tuesday 4 November, Excellent, 82, best day" (FR-015).
    static func accessibilityLabel(_ day: DaySuitability, isBestDay: Bool) -> String {
        var parts = [day.activity.title, longDate(day.date)]
        switch day.result {
        case let .scored(score, label, _):
            parts += [label.title, String(score)]
        case .noData:
            parts.append("No data")
        }
        if isBestDay { parts.append("best day") }
        return parts.joined(separator: ", ")
    }

    static let surfingFootnote = "Based on weather only — wave conditions not included."
}
