import Foundation

/// Sliding-window rate limiter: at most `limit` requests start in any `window` (specs/008 FR-001).
///
/// A caller over the limit waits for the earliest free slot instead of failing (FR-002). Each slot
/// is reserved synchronously inside the actor, so concurrent callers are ordered without a queue.
/// A cancelled wait keeps its slot, which errs on the side of never exceeding the limit.
///
/// It also holds the cooldown after the service's 429 (FR-007, FR-008), which the client checks
/// before asking for a slot.
actor RateLimiter {
    private let limit: Int
    private let window: Duration
    private let clock = ContinuousClock()
    /// Reserved start times, oldest first, pruned to those still inside a window.
    private var starts: [ContinuousClock.Instant] = []
    /// End of the cooldown after a 429, in wall-clock time because the service gives it so.
    private var cooldown: Date?

    init(limit: Int, per window: Duration) {
        precondition(limit > 0, "A rate limit allows at least one request")
        self.limit = limit
        self.window = window
    }

    /// Returns once a request may start. Throws `CancellationError` if cancelled while waiting.
    func acquire() async throws {
        try await clock.sleep(until: reserve(at: clock.now))
    }

    /// Starts or extends the cooldown; a shorter one never cuts it short.
    func coolDown(until end: Date) {
        cooldown = max(cooldown ?? end, end)
    }

    /// The cooldown's end while it is after `now`, else `nil`.
    func cooldownEnd(at now: Date) -> Date? {
        cooldown.flatMap { $0 > now ? $0 : nil }
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
