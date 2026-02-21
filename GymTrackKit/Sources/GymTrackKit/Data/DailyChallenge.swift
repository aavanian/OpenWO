import Foundation
import GRDB

public struct DailyChallenge: Codable, FetchableRecord, PersistableRecord, Identifiable {
    public var id: Int64?
    public var date: String
    public var setsCompleted: Int

    public init(id: Int64? = nil, date: String, setsCompleted: Int = 0) {
        self.id = id
        self.date = date
        self.setsCompleted = setsCompleted
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
