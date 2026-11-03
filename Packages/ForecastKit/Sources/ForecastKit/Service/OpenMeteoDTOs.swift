import Foundation

// Wire formats of the two Open-Meteo endpoints (contracts/open-meteo.md).
// Only the fields we use are decoded; unknown fields are ignored.

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
    let daily: DailyDTO
    let hourly: HourlyDTO?

    /// Parallel arrays indexed by `time`. Any element may be `null` and a whole series may be absent.
    struct DailyDTO: Decodable {
        let time: [String]
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

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case precipitationSum = "precipitation_sum"
            case rainSum = "rain_sum"
            case snowfallSum = "snowfall_sum"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case windSpeed10mMax = "wind_speed_10m_max"
            case windGusts10mMax = "wind_gusts_10m_max"
            case sunshineDuration = "sunshine_duration"
        }
    }

    struct HourlyDTO: Decodable {
        /// Local `yyyy-MM-ddTHH:mm`.
        let time: [String]
        /// Metres.
        let snowDepth: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time
            case snowDepth = "snow_depth"
        }
    }

    /// Maps to domain days. Days whose date cannot be parsed are dropped.
    /// - Throws: `UserFacingError.unexpected` when no day remains.
    func dailyWeather() throws(UserFacingError) -> [DailyWeather] {
        let snowDepthByDate = dailyMaxSnowDepthInCentimetres()
        let days = daily.time.enumerated().compactMap { index, time -> DailyWeather? in
            guard let date = LocalDate(iso8601: time) else { return nil }
            return DailyWeather(
                date: date,
                weatherCode: daily.weatherCode[safe: index],
                temperatureMax: daily.temperature2mMax[safe: index],
                temperatureMin: daily.temperature2mMin[safe: index],
                precipitation: daily.precipitationSum[safe: index],
                rain: daily.rainSum[safe: index],
                snowfall: daily.snowfallSum[safe: index],
                snowDepth: snowDepthByDate[time],
                precipitationProbability: daily.precipitationProbabilityMax[safe: index],
                windSpeedMax: daily.windSpeed10mMax[safe: index],
                windGustsMax: daily.windGusts10mMax[safe: index],
                sunshine: daily.sunshineDuration[safe: index].map { $0 / 3600 }
            )
        }
        guard !days.isEmpty else { throw .unexpected }
        return days
    }

    /// Hourly snow depth grouped by the date prefix of `hourly.time`, max per day, m → cm.
    /// Days whose hourly values are all `null` have no entry.
    private func dailyMaxSnowDepthInCentimetres() -> [String: Double] {
        guard let hourly, let depths = hourly.snowDepth else { return [:] }
        var result: [String: Double] = [:]
        for (time, depth) in zip(hourly.time, depths) {
            guard let depth else { continue }
            let date = String(time.prefix(10))
            result[date] = max(result[date] ?? -.infinity, depth * 100)
        }
        return result
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
