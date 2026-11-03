/// Human label for a 0–100 suitability score (FR-005).
public enum SuitabilityLabel: String, Sendable, Hashable, CaseIterable {
    case poor, fair, good, excellent

    /// Minimum score for a day to be eligible as an activity's best day (FR-007).
    public static let bestDayThreshold = 25

    public init(score: Int) {
        switch score {
        case ..<25: self = .poor
        case 25..<50: self = .fair
        case 50..<75: self = .good
        default: self = .excellent
        }
    }

    public var title: String { rawValue.capitalized }
}

/// One plain-language explanation of a score (FR-008).
public struct Reason: Sendable, Hashable {
    public enum Kind: Sendable, Hashable { case cap, negative, positive }

    public let kind: Kind
    public let text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }
}

/// One activity on one day (spec: Activity Suitability).
public struct DaySuitability: Sendable, Hashable {
    public enum Result: Sendable, Hashable {
        case scored(score: Int, label: SuitabilityLabel, reasons: [Reason])
        /// A factor the activity needs is missing from the forecast (FR-013).
        case noData
    }

    public let activity: Activity
    public let weather: DailyWeather
    public let result: Result

    public init(activity: Activity, weather: DailyWeather, result: Result) {
        self.activity = activity
        self.weather = weather
        self.result = result
    }

    public var date: LocalDate { weather.date }

    public var score: Int? {
        if case let .scored(score, _, _) = result { score } else { nil }
    }
}

/// One activity across the week (spec: Activity Ranking).
public struct ActivityRanking: Sendable, Hashable, Identifiable {
    public let activity: Activity
    /// In date order, up to 7.
    public let days: [DaySuitability]
    /// Rounded mean of scored days; `nil` when no day could be scored.
    public let weeklyScore: Int?
    /// Highest-scoring day (earliest if tied), only when it reaches `SuitabilityLabel.bestDayThreshold`.
    public let bestDay: LocalDate?
    /// 1…4
    public let rank: Int

    public init(activity: Activity, days: [DaySuitability], weeklyScore: Int?, bestDay: LocalDate?, rank: Int) {
        self.activity = activity
        self.days = days
        self.weeklyScore = weeklyScore
        self.bestDay = bestDay
        self.rank = rank
    }

    public var id: Activity { activity }
    public var weeklyLabel: SuitabilityLabel? { weeklyScore.map(SuitabilityLabel.init(score:)) }
}

/// The ranked week for one place.
public struct WeeklyRanking: Sendable, Hashable {
    public let place: Place
    /// Sorted best first (FR-006).
    public let rankings: [ActivityRanking]

    public init(place: Place, rankings: [ActivityRanking]) {
        self.place = place
        self.rankings = rankings
    }
}
