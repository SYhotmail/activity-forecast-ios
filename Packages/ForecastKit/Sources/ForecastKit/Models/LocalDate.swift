import Foundation

/// A calendar day in the place's own time zone. Kept as plain components so that
/// no device time-zone conversion can shift a forecast day (FR-003).
public struct LocalDate: Sendable, Hashable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    private static func calendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    public init?(year: Int, month: Int, day: Int) {
        let calendar = Self.calendar(timeZone: .gmt)
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: calendar) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// The calendar day that `instant` falls on in `timeZone` (the place's zone, never the device's).
    /// Uses the zone's rules for that instant, so days after a DST change stay correct.
    init(_ instant: Date, in timeZone: TimeZone) {
        let calendar = Self.calendar(timeZone: timeZone)
        let components = calendar.dateComponents([.year, .month, .day], from: instant)
        // A Gregorian calendar always yields these three components for any instant.
        year = components.year!
        month = components.month!
        day = components.day!
    }

    /// Midnight GMT of this day: format it with a GMT calendar or time zone to display the same day.
    public var date: Date {
        let calendar = Self.calendar(timeZone: .gmt)
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
