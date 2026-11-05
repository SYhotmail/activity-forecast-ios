import Foundation

/// A calendar day in the place's own time zone. Kept as plain components so that
/// no device time-zone conversion can shift a forecast day (FR-003).
public struct LocalDate: Sendable, Hashable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int
    
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    public init?(year: Int, month: Int, day: Int) {
        let calendar = Self.calendar
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: calendar) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `yyyy-MM-dd` as returned by the forecast service.
    public init?(iso8601 string: String) {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let year = parts.first.flatMap({ Int($0) }),
              let month = Int(parts[1]),
              let day = parts.last.flatMap({ Int($0) })
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// Midnight GMT of this day: format it with a GMT calendar or time zone to display the same day.
    public var date: Date {
        let calendar = Self.calendar
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
