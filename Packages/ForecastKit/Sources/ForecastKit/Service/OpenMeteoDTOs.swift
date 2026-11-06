import Foundation

// Wire formats of the two Open-Meteo endpoints (contracts/open-meteo.md).
// Only the fields we use are decoded; unknown fields are ignored.

// MARK: - Errors

/// Body of a rejected request, e.g. `{"error":true,"reason":"Invalid language"}`. Only logged.
struct ErrorResponseDTO: Decodable {
    let reason: String
}

// MARK: - Geocoding

struct GeocodingResponseDTO: Decodable {
    /// Absent when nothing matches.
    let results: [GeocodingResultDTO]?

    var places: [Place] { (results ?? []).map(\.place) }
}

struct GeocodingResultDTO: Decodable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?
    let timezone: String

    var place: Place {
        Place(id: id, name: name, region: admin1, country: country,
              latitude: latitude, longitude: longitude, timeZone: timezone)
    }
}

// MARK: - Forecast

struct ForecastResponseDTO: Decodable {
    /// IANA identifier of the place (`timezone=auto`), e.g. `Europe/Paris`.
    let timezone: String
    /// The place's offset at request time. Only a fallback: it is wrong for days after a DST change.
    let utcOffsetSeconds: Int
    /// Unit symbol of each daily series, e.g. `°F` (specs/006 FR-004).
    let dailyUnits: DailyUnitsDTO?
    let daily: DailyDTO
    let hourlyUnits: HourlyUnitsDTO?
    let hourly: HourlyDTO?

    /// Parallel arrays indexed by `time`. Any element may be `null` and a whole series may be absent.
    struct DailyDTO: Decodable {
        /// Unix seconds of each local midnight (`timeformat=unixtime`).
        let time: [Int]
        let weatherCode: [Int?]?
        let temperature2mMax: [Double?]?
        let temperature2mMin: [Double?]?
        let precipitationSum: [Double?]?
        let rainSum: [Double?]?
        let snowfallSum: [Double?]?
        let precipitationProbabilityMax: [Double?]?
        let windSpeed10mMax: [Double?]?
        let windGusts10mMax: [Double?]?
        let sunshineDuration: [Double?]?

        /// `.convertFromSnakeCase` turns `temperature_2m_max` into `temperature2MMax` (it
        /// capitalises the segment after `_`, even when it starts with a digit), so the
        /// digit-bearing keys need their converted spelling here. The rest match as is.
        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode
            case precipitationSum
            case rainSum
            case snowfallSum
            case precipitationProbabilityMax
            case sunshineDuration
            case temperature2mMax = "temperature2MMax"
            case temperature2mMin = "temperature2MMin"
            case windSpeed10mMax = "windSpeed10MMax"
            case windGusts10mMax = "windGusts10MMax"
        }
    }

    /// Unit symbols of the measured daily series; the other series have no physical unit.
    struct DailyUnitsDTO: Decodable {
        let temperature2mMax: String?
        let temperature2mMin: String?
        let precipitationSum: String?
        let rainSum: String?
        let snowfallSum: String?
        let windSpeed10mMax: String?
        let windGusts10mMax: String?
        let sunshineDuration: String?

        /// Same spelling rule as `DailyDTO.CodingKeys`.
        enum CodingKeys: String, CodingKey {
            case precipitationSum
            case rainSum
            case snowfallSum
            case sunshineDuration
            case temperature2mMax = "temperature2MMax"
            case temperature2mMin = "temperature2MMin"
            case windSpeed10mMax = "windSpeed10MMax"
            case windGusts10mMax = "windGusts10MMax"
        }
    }

    struct HourlyDTO: Decodable {
        /// Unix seconds of each hour (`timeformat=unixtime`).
        let time: [Int]
        /// In `HourlyUnitsDTO.snowDepth`: metres, or feet with `precipitation_unit=inch`.
        let snowDepth: [Double?]?
    }

    struct HourlyUnitsDTO: Decodable {
        let snowDepth: String?
    }

    /// Maps to domain days, dated in the place's time zone (FR-003), with each value in the
    /// unit the response states (specs/006 FR-004).
    /// - Throws: `UserFacingError.unexpected` when there is no day, no usable time zone, or a
    ///   present series whose unit is missing or unknown.
    func dailyWeather() throws(UserFacingError) -> [DailyWeather] {
        guard let zone = TimeZone(identifier: timezone) ?? TimeZone(secondsFromGMT: utcOffsetSeconds)
        else { throw .unexpected }
        let units = dailyUnits
        let temperatureMax = try Self.measured(daily.temperature2mMax, units?.temperature2mMax,
                                               OpenMeteoUnit.temperature)
        let temperatureMin = try Self.measured(daily.temperature2mMin, units?.temperature2mMin,
                                               OpenMeteoUnit.temperature)
        let precipitation = try Self.measured(daily.precipitationSum, units?.precipitationSum, OpenMeteoUnit.length)
        let rain = try Self.measured(daily.rainSum, units?.rainSum, OpenMeteoUnit.length)
        let snowfall = try Self.measured(daily.snowfallSum, units?.snowfallSum, OpenMeteoUnit.length)
        let windSpeed = try Self.measured(daily.windSpeed10mMax, units?.windSpeed10mMax, OpenMeteoUnit.speed)
        let windGusts = try Self.measured(daily.windGusts10mMax, units?.windGusts10mMax, OpenMeteoUnit.speed)
        let sunshine = try Self.measured(daily.sunshineDuration, units?.sunshineDuration, OpenMeteoUnit.duration)
        let snowDepthByDate = try dailyMaxSnowDepth(in: zone)
        let days = daily.time.enumerated().map { index, time in
            let date = Self.localDate(time, in: zone)
            return DailyWeather(
                date: date,
                weatherCode: daily.weatherCode[safe: index],
                temperatureMax: temperatureMax[safe: index],
                temperatureMin: temperatureMin[safe: index],
                precipitation: precipitation[safe: index],
                rain: rain[safe: index],
                snowfall: snowfall[safe: index],
                snowDepth: snowDepthByDate[date],
                precipitationProbability: daily.precipitationProbabilityMax[safe: index],
                windSpeedMax: windSpeed[safe: index],
                windGustsMax: windGusts[safe: index],
                sunshine: sunshine[safe: index]
            )
        }
        guard !days.isEmpty else { throw .unexpected }
        return days
    }

    /// Hourly snow depth grouped by the place's calendar day, max per day, in the response's unit.
    /// Days whose hourly values are all `null` have no entry.
    private func dailyMaxSnowDepth(in zone: TimeZone) throws(UserFacingError) -> [LocalDate: Measurement<UnitLength>] {
        guard let hourly, let depths = hourly.snowDepth else { return [:] }
        let unit = try Self.unit(hourlyUnits?.snowDepth, OpenMeteoUnit.length)
        var maxima: [LocalDate: Double] = [:]
        for (time, depth) in zip(hourly.time, depths) {
            guard let depth else { continue }
            let date = Self.localDate(time, in: zone)
            maxima[date] = max(maxima[date] ?? -.infinity, depth)
        }
        return maxima.mapValues { Measurement(value: $0, unit: unit) }
    }

    /// A series as measurements in its stated unit; `nil` when the series is absent.
    private static func measured<U: Dimension>(
        _ values: [Double?]?, _ symbol: String?, _ lookup: (String) -> U?
    ) throws(UserFacingError) -> [Measurement<U>?]? {
        guard let values else { return nil }
        let unit = try unit(symbol, lookup)
        return values.map { $0.map { Measurement(value: $0, unit: unit) } }
    }

    private static func unit<U: Dimension>(_ symbol: String?, _ lookup: (String) -> U?) throws(UserFacingError) -> U {
        guard let symbol, let unit = lookup(symbol) else { throw .unexpected }
        return unit
    }

    private static func localDate(_ unixSeconds: Int, in zone: TimeZone) -> LocalDate {
        LocalDate(Date(timeIntervalSince1970: TimeInterval(unixSeconds)), in: zone)
    }
}

/// Open-Meteo's unit symbols (verified live, specs/006 research R3).
enum OpenMeteoUnit {
    static func temperature(_ symbol: String) -> UnitTemperature? {
        switch symbol {
        case "°C": .celsius
        case "°F": .fahrenheit
        default: nil
        }
    }

    /// Precipitation and snowfall (`mm`, `cm`, `inch`) and snow depth (`m`, `ft`).
    static func length(_ symbol: String) -> UnitLength? {
        switch symbol {
        case "mm": .millimeters
        case "cm": .centimeters
        case "m": .meters
        case "inch": .inches
        case "ft": .feet
        default: nil
        }
    }

    static func speed(_ symbol: String) -> UnitSpeed? {
        switch symbol {
        case "km/h": .kilometersPerHour
        case "mp/h": .milesPerHour
        case "m/s": .metersPerSecond
        case "kn": .knots
        default: nil
        }
    }

    static func duration(_ symbol: String) -> UnitDuration? {
        symbol == "s" ? .seconds : nil
    }
}

private extension Optional {
    /// Element at `index` of an optional series of optionals; `nil` when the series,
    /// the index or the element is missing.
    subscript<Element>(safe index: Int) -> Element? where Wrapped == [Element?] {
        guard let array = self, array.indices.contains(index) else { return nil }
        return array[index]
    }
}
