import Foundation

// Short constructors for the weather units ForecastKit reads and writes, e.g. `.celsius(20)`.

public extension Measurement where UnitType == UnitTemperature {
    static func celsius(_ value: Double) -> Self { Self(value: value, unit: .celsius) }
    static func fahrenheit(_ value: Double) -> Self { Self(value: value, unit: .fahrenheit) }
}

public extension Measurement where UnitType == UnitLength {
    static func millimetres(_ value: Double) -> Self { Self(value: value, unit: .millimeters) }
    static func centimetres(_ value: Double) -> Self { Self(value: value, unit: .centimeters) }
    static func metres(_ value: Double) -> Self { Self(value: value, unit: .meters) }
    static func inches(_ value: Double) -> Self { Self(value: value, unit: .inches) }
    static func feet(_ value: Double) -> Self { Self(value: value, unit: .feet) }
}

public extension Measurement where UnitType == UnitSpeed {
    static func kilometresPerHour(_ value: Double) -> Self { Self(value: value, unit: .kilometersPerHour) }
    static func milesPerHour(_ value: Double) -> Self { Self(value: value, unit: .milesPerHour) }
}

public extension Measurement where UnitType == UnitDuration {
    static func hours(_ value: Double) -> Self { Self(value: value, unit: .hours) }
    static func seconds(_ value: Double) -> Self { Self(value: value, unit: .seconds) }
}
