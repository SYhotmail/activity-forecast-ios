import Foundation
import Observation

/// Screen model for place search (contracts/ui.md › Search, data-model.md › LoadState).
///
/// The view owns debouncing: it calls `search()` from `.task(id: query)` after a short sleep,
/// so SwiftUI cancels a superseded search when the query changes (research.md R5).
/// A result is only applied if its task was not cancelled and the query has not changed
/// since the request started, so older text never replaces newer results (FR-012).
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
        let trimmed = Self.trimmed(query)
        guard trimmed.count >= Self.minimumQueryLength else {
            state = .idle
            return
        }
        state = .loading
        let outcome: LoadState<[Place]>
        do {
            let places = try await service.searchPlaces(matching: trimmed)
            outcome = places.isEmpty ? .empty : .loaded(places)
        } catch is CancellationError {
            return
        } catch let error as UserFacingError {
            outcome = .failed(error)
        } catch {
            outcome = .failed(.unexpected)
        }
        guard !Task.isCancelled, Self.trimmed(query) == trimmed else { return }
        state = outcome
    }

    /// Runs the current search again after a failure (FR-011).
    public func retry() async {
        await search()
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
