import Foundation

public enum Granularity: String, CaseIterable {
    case weekly, monthly
}

public struct SessionCountBucket: Identifiable {
    public let id: String
    public let label: String
    public let count: Int
    public let dominantType: SessionType?
}

public struct PersonalBests {
    public let heaviestLift: (exercise: String, weight: Double)?
    public let longestSessionStreak: Int
    public let longestChallengeStreak: Int
    public let mostSessionsInWeek: Int
}
