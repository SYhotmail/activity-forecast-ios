import Testing
@testable import ForecastKit

@Suite("Ramp: piecewise-linear normalisation")
struct RampTests {
    /// Rising, flat, then falling, like the surfing wind factor.
    private let ramp = Ramp([(x: 0, y: 0.3), (x: 15, y: 1), (x: 35, y: 1), (x: 50, y: 0)])

    @Test("returns the breakpoint value exactly at each breakpoint", arguments: [
        (0.0, 0.3), (15.0, 1.0), (35.0, 1.0), (50.0, 0.0)
    ])
    func atBreakpoints(x: Double, expected: Double) {
        #expect(abs(ramp(x) - expected) < 1e-9)
    }

    @Test("interpolates linearly between breakpoints", arguments: [
        (7.5, 0.65), (25.0, 1.0), (42.5, 0.5), (45.0, 1.0 / 3.0)
    ])
    func between(x: Double, expected: Double) {
        #expect(abs(ramp(x) - expected) < 1e-9)
    }

    @Test("clamps to the end values outside the range", arguments: [
        (-10.0, 0.3), (-0.001, 0.3), (50.001, 0.0), (1_000.0, 0.0)
    ])
    func clamps(x: Double, expected: Double) {
        #expect(abs(ramp(x) - expected) < 1e-9)
    }

    @Test("a descending ramp (≤ 0 → 1, ≥ 5 → 0) works like skiing's cold factor")
    func descending() {
        let cold = Ramp([(x: 0, y: 1), (x: 5, y: 0)])
        #expect(cold(-20) == 1)
        #expect(cold(0) == 1)
        #expect(abs(cold(2.5) - 0.5) < 1e-9)
        #expect(cold(5) == 0)
        #expect(cold(30) == 0)
    }

    @Test("a single breakpoint is a constant")
    func single() {
        let constant = Ramp([(x: 10, y: 0.7)])
        #expect(constant(-5) == 0.7)
        #expect(constant(10) == 0.7)
        #expect(constant(99) == 0.7)
    }
}
