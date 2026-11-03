/// Turns a week of forecasts into the ranked list of activities (FR-006, FR-007, FR-013).
public enum WeeklyRanker {
    /// Scores every activity on every day and ranks the activities.
    ///
    /// - Weekly score: rounded mean of the days that could be scored; `nil` when none could.
    /// - Best day: the highest-scoring day, the earliest if tied, only when it reaches
    ///   `SuitabilityLabel.bestDayThreshold`.
    /// - Order: weekly score (unscored last), then highest daily score, then `Activity.allCases`.
    public static func rank(_ days: [DailyWeather], for place: Place) -> WeeklyRanking {
        let sortedDays = days.sorted { $0.date < $1.date }
        let suitabilities = Dictionary(uniqueKeysWithValues: Activity.allCases.map { activity in
            (activity, sortedDays.map { ActivityScorer.suitability(for: activity, on: $0) })
        })
        return rank(suitabilities, for: place)
    }

    /// Ranks already-scored days. Separate from scoring so tie-breaks can be tested directly.
    static func rank(_ suitabilities: [Activity: [DaySuitability]], for place: Place) -> WeeklyRanking {
        struct Candidate {
            let activity: Activity
            let order: Int
            let days: [DaySuitability]
            let weeklyScore: Int?
            let best: DaySuitability?
        }

        let candidates = Activity.allCases.enumerated().map { order, activity in
            let days = (suitabilities[activity] ?? []).sorted { $0.date < $1.date }
            let scores = days.compactMap(\.score)
            let weeklyScore = scores.isEmpty
                ? nil
                : Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
            // Days are in date order, so keeping the first maximum picks the earliest tie.
            let best = days.reduce(nil as DaySuitability?) { best, day in
                guard let score = day.score else { return best }
                guard let current = best?.score else { return day }
                return score > current ? day : best
            }
            return Candidate(activity: activity, order: order, days: days, weeklyScore: weeklyScore, best: best)
        }

        let ordered = candidates.sorted { lhs, rhs in
            switch (lhs.weeklyScore, rhs.weeklyScore) {
            case let (l?, r?) where l != r: return l > r
            case (.some, nil): return true
            case (nil, .some): return false
            default: break
            }
            let lBest = lhs.best?.score ?? Int.min
            let rBest = rhs.best?.score ?? Int.min
            if lBest != rBest { return lBest > rBest }
            return lhs.order < rhs.order
        }

        let rankings = ordered.enumerated().map { index, candidate in
            let bestDay = candidate.best.flatMap { day in
                (day.score ?? 0) >= SuitabilityLabel.bestDayThreshold ? day.date : nil
            }
            return ActivityRanking(activity: candidate.activity, days: candidate.days,
                                   weeklyScore: candidate.weeklyScore, bestDay: bestDay, rank: index + 1)
        }
        return WeeklyRanking(place: place, rankings: rankings)
    }
}
