import Foundation
import Testing
@testable import ForecastKit

/// Sliding-window limiting (specs/008 FR-001, FR-002). Reservations are checked against fixed
/// instants, so no test waits for real time.
@Suite("RateLimiter")
struct RateLimiterTests {
    let start = ContinuousClock.now

    @Test("Requests within the limit start immediately")
    func withinLimit() async {
        let limiter = RateLimiter(limit: 3, per: .seconds(10))

        for _ in 0..<3 {
            #expect(await limiter.reserve(at: start) == start)
        }
    }

    @Test("Over the limit, a request starts when the oldest leaves the window")
    func overLimit() async {
        let limiter = RateLimiter(limit: 2, per: .seconds(10))
        _ = await limiter.reserve(at: start)
        _ = await limiter.reserve(at: start + .seconds(4))

        #expect(await limiter.reserve(at: start + .seconds(5)) == start + .seconds(10))
        #expect(await limiter.reserve(at: start + .seconds(5)) == start + .seconds(14))
    }

    @Test("Requests older than the window no longer count")
    func windowSlides() async {
        let limiter = RateLimiter(limit: 1, per: .seconds(10))
        _ = await limiter.reserve(at: start)

        #expect(await limiter.reserve(at: start + .seconds(11)) == start + .seconds(11))
    }

    @Test("Waiting for a slot ends with CancellationError when cancelled")
    func cancelledWait() async throws {
        let limiter = RateLimiter(limit: 1, per: .seconds(60))
        try await limiter.acquire()

        let waiter = Task { try await limiter.acquire() }
        waiter.cancel()

        await #expect(throws: CancellationError.self) { try await waiter.value }
    }
}
