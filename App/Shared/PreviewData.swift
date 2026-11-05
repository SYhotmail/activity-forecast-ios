import Foundation
import ForecastKit

/// Canned places and weather for SwiftUI previews. Never used by the running app.
nonisolated enum PreviewData {
    static let paris = Place(id: 2988507, name: "Paris", region: "Île-de-France Region",
                             country: "France", latitude: 48.85, longitude: 2.35,
                             timeZone: "Europe/Paris")
    static let parisTexas = Place(id: 4717560, name: "Paris", region: "Texas",
                                  country: "United States", latitude: 33.66, longitude: -95.56,
                                  timeZone: "America/Chicago")

    /// A mixed autumn week in a city: a rainy day, a thunderstorm, a sunny day and one day
    /// with a missing sunshine value (No data for the sightseeing activities).
    static let week: [DailyWeather] = [
        day(3, code: 3, tmax: 14, tmin: 8, precipitation: 0.2, probability: 20, wind: 12, gusts: 25, sunshine: 5),
        day(4, code: 63, tmax: 11, tmin: 7, precipitation: 12, probability: 90, wind: 20, gusts: 45, sunshine: 0),
        day(5, code: 1, tmax: 19, tmin: 10, precipitation: 0, probability: 5, wind: 10, gusts: 20, sunshine: 9),
        day(6, code: 95, tmax: 22, tmin: 15, precipitation: 8, probability: 80, wind: 30, gusts: 70, sunshine: 2),
        day(7, code: 2, tmax: 16, tmin: 9, precipitation: 1, probability: 30, wind: 25, gusts: 40, sunshine: 4),
        day(8, code: 2, tmax: 15, tmin: 9, precipitation: 0, probability: 10, wind: 15, gusts: 30, sunshine: nil),
        day(9, code: 0, tmax: 21, tmin: 11, precipitation: 0, probability: 0, wind: 8, gusts: 18, sunshine: 10)
    ]

    static let ranking = WeeklyRanker.rank(week, for: paris)

    /// Answers instantly with the canned data.
    static let service = StubWeatherService(
        search: { _ in [paris, parisTexas] },
        forecast: { _ in week }
    )

    /// Never answers, to preview loading states.
    static let hangingService = StubWeatherService(
        search: { _ in try await Task.sleep(for: .seconds(3600)); return [] },
        forecast: { _ in try await Task.sleep(for: .seconds(3600)); return [] }
    )

    /// Finds nothing.
    static let emptyService = StubWeatherService(search: { _ in [] })

    /// Fails as if the device were offline.
    static let offlineService = StubWeatherService(
        search: { _ in throw UserFacingError.offline },
        forecast: { _ in throw UserFacingError.offline }
    )

    // Mirrors DailyWeather's fields so each preview day reads as one labelled row (°C, mm, km/h, hours).
    // swiftlint:disable function_parameter_count
    private static func day(_ day: Int, code: Int, tmax: Double, tmin: Double,
                            precipitation: Double, probability: Double,
                            wind: Double, gusts: Double, sunshine: Double?) -> DailyWeather {
        DailyWeather(date: LocalDate(year: 2026, month: 11, day: day)!, weatherCode: code,
                     temperatureMax: .celsius(tmax), temperatureMin: .celsius(tmin),
                     precipitation: .millimetres(precipitation), rain: .millimetres(precipitation),
                     snowfall: .centimetres(0), snowDepth: .centimetres(0), precipitationProbability: probability,
                     windSpeedMax: .kilometresPerHour(wind), windGustsMax: .kilometresPerHour(gusts),
                     sunshine: sunshine.map { .hours($0) })
    }
    // swiftlint:enable function_parameter_count
}
