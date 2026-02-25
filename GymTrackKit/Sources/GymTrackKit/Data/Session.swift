import Foundation
import GRDB

public struct Session: Codable, FetchableRecord, PersistableRecord, Identifiable {
    public var id: Int64?
    public var sessionType: String
    public var date: String
    public var startedAt: String
    public var durationSeconds: Int
    public var isPartial: Bool
    public var feedback: String?

    public init(
        id: Int64? = nil,
        sessionType: SessionType,
        date: String,
        startedAt: String,
        durationSeconds: Int,
        isPartial: Bool = false,
        feedback: String? = nil
    ) {
        self.id = id
        self.sessionType = sessionType.rawValue
        self.date = date
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.isPartial = isPartial
        self.feedback = feedback
    }

    public var type: SessionType? {
        SessionType(rawValue: sessionType)
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
