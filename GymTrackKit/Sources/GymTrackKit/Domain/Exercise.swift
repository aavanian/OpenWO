import Foundation

public struct Exercise: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let instruction: String
    public let sets: Int?
    public let reps: String
    public let isDailyChallenge: Bool
    public let isTimed: Bool
    public let hasWeight: Bool
    public let workoutExerciseId: Int64
    public let counterSeconds: Int?

    /// Whether the timer display uses minutes (>= 60s and divisible by 60)
    public var timerDisplaysMinutes: Bool {
        guard isTimed, let secs = counterSeconds else { return false }
        return secs >= 60 && secs % 60 == 0
    }

    public init(
        id: String,
        name: String,
        instruction: String,
        sets: Int? = nil,
        reps: String,
        isDailyChallenge: Bool = false,
        isTimed: Bool = false,
        hasWeight: Bool = false,
        workoutExerciseId: Int64 = 0,
        counterSeconds: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.sets = sets
        self.reps = reps
        self.isDailyChallenge = isDailyChallenge
        self.isTimed = isTimed
        self.hasWeight = hasWeight
        self.workoutExerciseId = workoutExerciseId
        self.counterSeconds = counterSeconds
    }
}
