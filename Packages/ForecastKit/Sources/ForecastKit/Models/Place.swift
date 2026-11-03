/// A city or town the user can select (spec: Place).
public struct Place: Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
    public let region: String?
    public let country: String?
    public let latitude: Double
    public let longitude: Double
    /// IANA identifier. Display only: forecast dates already arrive in local time.
    public let timeZone: String

    public init(id: Int, name: String, region: String?, country: String?,
                latitude: Double, longitude: Double, timeZone: String) {
        self.id = id
        self.name = name
        self.region = region
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.timeZone = timeZone
    }

    /// "Region, Country" with missing or empty parts dropped; `nil` when neither is known.
    public var subtitle: String? {
        let parts = [region, country].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// "Name, Region, Country" used to tell same-named places apart (FR-002).
    public var displayName: String {
        [name, subtitle].compactMap { $0 }.joined(separator: ", ")
    }
}
