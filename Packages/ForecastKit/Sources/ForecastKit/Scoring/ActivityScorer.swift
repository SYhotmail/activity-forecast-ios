import Foundation

/// Scores one activity on one day (FR-004, FR-009, FR-010, FR-013), per research.md R9.
///
/// Thresholds are written in °C, mm, cm, km/h and hours. Inputs may arrive in any unit: each is
/// converted to its threshold's unit before use, so a day scores the same in any unit system,
/// while reasons keep the value as received (specs/006 FR-005, FR-006).
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
        /// Shown when this factor is the day's biggest strength, e.g. fresh snow 12 cm.
        let positive: Reason.Detail
        /// Shown when this factor is the day's biggest weakness, e.g. strong gusts 65 km/h.
        let negative: Reason.Detail

        var contribution: Double { weight * value }
        /// Points lost to this factor: weight × (1 − value).
        var loss: Double { weight * (1 - value) }
    }

    /// A hard upper bound for a disqualifying condition.
    struct Cap: Sendable, Hashable {
        let maximum: Int
        let reason: Reason.Detail
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

    /// Max temperature, °C.
    private static let skiingCold = Ramp([(x: 0, y: 1), (x: 5, y: 0)])
    /// Gusts, km/h.
    private static let skiingGusts = Ramp([(x: 30, y: 1), (x: 70, y: 0)])
    /// Wind, km/h.
    private static let surfingWind = Ramp([(x: 0, y: 0.3), (x: 15, y: 1), (x: 35, y: 1), (x: 50, y: 0)])
    /// Max temperature, °C.
    private static let surfingWarmth = Ramp([(x: 5, y: 0), (x: 18, y: 1), (x: 30, y: 1), (x: 38, y: 0.5)])
    /// Max temperature, °C.
    private static let outdoorComfort = Ramp([(x: 0, y: 0), (x: 15, y: 1), (x: 25, y: 1), (x: 38, y: 0)])
    /// Wind, km/h.
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
            reasons.append(Reason(kind: .cap, detail: cap.reason))
        }
        let weak = breakdown.factors.filter { $0.value < negativeThreshold }
        if let negative = first(maximising: \.loss, in: weak) {
            reasons.append(Reason(kind: .negative, detail: negative.negative))
        }
        let strong = breakdown.factors.filter { $0.value >= positiveThreshold }
        if let positive = first(maximising: \.contribution, in: strong) {
            reasons.append(Reason(kind: .positive, detail: positive.positive))
        }
        if reasons.isEmpty, let fallback = first(maximising: \.loss, in: breakdown.factors) {
            reasons.append(Reason(kind: .negative, detail: fallback.negative))
        }
        return Array(reasons.prefix(maximumReasons))
    }

    /// Indoor sightseeing has no factors of its own: it is good exactly when outside is not,
    /// so its single reason describes the weather outside.
    static func indoorReason(outdoorScore: Int) -> Reason {
        outdoorScore < 50
            ? Reason(kind: .positive, detail: .poorWeatherOutside)
            : Reason(kind: .negative, detail: .greatWeatherOutside)
    }

    /// The earliest factor with the largest `key` (unlike `max(by:)`, which keeps the last).
    private static func first(maximising key: KeyPath<Factor, Double>, in factors: [Factor]) -> Factor? {
        factors.reduce(nil as Factor?) { best, factor in
            guard let best else { return factor }
            return factor[keyPath: key] > best[keyPath: key] ? factor : best
        }
    }

    private static func rainReason(_ amount: Reason.Detail.Length) -> Reason.Detail {
        amount.value(in: .millimeters) >= 10 ? .heavyRain(amount) : .rain(amount)
    }

    private static func dryReason(_ amount: Reason.Detail.Length) -> Reason.Detail {
        amount.value(in: .millimeters) <= 0 ? .dry : .littleRain(amount)
    }

    static func skiing(_ w: DailyWeather) -> Breakdown? {
        guard let snowfall = w.snowfall, let depth = w.snowDepth,
              let tmax = w.temperatureMax,
              let gusts = w.windGustsMax, let rain = w.rain
        else { return nil }
        let snowfallCm = snowfall.value(in: .centimeters)
        let depthCm = depth.value(in: .centimeters)
        let factors = [
            Factor(name: .snow, weight: 50, value: min(1, max(0, snowfallCm / 10 + depthCm / 100)),
                   positive: snowfallCm > 0 ? .freshSnow(snowfall) : .snowBase(depth),
                   negative: .thinSnowCover(depth)),
            Factor(name: .cold, weight: 25, value: skiingCold(tmax.value(in: .celsius)),
                   positive: .cold(tmax), negative: .tooWarm(tmax)),
            Factor(name: .gusts, weight: 15, value: skiingGusts(gusts.value(in: .kilometersPerHour)),
                   positive: .lightGusts(gusts), negative: .strongGusts(gusts)),
            Factor(name: .noRain, weight: 10, value: dryness(rain.value(in: .millimeters)),
                   positive: dryReason(rain), negative: rainReason(rain))
        ]
        // Without skiable snow there is no skiing, however good the rest of the weather
        // (live checks: Chamonix 0 cm at −3.9 °C; Minsk, a 1 cm dusting, specs/009).
        // No snow at all scores 0; some snow, too little to ski, at most 10 (specs/009 FR-002).
        guard isSkiable(snowfallCm: snowfallCm, depthCm: depthCm) else {
            let cap = snowfallCm <= 0 && depthCm <= 0
                ? Cap(maximum: 0, reason: .noSnowOnGround)
                : Cap(maximum: 10, reason: .tooLittleSnow(depth))
            return Breakdown(factors: factors, cap: cap)
        }
        return Breakdown(factors: factors, cap: nil)
    }

    /// Enough snow to ski: at least 10 cm lying or 2 cm falling (specs/009 FR-001, research R1).
    static func isSkiable(snowfallCm: Double, depthCm: Double) -> Bool {
        depthCm >= 10 || snowfallCm >= 2
    }

    static func surfing(_ w: DailyWeather) -> Breakdown? {
        guard let wind = w.windSpeedMax, let tmax = w.temperatureMax,
              let precipitation = w.precipitation, w.weatherCode != nil
        else { return nil }
        let windKmh = wind.value(in: .kilometersPerHour)
        let tmaxC = tmax.value(in: .celsius)
        let factors = [
            Factor(name: .wind, weight: 40, value: surfingWind(windKmh),
                   positive: .goodBreeze(wind),
                   negative: windKmh < 15 ? .tooLittleWind(wind) : .tooWindy(wind)),
            Factor(name: .warmth, weight: 30, value: surfingWarmth(tmaxC),
                   positive: .warm(tmax),
                   negative: tmaxC < 18 ? .tooCold(tmax) : .tooHot(tmax)),
            Factor(name: .dry, weight: 30, value: dryness(precipitation.value(in: .millimeters)),
                   positive: dryReason(precipitation), negative: rainReason(precipitation))
        ]
        let cap = w.isThunderstorm ? Cap(maximum: 10, reason: .thunderstorms) : nil
        return Breakdown(factors: factors, cap: cap)
    }

    static func outdoor(_ w: DailyWeather) -> Breakdown? {
        guard let tmax = w.temperatureMax, let precipitation = w.precipitation,
              let probability = w.precipitationProbability, let wind = w.windSpeedMax,
              let sunshine = w.sunshine, let snowfall = w.snowfall, w.weatherCode != nil
        else { return nil }
        let tmaxC = tmax.value(in: .celsius)
        let precipitationMm = precipitation.value(in: .millimeters)
        let sunshineHours = sunshine.value(in: .hours)
        let wetness = max(min(max(precipitationMm, 0) / 10, 1), min(max(probability, 0), 100) / 100 * 0.5)
        let factors = [
            Factor(name: .comfort, weight: 35, value: outdoorComfort(tmaxC),
                   positive: .comfortable(tmax),
                   negative: tmaxC < 15 ? .cold(tmax) : .hot(tmax)),
            // Describe whichever of amount or probability set the wetness.
            Factor(name: .dry, weight: 35, value: 1 - wetness,
                   positive: dryReason(precipitation),
                   negative: precipitationMm / 10 >= probability / 200
                       ? rainReason(precipitation) : .rainLikely(percent: probability)),
            Factor(name: .calm, weight: 15, value: outdoorCalm(wind.value(in: .kilometersPerHour)),
                   positive: .lightWind(wind), negative: .strongWind(wind)),
            Factor(name: .sun, weight: 15, value: min(max(sunshineHours, 0) / 8, 1),
                   positive: .sunny(sunshine), negative: .littleSunshine(sunshine))
        ]
        let cap: Cap? = if w.isThunderstorm {
            Cap(maximum: 20, reason: .thunderstorms)
        } else if snowfall.value(in: .centimeters) >= 2 {
            Cap(maximum: 20, reason: .snowfallExpected)
        } else {
            nil
        }
        return Breakdown(factors: factors, cap: cap)
    }
}

private extension Measurement where UnitType: Dimension {
    /// The numeric value in `unit`, for comparing with a threshold written in that unit.
    func value(in unit: UnitType) -> Double { converted(to: unit).value }
}
