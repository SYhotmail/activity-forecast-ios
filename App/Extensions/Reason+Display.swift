import Foundation
import ForecastKit

/// Plain-language reason text (FR-008), values in the user's units (FR-016).
extension Reason.Detail {
    var text: String {
        switch self {
        case .noSnowOnGround: "No snow on the ground"
        case .thunderstorms: "Thunderstorms expected"
        case .snowfallExpected: "Snowfall expected"
        case .poorWeatherOutside: "Poor weather outside — good day for museums"
        case .greatWeatherOutside: "Great weather outside — better spent outdoors"
        case let .freshSnow(value): "Fresh snow \(Formatting.snow(value))"
        case let .snowBase(value): "Snow base \(Formatting.snow(value))"
        case let .thinSnowCover(value): "Thin snow cover \(Formatting.snow(value))"
        case let .cold(value): "Cold \(Formatting.temperature(value))"
        case let .tooWarm(value): "Too warm \(Formatting.temperature(value))"
        case let .warm(value): "Warm \(Formatting.temperature(value))"
        case let .tooCold(value): "Too cold \(Formatting.temperature(value))"
        case let .tooHot(value): "Too hot \(Formatting.temperature(value))"
        case let .comfortable(value): "Comfortable \(Formatting.temperature(value))"
        case let .hot(value): "Hot \(Formatting.temperature(value))"
        case let .lightGusts(value): "Light gusts \(Formatting.windSpeed(value))"
        case let .strongGusts(value): "Strong gusts \(Formatting.windSpeed(value))"
        case let .goodBreeze(value): "Good breeze \(Formatting.windSpeed(value))"
        case let .tooLittleWind(value): "Too little wind \(Formatting.windSpeed(value))"
        case let .tooWindy(value): "Too windy \(Formatting.windSpeed(value))"
        case let .lightWind(value): "Light wind \(Formatting.windSpeed(value))"
        case let .strongWind(value): "Strong wind \(Formatting.windSpeed(value))"
        case .dry: "Dry \(Formatting.rainfall(.millimetres(0)))"
        case let .littleRain(value): "Little rain \(Formatting.rainfall(value))"
        case let .rain(value): "Rain \(Formatting.rainfall(value))"
        case let .heavyRain(value): "Heavy rain \(Formatting.rainfall(value))"
        case let .rainLikely(value): "Rain likely \(Formatting.percent(value))"
        case let .sunny(value): "Sunny \(Formatting.hours(value))"
        case let .littleSunshine(value): "Little sunshine \(Formatting.hours(value))"
        }
    }
}
