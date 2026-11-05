import Foundation

/// Forecast for one local day (spec: Daily Weather). Every value is optional because
/// the service can return `null`; missing values must never be scored as zero (FR-013).
/// Quantities carry their unit, as received (specs/006 FR-003).
public struct DailyWeather: Sendable, Hashable {
    public let date: LocalDate
    /// WMO weather interpretation code.
    public var weatherCode: Int?
    public var temperatureMax: Measurement<UnitTemperature>?
    public var temperatureMin: Measurement<UnitTemperature>?
    public var precipitation: Measurement<UnitLength>?
    public var rain: Measurement<UnitLength>?
    public var snowfall: Measurement<UnitLength>?
    /// Daily maximum of the hourly snow depth.
    public var snowDepth: Measurement<UnitLength>?
    /// %
    public var precipitationProbability: Double?
    public var windSpeedMax: Measurement<UnitSpeed>?
    public var windGustsMax: Measurement<UnitSpeed>?
    public var sunshine: Measurement<UnitDuration>?

    public init(date: LocalDate, weatherCode: Int? = nil,
                temperatureMax: Measurement<UnitTemperature>? = nil,
                temperatureMin: Measurement<UnitTemperature>? = nil,
                precipitation: Measurement<UnitLength>? = nil, rain: Measurement<UnitLength>? = nil,
                snowfall: Measurement<UnitLength>? = nil, snowDepth: Measurement<UnitLength>? = nil,
                precipitationProbability: Double? = nil,
                windSpeedMax: Measurement<UnitSpeed>? = nil, windGustsMax: Measurement<UnitSpeed>? = nil,
                sunshine: Measurement<UnitDuration>? = nil) {
        self.date = date
        self.weatherCode = weatherCode
        self.temperatureMax = temperatureMax
        self.temperatureMin = temperatureMin
        self.precipitation = precipitation
        self.rain = rain
        self.snowfall = snowfall
        self.snowDepth = snowDepth
        self.precipitationProbability = precipitationProbability
        self.windSpeedMax = windSpeedMax
        self.windGustsMax = windGustsMax
        self.sunshine = sunshine
    }

    /// WMO 95–99: thunderstorm (with or without hail).
    public var isThunderstorm: Bool { weatherCode.flatMap { (95...99).contains($0) } == true }
}
