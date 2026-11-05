import Foundation

/// The units the forecast is requested in (specs/006 FR-001). Values are always decoded with
/// the units the response states, and scoring does not depend on them (FR-004, FR-005).
public struct ForecastUnits: Sendable, Hashable {
    /// Raw values are Open-Meteo's `temperature_unit` parameter.
    public enum Temperature: String, Sendable, Hashable { case celsius, fahrenheit }
    /// Raw values are Open-Meteo's `wind_speed_unit` parameter.
    public enum WindSpeed: String, Sendable, Hashable {
        case kilometresPerHour = "kmh", metresPerSecond = "ms", milesPerHour = "mph", knots = "kn"
    }
    /// Raw values are Open-Meteo's `precipitation_unit` parameter; it also sets snowfall and snow depth.
    public enum Precipitation: String, Sendable, Hashable { case millimetres = "mm", inches = "inch" }

    public var temperature: Temperature
    public var windSpeed: WindSpeed
    public var precipitation: Precipitation

    public init(temperature: Temperature, windSpeed: WindSpeed, precipitation: Precipitation) {
        self.temperature = temperature
        self.windSpeed = windSpeed
        self.precipitation = precipitation
    }

    /// °C, km/h, mm: Open-Meteo's defaults.
    public static let metric = Self(temperature: .celsius, windSpeed: .kilometresPerHour, precipitation: .millimetres)
    /// °F, mph, inches.
    public static let imperial = Self(temperature: .fahrenheit, windSpeed: .milesPerHour, precipitation: .inches)

    /// The units of the user's locale and settings (specs/006 research R2). Temperature is asked
    /// of Foundation with the `.weather` usage the app displays with, so it follows the iOS
    /// Temperature setting (the locale's `mu` keyword). Rain and snow are in inches only in the
    /// US system; wind is in mph outside the metric system (UK, US).
    public init(locale: Locale) {
        let fahrenheit = UnitTemperature(forLocale: locale, usage: .weather) == .fahrenheit
        let system = locale.measurementSystem
        self.init(temperature: fahrenheit ? .fahrenheit : .celsius,
                  windSpeed: system == .metric ? .kilometresPerHour : .milesPerHour,
                  precipitation: system == .us ? .inches : .millimetres)
    }
}
