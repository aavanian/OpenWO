import XCTest
@testable import GymTrackKit

final class DatabaseTests: XCTestCase {
    func testInMemoryDatabaseCreates() throws {
        let db = try AppDatabase.empty()
        XCTAssertNotNil(db)
    }

    func testTablesExist() throws {
        let db = try AppDatabase.empty()
        let tableNames = try db.dbWriter.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        }
        XCTAssertTrue(tableNames.contains("session"))
        XCTAssertTrue(tableNames.contains("dailyChallenge"))
        XCTAssertTrue(tableNames.contains("exercise"))
        XCTAssertTrue(tableNames.contains("workout"))
        XCTAssertTrue(tableNames.contains("workoutExercise"))
        XCTAssertTrue(tableNames.contains("exerciseLog"))
    }

    func testV3MigrationAddsColumns() throws {
        let db = try AppDatabase.empty()

        // Verify hasWeight column exists on exercise
        let hasWeightCount = try db.dbWriter.read { dbConn in
            try Int.fetchOne(dbConn, sql: "SELECT COUNT(*) FROM exercise WHERE hasWeight = 1")
        }
        // Rows (3), Chest press (4), Shoulder press (5), Curls (6)
        XCTAssertEqual(hasWeightCount, 4)

        // Verify feedback column exists on session (nullable)
        try db.dbWriter.write { dbConn in
            try dbConn.execute(
                sql: "INSERT INTO session (sessionType, date, startedAt, durationSeconds, isPartial, feedback) VALUES ('A', '2026-02-25', '2026-02-25T08:00:00', 2400, 0, 'ok')"
            )
        }
        let feedback = try db.dbWriter.read { dbConn in
            try String?.fetchOne(dbConn, sql: "SELECT feedback FROM session ORDER BY id DESC LIMIT 1")
        }
        XCTAssertEqual(feedback, "ok")
    }

    func testSeedDataPopulated() throws {
        let db = try AppDatabase.empty()

        let exerciseCount = try db.dbWriter.read { dbConn in
            try Int.fetchOne(dbConn, sql: "SELECT COUNT(*) FROM exercise")
        }
        XCTAssertEqual(exerciseCount, 12)

        let workoutCount = try db.dbWriter.read { dbConn in
            try Int.fetchOne(dbConn, sql: "SELECT COUNT(*) FROM workout")
        }
        XCTAssertEqual(workoutCount, 3)

        let weCount = try db.dbWriter.read { dbConn in
            try Int.fetchOne(dbConn, sql: "SELECT COUNT(*) FROM workoutExercise")
        }
        // Day A: 9 + Day B: 7 + Day C: 7 = 23
        XCTAssertEqual(weCount, 23)
    }
}
