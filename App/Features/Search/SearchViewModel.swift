import ForecastKit
import Foundation
import Observation

/// View model for place search (contracts/ui.md › Search, data-model.md › LoadState).
///
/// The view owns debouncing: it calls `search()` from `.task(id: query)` after a short sleep,
/// so SwiftUI cancels a superseded search when the query changes (research.md R5).
/// A result is only applied if its task was not cancelled and the query has not changed
/// since the request started, so older text never replaces newer results (FR-012).
@Observable
final class SearchViewModel {
    /// Minimum trimmed query length that triggers a search (FR-001).
    static let minimumQueryLength = 2

    var query = ""
    private(set) var state: LoadState<[Place]> = .idle
    /// Trimmed query that produced the current `.loaded`/`.empty` state, if any.
    private var lastQuery: String?

    private let service: any WeatherService
    private let language: QueryLanguage

    /// - Parameter language: picks the language each query is searched in (specs/007).
    init(service: any WeatherService, language: QueryLanguage = .user) {
        self.service = service
        self.language = language
    }

    private var trimmedQuery: String {
        Self.trimmed(query)
    }

    /// Searches for the current query, or returns to `.idle` when it is too short.
    ///
    /// Asking again for the query whose results are already shown makes no request: the
    /// sidebar's `.task(id: query)` reruns when a fold or resize rebuilds it (specs/003 FR-007,
    /// research.md R3).
    func search() async {
        let trimmed = trimmedQuery
        guard trimmed.count >= Self.minimumQueryLength else {
            state = .idle
            lastQuery = nil
            return
        }
        if trimmed == lastQuery, isShowingResults { return }
        state = .loading
        let outcome: LoadState<[Place]>
        do {
            let places = try await service.searchPlaces(matching: trimmed, language: language.code(for: trimmed))
            outcome = places.isEmpty ? .empty : .loaded(places)
        } catch is CancellationError {
            return
        } catch let error as UserFacingError {
            outcome = .failed(error)
        } catch {
            outcome = .failed(.unexpected)
        }
        guard !Task.isCancelled, trimmedQuery == trimmed else { return }
        state = outcome
        lastQuery = trimmed
    }

    /// Runs the current search again (FR-011). Always makes a request.
    func retry() async {
        lastQuery = nil
        await search()
    }

    private var isShowingResults: Bool {
        switch state {
        case .loaded, .empty: true
        case .idle, .loading, .failed: false
        }
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
