import ForecastKit

/// How a place is named on screen (FR-002).
extension Place {
    /// "Region, Country" with missing or empty parts dropped; `nil` when neither is known.
    var subtitle: String? {
        let parts = [region, country].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// "Name, Region, Country" used to tell same-named places apart.
    var displayName: String {
        [name, subtitle].compactMap { $0 }.joined(separator: ", ")
    }
}
