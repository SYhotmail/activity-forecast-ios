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
        /// Shown when this factor is the day's biggest strength, e.g. "Fresh snow 12 cm".
        let positive: String
        /// Shown when this factor is the day's biggest weakness, e.g. "Strong gusts 65 km/h".
        let negative: String

        var contribution: Double { weight * value }
        /// Points lost to this factor: weight × (1 − value).
        var loss: Double { weight * (1 - value) }
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
            return .scored(score: score, label: SuitabilityLabel(score: score),
                           reasons: [indoorReason(outdoorScore: outdoor.score)])
        }
        guard let breakdown else { return .noData }
        let score = breakdown.score
        return .scored(score: score, label: SuitabilityLabel(score: score), reasons: reasons(for: breakdown))
    }

    // MARK: - Reasons (FR-008, research.md R9 › Reasons)

    /// Factor values below this are called out as a weakness.
    static let negativeThreshold = 0.4
    /// Factor values at or above this are called out as a strength.
    static let positiveThreshold = 0.8
    static let maximumReasons = 2

    /// Cap first; then the biggest loss among factors below 0.4; then the biggest contribution
    /// among factors at or above 0.8; at most two. Ties go to the earlier factor. When nothing
    /// qualifies, the biggest loss is shown anyway so every scored day has a reason (FR-008).
    static func reasons(for breakdown: Breakdown) -> [Reason] {
        var reasons: [Reason] = []
        if let cap = breakdown.cap {
            reasons.append(Reason(kind: .cap, text: cap.reason))
        }
        let weak = breakdown.factors.filter { $0.value < negativeThreshold }
        if let negative = first(maximising: \.loss, in: weak) {
            reasons.append(Reason(kind: .negative, text: negative.negative))
        }
        let strong = breakdown.factors.filter { $0.value >= positiveThreshold }
        if let positive = first(maximising: \.contribution, in: strong) {
            reasons.append(Reason(kind: .positive, text: positive.positive))
        }
        if reasons.isEmpty, let fallback = first(maximising: \.loss, in: breakdown.factors) {
            reasons.append(Reason(kind: .negative, text: fallback.negative))
        }
        return Array(reasons.prefix(maximumReasons))
    }

    /// Indoor sightseeing has no factors of its own: it is good exactly when outside is not,
    /// so its single reason describes the weather outside.
    static func indoorReason(outdoorScore: Int) -> Reason {
        outdoorScore < 50
            ? Reason(kind: .positive, text: "Poor weather outside — good day for museums")
            : Reason(kind: .negative, text: "Great weather outside — better spent outdoors")
    }

    /// The earliest factor with the largest `key` (unlike `max(by:)`, which keeps the last).
    private static func first(maximising key: KeyPath<Factor, Double>, in factors: [Factor]) -> Factor? {
        factors.reduce(nil as Factor?) { best, factor in
            guard let best else { return factor }
            return factor[keyPath: key] > best[keyPath: key] ? factor : best
        }
    }

    /// "12", "7.5": one decimal at most, none for whole values.
    static func format(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }

    private static func rainText(_ millimetres: Double) -> String {
        millimetres >= 10 ? "Heavy rain \(format(millimetres)) mm" : "Rain \(format(millimetres)) mm"
    }

    private static func dryText(_ millimetres: Double) -> String {
        millimetres <= 0 ? "Dry 0 mm" : "Little rain \(format(millimetres)) mm"
    }

    static func skiing(_ w: DailyWeather) -> Breakdown? {
        guard let snowfall = w.snowfall, let depth = w.snowDepth,
              let tmax = w.temperatureMax, let tmin = w.temperatureMin,
              let gusts = w.windGustsMax, let rain = w.rain
        else { return nil }
        let factors = [
            Factor(name: .snow, weight: 50, value: min(1, max(0, snowfall / 10 + depth / 100)),
                   positive: snowfall > 0 ? "Fresh snow \(format(snowfall)) cm" : "Snow base \(format(depth)) cm",
                   negative: "Thin snow cover \(format(depth)) cm"),
            Factor(name: .cold, weight: 25, value: skiingCold(tmax),
                   positive: "Cold \(format(tmax)) °C", negative: "Too warm \(format(tmax)) °C"),
            Factor(name: .gusts, weight: 15, value: skiingGusts(gusts),
                   positive: "Light gusts \(format(gusts)) km/h", negative: "Strong gusts \(format(gusts)) km/h"),
            Factor(name: .noRain, weight: 10, value: dryness(rain),
                   positive: dryText(rain), negative: rainText(rain))
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
            Factor(name: .wind, weight: 40, value: surfingWind(wind),
                   positive: "Good breeze \(format(wind)) km/h",
                   negative: wind < 15 ? "Too little wind \(format(wind)) km/h" : "Too windy \(format(wind)) km/h"),
            Factor(name: .warmth, weight: 30, value: surfingWarmth(tmax),
                   positive: "Warm \(format(tmax)) °C",
                   negative: tmax < 18 ? "Too cold \(format(tmax)) °C" : "Too hot \(format(tmax)) °C"),
            Factor(name: .dry, weight: 30, value: dryness(precipitation),
                   positive: dryText(precipitation), negative: rainText(precipitation))
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
            Factor(name: .comfort, weight: 35, value: outdoorComfort(tmax),
                   positive: "Comfortable \(format(tmax)) °C",
                   negative: tmax < 15 ? "Cold \(format(tmax)) °C" : "Hot \(format(tmax)) °C"),
            // Describe whichever of amount or probability set the wetness.
            Factor(name: .dry, weight: 35, value: 1 - wetness,
                   positive: dryText(precipitation),
                   negative: precipitation / 10 >= probability / 200
                       ? rainText(precipitation) : "Rain likely \(format(probability))%"),
            Factor(name: .calm, weight: 15, value: outdoorCalm(wind),
                   positive: "Light wind \(format(wind)) km/h", negative: "Strong wind \(format(wind)) km/h"),
            Factor(name: .sun, weight: 15, value: min(max(sunshine, 0) / 8, 1),
                   positive: "Sunny \(format(sunshine)) h", negative: "Little sunshine \(format(sunshine)) h")
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
