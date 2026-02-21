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
    }
}
