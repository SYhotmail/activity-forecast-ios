/// Scores one activity on one day (FR-004, FR-009, FR-010, FR-013), per research.md R9.
///
/// Each outdoor activity is a weighted sum of named factors, each normalised to 0…1 by a
/// `Ramp`. The sum is rounded, clamped to 0…100 and then capped for disqualifying conditions.
/// Indoor sightseeing is derived from the outdoor score: `30 + 0.6 × (100 − outdoor)`.
///
/// Missing values: if any input that an activity's factors **or caps** read is `nil`, the day
/// is `.noData` for that activity; it is never scored as zero. This includes
/// `precipitationProbability` for outdoor sightseeing and `weatherCode` (the thunderstorm cap)
/// for surfing and outdoor sightseeing: an unknown sky cannot be assumed storm-free. Inputs an
/// activity does not read (e.g. sunshine for skiing) may be missing without effect.
public enum ActivityScorer {
    public static func suitability(for activity: Activity, on weather: DailyWeather) -> DaySuitability {
        DaySuitability(activity: activity, weather: weather, result: result(for: activity, on: weather))
    }

    // MARK: - Model

    /// One weighted, normalised contribution to a score. Kept as data so that plain-language
    /// reasons (FR-008) can be derived from the same numbers that produced the score.
    struct Factor: Sendable, Hashable {
        enum Name: Sendable, Hashable {
            case snow, cold, gusts, noRain   // skiing
            case wind, warmth                // surfing
            case comfort, calm, sun          // outdoor sightseeing
            case dry                         // surfing, outdoor sightseeing
        }

        let name: Name
        let weight: Double
        /// 0…1
        let value: Double

        var contribution: Double { weight * value }
    }

    /// A hard upper bound for a disqualifying condition.
    struct Cap: Sendable, Hashable {
        let maximum: Int
        let reason: String
    }

    /// The factors and the cap (if any) behind an outdoor activity's score.
    struct Breakdown: Sendable, Hashable {
        let factors: [Factor]
        let cap: Cap?

        var score: Int {
            let raw = factors.reduce(0) { $0 + $1.contribution }
            let clamped = min(100, max(0, Int(raw.rounded())))
            return cap.map { min(clamped, $0.maximum) } ?? clamped
        }
    }

    // MARK: - Ramps (research.md R9)

    private static let skiingCold = Ramp([(x: 0, y: 1), (x: 5, y: 0)])
    private static let skiingGusts = Ramp([(x: 30, y: 1), (x: 70, y: 0)])
    private static let surfingWind = Ramp([(x: 0, y: 0.3), (x: 15, y: 1), (x: 35, y: 1), (x: 50, y: 0)])
    private static let surfingWarmth = Ramp([(x: 5, y: 0), (x: 18, y: 1), (x: 30, y: 1), (x: 38, y: 0.5)])
    private static let outdoorComfort = Ramp([(x: 0, y: 0), (x: 15, y: 1), (x: 25, y: 1), (x: 38, y: 0)])
    private static let outdoorCalm = Ramp([(x: 20, y: 1), (x: 50, y: 0)])

    /// 1 at 0 mm, falling linearly to 0 at 10 mm or more.
    private static func dryness(_ millimetres: Double) -> Double {
        1 - min(max(millimetres, 0) / 10, 1)
    }

    // MARK: - Scoring

    private static func result(for activity: Activity, on weather: DailyWeather) -> DaySuitability.Result {
        let breakdown: Breakdown?
        switch activity {
        case .skiing: breakdown = skiing(weather)
        case .surfing: breakdown = surfing(weather)
        case .outdoorSightseeing: breakdown = outdoor(weather)
        case .indoorSightseeing:
            guard let outdoor = outdoor(weather) else { return .noData }
            let score = Int((30 + 0.6 * Double(100 - outdoor.score)).rounded())
            return .scored(score: score, label: SuitabilityLabel(score: score), reasons: [])
        }
        guard let breakdown else { return .noData }
        let score = breakdown.score
        let capReasons = breakdown.cap.map { [Reason(kind: .cap, text: $0.reason)] } ?? []
        return .scored(score: score, label: SuitabilityLabel(score: score), reasons: capReasons)
    }

    static func skiing(_ w: DailyWeather) -> Breakdown? {
        guard let snowfall = w.snowfall, let depth = w.snowDepth,
              let tmax = w.temperatureMax, let tmin = w.temperatureMin,
              let gusts = w.windGustsMax, let rain = w.rain
        else { return nil }
        let factors = [
            Factor(name: .snow, weight: 50, value: min(1, max(0, snowfall / 10 + depth / 100))),
            Factor(name: .cold, weight: 25, value: skiingCold(tmax)),
            Factor(name: .gusts, weight: 15, value: skiingGusts(gusts)),
            Factor(name: .noRain, weight: 10, value: dryness(rain))
        ]
        let noSnowAndThawing = snowfall <= 0 && depth <= 0 && tmin > 0
        let cap = noSnowAndThawing ? Cap(maximum: 10, reason: "No snow and above freezing") : nil
        return Breakdown(factors: factors, cap: cap)
    }

    static func surfing(_ w: DailyWeather) -> Breakdown? {
        guard let wind = w.windSpeedMax, let tmax = w.temperatureMax,
              let precipitation = w.precipitation, w.weatherCode != nil
        else { return nil }
        let factors = [
            Factor(name: .wind, weight: 40, value: surfingWind(wind)),
            Factor(name: .warmth, weight: 30, value: surfingWarmth(tmax)),
            Factor(name: .dry, weight: 30, value: dryness(precipitation))
        ]
        let cap = w.isThunderstorm ? Cap(maximum: 10, reason: "Thunderstorms expected") : nil
        return Breakdown(factors: factors, cap: cap)
    }

    static func outdoor(_ w: DailyWeather) -> Breakdown? {
        guard let tmax = w.temperatureMax, let precipitation = w.precipitation,
              let probability = w.precipitationProbability, let wind = w.windSpeedMax,
              let sunshine = w.sunshine, let snowfall = w.snowfall, w.weatherCode != nil
        else { return nil }
        let wetness = max(min(max(precipitation, 0) / 10, 1), min(max(probability, 0), 100) / 100 * 0.5)
        let factors = [
            Factor(name: .comfort, weight: 35, value: outdoorComfort(tmax)),
            Factor(name: .dry, weight: 35, value: 1 - wetness),
            Factor(name: .calm, weight: 15, value: outdoorCalm(wind)),
            Factor(name: .sun, weight: 15, value: min(max(sunshine, 0) / 8, 1))
        ]
        let cap: Cap? = if w.isThunderstorm {
            Cap(maximum: 20, reason: "Thunderstorms expected")
        } else if snowfall >= 2 {
            Cap(maximum: 20, reason: "Snowfall expected")
        } else {
            nil
        }
        return Breakdown(factors: factors, cap: cap)
    }
}
