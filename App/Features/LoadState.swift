import ForecastKit

/// Every state a screen can be in (contracts/ui.md). Exhaustive by design.
enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(UserFacingError)
}

extension LoadState: Equatable where Value: Equatable {}
