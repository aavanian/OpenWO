import Foundation

public enum SessionType: String, Codable, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"

    public var displayName: String {
        switch self {
        case .a: return "Day A — Upper Strength"
        case .b: return "Day B — Cardio + Core"
        case .c: return "Day C — Mixed / Maintenance"
        }
    }

    public var subtitle: String {
        switch self {
        case .a: return "Upper Strength"
        case .b: return "Cardio + Core"
        case .c: return "Mixed / Maintenance"
        }
    }

    public var shortLabel: String {
        rawValue
    }
}
