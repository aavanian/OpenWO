import Foundation
import GRDB

public final class AppDatabase {
    public let dbWriter: any DatabaseWriter

    public init(_ dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "session") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sessionType", .text).notNull()
                t.column("date", .text).notNull()
                t.column("startedAt", .text).notNull()
                t.column("durationSeconds", .integer).notNull()
                t.column("isPartial", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "dailyChallenge") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("date", .text).notNull().unique()
                t.column("setsCompleted", .integer).notNull().defaults(to: 0)
            }
        }

        return migrator
    }

    /// In-memory database for testing
    public static func empty() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(configuration: Configuration())
        return try AppDatabase(dbQueue)
    }
}
