import Foundation
import Observation

/// Screen model for place search (contracts/ui.md › Search, data-model.md › LoadState).
///
/// The view owns debouncing: it calls `search()` from `.task(id: query)` after a short sleep,
/// so SwiftUI cancels a superseded search when the query changes (research.md R5).
@MainActor
@Observable
public final class SearchModel {
    /// Minimum trimmed query length that triggers a search (FR-001).
    public static let minimumQueryLength = 2

    public var query = ""
    public private(set) var state: LoadState<[Place]> = .idle

    private let service: any WeatherService

    public init(service: any WeatherService) {
        self.service = service
    }

    /// Searches for the current query, or returns to `.idle` when it is too short.
    public func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minimumQueryLength else {
            state = .idle
            return
        }
        state = .loading
        do {
            let places = try await service.searchPlaces(matching: trimmed)
            state = places.isEmpty ? .empty : .loaded(places)
        } catch {
            state = .failed(.unexpected)
        }
    }
}
