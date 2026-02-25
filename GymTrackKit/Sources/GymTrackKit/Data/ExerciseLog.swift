import Foundation
import GRDB

public struct ExerciseLog: Codable, FetchableRecord, PersistableRecord, Identifiable {
    public var id: Int64?
    public var sessionId: Int64
    public var workoutExerciseId: Int64
    public var weight: Double?
    public var failed: Bool
    public var achievedValue: Int?

    public static var databaseTableName: String { "exerciseLog" }

    public init(
        id: Int64? = nil,
        sessionId: Int64,
        workoutExerciseId: Int64,
        weight: Double? = nil,
        failed: Bool = false,
        achievedValue: Int? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.workoutExerciseId = workoutExerciseId
        self.weight = weight
        self.failed = failed
        self.achievedValue = achievedValue
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
