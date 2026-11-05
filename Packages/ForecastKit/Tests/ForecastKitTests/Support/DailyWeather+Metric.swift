import Foundation
@testable import ForecastKit

extension DailyWeather {
    /// A day given in the units of the research.md R9 tables (°C, mm, cm, km/h, hours), so test
    /// tables read like the spec. Scoring itself accepts any units (specs/006 FR-005).
    static func metric(date: LocalDate, weatherCode: Int? = nil,
                       temperatureMax: Double? = nil, temperatureMin: Double? = nil,
                       precipitation: Double? = nil, rain: Double? = nil,
                       snowfall: Double? = nil, snowDepth: Double? = nil,
                       precipitationProbability: Double? = nil,
                       windSpeedMax: Double? = nil, windGustsMax: Double? = nil,
                       sunshine: Double? = nil) -> DailyWeather {
        DailyWeather(date: date, weatherCode: weatherCode,
                     temperatureMax: temperatureMax.map { .celsius($0) },
                     temperatureMin: temperatureMin.map { .celsius($0) },
                     precipitation: precipitation.map { .millimetres($0) },
                     rain: rain.map { .millimetres($0) },
                     snowfall: snowfall.map { .centimetres($0) },
                     snowDepth: snowDepth.map { .centimetres($0) },
                     precipitationProbability: precipitationProbability,
                     windSpeedMax: windSpeedMax.map { .kilometresPerHour($0) },
                     windGustsMax: windGustsMax.map { .kilometresPerHour($0) },
                     sunshine: sunshine.map { .hours($0) })
    }

    /// The same day in US units: °F, inches, feet of snow depth, mph, sunshine in seconds.
    var imperial: DailyWeather {
        DailyWeather(date: date, weatherCode: weatherCode,
                     temperatureMax: temperatureMax?.converted(to: .fahrenheit),
                     temperatureMin: temperatureMin?.converted(to: .fahrenheit),
                     precipitation: precipitation?.converted(to: .inches),
                     rain: rain?.converted(to: .inches),
                     snowfall: snowfall?.converted(to: .inches),
                     snowDepth: snowDepth?.converted(to: .feet),
                     precipitationProbability: precipitationProbability,
                     windSpeedMax: windSpeedMax?.converted(to: .milesPerHour),
                     windGustsMax: windGustsMax?.converted(to: .milesPerHour),
                     sunshine: sunshine?.converted(to: .seconds))
    }
}
