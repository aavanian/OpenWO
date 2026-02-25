import Foundation
import GRDB

public struct ExerciseRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    public var id: Int64?
    public var name: String
    public var description: String
    public var instructions: String
    public var tip: String
    public var externalId: String?
    public var level: String?
    public var category: String?
    public var force: String?
    public var mechanic: String?
    public var equipment: String?
    public var primaryMuscles: String?
    public var secondaryMuscles: String?

    public static var databaseTableName: String { "exercise" }

    public init(
        id: Int64? = nil,
        name: String,
        description: String = "",
        instructions: String = "",
        tip: String = "",
        externalId: String? = nil,
        level: String? = nil,
        category: String? = nil,
        force: String? = nil,
        mechanic: String? = nil,
        equipment: String? = nil,
        primaryMuscles: String? = nil,
        secondaryMuscles: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.instructions = instructions
        self.tip = tip
        self.externalId = externalId
        self.level = level
        self.category = category
        self.force = force
        self.mechanic = mechanic
        self.equipment = equipment
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
