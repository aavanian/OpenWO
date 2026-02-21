import Foundation

public struct Exercise: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let instruction: String
    public let sets: Int?
    public let reps: String
    public let isDailyChallenge: Bool
    public let isTimed: Bool

    public init(
        id: String,
        name: String,
        instruction: String,
        sets: Int? = nil,
        reps: String,
        isDailyChallenge: Bool = false,
        isTimed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.sets = sets
        self.reps = reps
        self.isDailyChallenge = isDailyChallenge
        self.isTimed = isTimed
    }
}
