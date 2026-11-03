/// Piecewise-linear normalisation used by every scoring factor (research.md R9).
///
/// Given ascending breakpoints `(x, y)`, the ramp returns `y` linearly interpolated
/// between neighbouring breakpoints and clamped to the first / last `y` outside the range.
public struct Ramp: Sendable, Hashable {
    public struct Point: Sendable, Hashable {
        public let x: Double
        public let y: Double
    }

    public let points: [Point]

    /// - Precondition: at least one breakpoint, with strictly ascending `x`.
    public init(_ breakpoints: [(x: Double, y: Double)]) {
        precondition(!breakpoints.isEmpty, "Ramp needs at least one breakpoint")
        precondition(zip(breakpoints, breakpoints.dropFirst()).allSatisfy { $0.x < $1.x },
                     "Ramp breakpoints must be strictly ascending in x")
        points = breakpoints.map { Point(x: $0.x, y: $0.y) }
    }

    public func callAsFunction(_ x: Double) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        if x <= first.x { return first.y }
        if x >= last.x { return last.y }
        for (lower, upper) in zip(points, points.dropFirst()) where x <= upper.x {
            let t = (x - lower.x) / (upper.x - lower.x)
            return lower.y + t * (upper.y - lower.y)
        }
        return last.y
    }
}
