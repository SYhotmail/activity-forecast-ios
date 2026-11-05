import Foundation

/// Sliding-window rate limiter: at most `limit` requests start in any `window` (specs/008 FR-001).
///
/// A caller over the limit waits for the earliest free slot instead of failing (FR-002). Each slot
/// is reserved synchronously inside the actor, so concurrent callers are ordered without a queue.
/// A cancelled wait keeps its slot, which errs on the side of never exceeding the limit.
actor RateLimiter {
    private let limit: Int
    private let window: Duration
    private let clock = ContinuousClock()
    /// Reserved start times, oldest first, pruned to those still inside a window.
    private var starts: [ContinuousClock.Instant] = []

    init(limit: Int, per window: Duration) {
        precondition(limit > 0, "A rate limit allows at least one request")
        self.limit = limit
        self.window = window
    }

    /// Returns once a request may start. Throws `CancellationError` if cancelled while waiting.
    func acquire() async throws {
        try await clock.sleep(until: reserve(at: clock.now))
    }

    /// Reserves and returns the earliest start at or after `now` that keeps at most `limit` starts
    /// in any window. Starts never decrease, so `starts` stays sorted.
    func reserve(at now: ContinuousClock.Instant) -> ContinuousClock.Instant {
        let windowStart = now - window
        starts.removeAll { $0 <= windowStart }
        let oldestCounted = starts.count - limit
        let start = oldestCounted < 0 ? now : max(now, starts[oldestCounted] + window)
        starts.append(start)
        return start
    }
}
