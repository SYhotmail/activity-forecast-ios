import CoreLocation
import Foundation
import MapKit

/// `PlaceLocating` backed by Apple's keyless MapKit services (specs/005 research R2, R6).
///
/// Open-Meteo has no reverse geocoding, so naming a tapped point uses MapKit:
/// `MKReverseGeocodingRequest` on iOS/macOS 26+, `CLGeocoder` before that. No location
/// permission is needed. The only MapKit import in ForecastKit (constitution 2.3.0, Principle V).
public struct MapKitPlaceLocator: PlaceLocating {
    public init() {}

    public func nearestLocality(to coordinate: Coordinate) async throws -> Place? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let locality: Place?
            if #available(iOS 26, macOS 26, *) {
                locality = try await Self.mapKitLocality(at: location)
            } else {
                locality = try await Self.geocoderLocality(at: location)
            }
            try Task.checkCancellation()
            return locality
        } catch {
            if Self.isNotFound(error) { return nil }
            throw Self.map(error)
        }
    }

    public func region(ofCountry code: String) async throws -> GeoRegion? {
        guard code.count == 2, code.allSatisfy({ $0.isASCII && $0.isLetter }),
              let name = Locale(identifier: "en_US").localizedString(forRegionCode: code.uppercased())
        else { return nil }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        request.resultTypes = .address
        do {
            let region = try await MKLocalSearch(request: request).start().boundingRegion
            try Task.checkCancellation()
            return GeoRegion(
                center: Coordinate(latitude: region.center.latitude, longitude: region.center.longitude),
                latitudeDelta: region.span.latitudeDelta,
                longitudeDelta: region.span.longitudeDelta)
        } catch {
            if Self.isNotFound(error) { return nil }
            throw Self.map(error)
        }
    }

    // MARK: - Lookups

    /// iOS/macOS 26+: city from the first map item's address representations. `regionName` is the
    /// country; the region is parsed from `cityWithContext` (see `region(fromCityContext:city:country:)`).
    @available(iOS 26, macOS 26, *)
    private static func mapKitLocality(at location: CLLocation) async throws -> Place? {
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        guard let item = try await request.mapItems.first,
              let address = item.addressRepresentations,
              let city = address.cityName, !city.isEmpty
        else { return nil }
        let region = region(fromCityContext: address.cityWithContext, city: city, country: address.regionName)
        return Place(id: 0, name: city, region: region, country: address.regionName,
                     latitude: item.location.coordinate.latitude,
                     longitude: item.location.coordinate.longitude,
                     timeZone: item.timeZone?.identifier ?? "GMT")
    }

    /// iOS/macOS 18–25: `CLGeocoder` placemark fields. Deprecated only from 26, which never runs this.
    private static func geocoderLocality(at location: CLLocation) async throws -> Place? {
        guard let placemark = try await CLGeocoder().reverseGeocodeLocation(location).first,
              let city = placemark.locality, !city.isEmpty
        else { return nil }
        let point = placemark.location?.coordinate ?? location.coordinate
        return Place(id: 0, name: city, region: placemark.administrativeArea, country: placemark.country,
                     latitude: point.latitude, longitude: point.longitude,
                     timeZone: placemark.timeZone?.identifier ?? "GMT")
    }

    /// The region inside MapKit's "city, context" string, or `nil` when it only repeats the country.
    /// Live shapes: "Cupertino, CA United States" → "CA"; "Chamonix, France" → nil; "Courmayeur" → nil.
    static func region(fromCityContext context: String?, city: String, country: String?) -> String? {
        guard let context, context.hasPrefix(city + ", ") else { return nil }
        var rest = Substring(context.dropFirst(city.count + 2))
        // Drop the country only as a whole trailing part, never from inside a name ("Île-de-France").
        if let country, rest == country || rest.hasSuffix(" " + country) {
            rest = rest.dropLast(country.count)
        }
        let region = rest.trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces))
        return region.isEmpty ? nil : region
    }

    // MARK: - Error mapping (contracts/place-locating.md › Behaviour)

    private static func isNotFound(_ error: any Error) -> Bool {
        if let clError = error as? CLError, clError.code == .geocodeFoundNoResult { return true }
        if let mkError = error as? MKError, mkError.code == .placemarkNotFound { return true }
        return false
    }

    static func map(_ error: any Error) -> any Error {
        if error is CancellationError { return error }
        if let clError = error as? CLError {
            switch clError.code {
            case .geocodeCanceled: return CancellationError()
            case .network: return UserFacingError.offline
            default: break
            }
        }
        let nsError = error as NSError
        let urlError = nsError.domain == NSURLErrorDomain
            ? nsError
            : nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        if let urlError, urlError.domain == NSURLErrorDomain {
            let offlineCodes = [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
                                NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
                                NSURLErrorDNSLookupFailed, NSURLErrorDataNotAllowed]
            if urlError.code == NSURLErrorCancelled { return CancellationError() }
            if offlineCodes.contains(urlError.code) { return UserFacingError.offline }
        }
        return UserFacingError.serviceUnavailable
    }
}
