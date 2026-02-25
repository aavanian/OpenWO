import Foundation

public enum WorkoutFeedback: String, CaseIterable {
    case easy
    case ok
    case hard

    public var displayLabel: String {
        switch self {
        case .easy: return "Easy"
        case .ok: return "OK"
        case .hard: return "Hard"
        }
    }

    public var icon: String {
        switch self {
        case .easy: return "face.smiling"
        case .ok: return "face.smiling.inverse"
        case .hard: return "flame"
        }
    }
}
