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
    /// IANA identifier of the place (`timezone=auto`), e.g. `Europe/Paris`.
    let timezone: String
    /// The place's offset at request time. Only a fallback: it is wrong for days after a DST change.
    let utcOffsetSeconds: Int
    let daily: DailyDTO
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

    struct HourlyDTO: Decodable {
        /// Unix seconds of each hour (`timeformat=unixtime`).
        let time: [Int]
        /// Metres.
        let snowDepth: [Double?]?
    }

    /// Maps to domain days, dated in the place's time zone (FR-003).
    /// - Throws: `UserFacingError.unexpected` when there is no day or no usable time zone.
    func dailyWeather() throws(UserFacingError) -> [DailyWeather] {
        guard let zone = TimeZone(identifier: timezone) ?? TimeZone(secondsFromGMT: utcOffsetSeconds)
        else { throw .unexpected }
        let snowDepthByDate = dailyMaxSnowDepthInCentimetres(in: zone)
        let days = daily.time.enumerated().map { index, time in
            let date = Self.localDate(time, in: zone)
            return DailyWeather(
                date: date,
                weatherCode: daily.weatherCode[safe: index],
                temperatureMax: daily.temperature2mMax[safe: index],
                temperatureMin: daily.temperature2mMin[safe: index],
                precipitation: daily.precipitationSum[safe: index],
                rain: daily.rainSum[safe: index],
                snowfall: daily.snowfallSum[safe: index],
                snowDepth: snowDepthByDate[date],
                precipitationProbability: daily.precipitationProbabilityMax[safe: index],
                windSpeedMax: daily.windSpeed10mMax[safe: index],
                windGustsMax: daily.windGusts10mMax[safe: index],
                sunshine: daily.sunshineDuration[safe: index].map { $0 / 3600 }
            )
        }
        guard !days.isEmpty else { throw .unexpected }
        return days
    }

    /// Hourly snow depth grouped by the place's calendar day, max per day, m → cm.
    /// Days whose hourly values are all `null` have no entry.
    private func dailyMaxSnowDepthInCentimetres(in zone: TimeZone) -> [LocalDate: Double] {
        guard let hourly, let depths = hourly.snowDepth else { return [:] }
        var result: [LocalDate: Double] = [:]
        for (time, depth) in zip(hourly.time, depths) {
            guard let depth else { continue }
            let date = Self.localDate(time, in: zone)
            result[date] = max(result[date] ?? -.infinity, depth * 100)
        }
        return result
    }

    private static func localDate(_ unixSeconds: Int, in zone: TimeZone) -> LocalDate {
        LocalDate(Date(timeIntervalSince1970: TimeInterval(unixSeconds)), in: zone)
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
