import ForecastKit

/// Scripted `PlaceLocating` for unit tests and SwiftUI previews (no MapKit, no network).
/// A preview and test fixture, shared by SwiftUI previews and by `ActivityForecastTests` through
/// `@testable import`. It compiles into Release because `#Preview` bodies do, but production code
/// MUST never use it: only `ActivityForecastApp` chooses the locator, and it uses `MapKitPlaceLocator`
/// (constitution Principle V).
nonisolated struct StubPlaceLocator: PlaceLocating {
    var nearest: @Sendable (Coordinate) async throws -> Place?
    var region: @Sendable (String) async throws -> GeoRegion?

    init(
        nearest: @escaping @Sendable (Coordinate) async throws -> Place? = { _ in nil },
        region: @escaping @Sendable (String) async throws -> GeoRegion? = { _ in nil }
    ) {
        self.nearest = nearest
        self.region = region
    }

    func nearestLocality(to coordinate: Coordinate) async throws -> Place? {
        try await nearest(coordinate)
    }

    func region(ofCountry code: String) async throws -> GeoRegion? {
        try await region(code)
    }
}
