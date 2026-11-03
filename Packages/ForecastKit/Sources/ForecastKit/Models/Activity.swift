/// The four ranked activities. Declaration order is the final ranking tie-break (FR-006).
public enum Activity: String, Sendable, Hashable, CaseIterable, Identifiable {
    case skiing
    case surfing
    case outdoorSightseeing
    case indoorSightseeing

    public var id: Self { self }

    public var title: String {
        switch self {
        case .skiing: "Skiing"
        case .surfing: "Surfing"
        case .outdoorSightseeing: "Outdoor sightseeing"
        case .indoorSightseeing: "Indoor sightseeing"
        }
    }
}
