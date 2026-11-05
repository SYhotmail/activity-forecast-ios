/// Forecast for one local day (spec: Daily Weather). Every value is optional because
/// the service can return `null`; missing values must never be scored as zero (FR-013).
public struct DailyWeather: Sendable, Hashable {
    public let date: LocalDate
    /// WMO weather interpretation code.
    public var weatherCode: Int?
    /// °C
    public var temperatureMax: Double?
    /// °C
    public var temperatureMin: Double?
    /// mm
    public var precipitation: Double?
    /// mm
    public var rain: Double?
    /// cm
    public var snowfall: Double?
    /// cm, daily maximum of the hourly snow depth.
    public var snowDepth: Double?
    /// %
    public var precipitationProbability: Double?
    /// km/h
    public var windSpeedMax: Double?
    /// km/h
    public var windGustsMax: Double?
    /// hours
    public var sunshine: Double?

    public init(date: LocalDate, weatherCode: Int? = nil,
                temperatureMax: Double? = nil, temperatureMin: Double? = nil,
                precipitation: Double? = nil, rain: Double? = nil,
                snowfall: Double? = nil, snowDepth: Double? = nil,
                precipitationProbability: Double? = nil,
                windSpeedMax: Double? = nil, windGustsMax: Double? = nil,
                sunshine: Double? = nil) {
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
