import Foundation
import ForecastKit

/// Plain-language reason text (FR-008), values in fixed metric units (FR-016).
extension Reason.Detail {
    var text: String {
        switch self {
        case .noSnowOnGround: "No snow on the ground"
        case .thunderstorms: "Thunderstorms expected"
        case .snowfallExpected: "Snowfall expected"
        case .poorWeatherOutside: "Poor weather outside — good day for museums"
        case .greatWeatherOutside: "Great weather outside — better spent outdoors"
        case let .freshSnow(value): "Fresh snow \(Self.centimetres(value))"
        case let .snowBase(value): "Snow base \(Self.centimetres(value))"
        case let .thinSnowCover(value): "Thin snow cover \(Self.centimetres(value))"
        case let .cold(value): "Cold \(Self.celsius(value))"
        case let .tooWarm(value): "Too warm \(Self.celsius(value))"
        case let .warm(value): "Warm \(Self.celsius(value))"
        case let .tooCold(value): "Too cold \(Self.celsius(value))"
        case let .tooHot(value): "Too hot \(Self.celsius(value))"
        case let .comfortable(value): "Comfortable \(Self.celsius(value))"
        case let .hot(value): "Hot \(Self.celsius(value))"
        case let .lightGusts(value): "Light gusts \(Self.speed(value))"
        case let .strongGusts(value): "Strong gusts \(Self.speed(value))"
        case let .goodBreeze(value): "Good breeze \(Self.speed(value))"
        case let .tooLittleWind(value): "Too little wind \(Self.speed(value))"
        case let .tooWindy(value): "Too windy \(Self.speed(value))"
        case let .lightWind(value): "Light wind \(Self.speed(value))"
        case let .strongWind(value): "Strong wind \(Self.speed(value))"
        case .dry: "Dry \(Self.millimetres(0))"
        case let .littleRain(value): "Little rain \(Self.millimetres(value))"
        case let .rain(value): "Rain \(Self.millimetres(value))"
        case let .heavyRain(value): "Heavy rain \(Self.millimetres(value))"
        case let .rainLikely(value): "Rain likely \(Formatting.percent(value))"
        case let .sunny(value): "Sunny \(Self.hours(value))"
        case let .littleSunshine(value): "Little sunshine \(Self.hours(value))"
        }
    }

    private static func centimetres(_ value: Double) -> String { Formatting.metric(value, UnitLength.centimeters) }
    private static func millimetres(_ value: Double) -> String { Formatting.metric(value, UnitLength.millimeters) }
    private static func celsius(_ value: Double) -> String { Formatting.metric(value, UnitTemperature.celsius) }
    private static func speed(_ value: Double) -> String { Formatting.metric(value, UnitSpeed.kilometersPerHour) }
    private static func hours(_ value: Double) -> String { Formatting.metric(value, UnitDuration.hours) }
}
