import XCTest
@testable import GymTrackKit

final class QueriesTests: XCTestCase {
    private var db: AppDatabase!

    override func setUp() async throws {
        db = try AppDatabase.empty()
    }

    // MARK: - Sessions

    func testInsertAndFetchLastSession() throws {
        try Queries.insertSession(
            db,
            type: .a,
            date: "2026-02-20",
            startedAt: "2026-02-20T08:00:00",
            durationSeconds: 2400
        )
        try Queries.insertSession(
            db,
            type: .b,
            date: "2026-02-20",
            startedAt: "2026-02-20T17:00:00",
            durationSeconds: 2700
        )

        let last = try Queries.lastSession(db)
        XCTAssertEqual(last?.sessionType, "B")
    }

    func testLastSessionNilWhenEmpty() throws {
        let last = try Queries.lastSession(db)
        XCTAssertNil(last)
    }

    func testSessionsInDateRange() throws {
        try Queries.insertSession(db, type: .a, date: "2026-02-18", startedAt: "2026-02-18T08:00:00", durationSeconds: 2400)
        try Queries.insertSession(db, type: .b, date: "2026-02-19", startedAt: "2026-02-19T08:00:00", durationSeconds: 2400)
        try Queries.insertSession(db, type: .c, date: "2026-02-20", startedAt: "2026-02-20T08:00:00", durationSeconds: 2400)

        let sessions = try Queries.sessionsInDateRange(db, from: "2026-02-19", to: "2026-02-20")
        XCTAssertEqual(sessions.count, 2)
    }

    func testNonPartialSessionDates() throws {
        try Queries.insertSession(db, type: .a, date: "2026-02-18", startedAt: "2026-02-18T08:00:00", durationSeconds: 2400)
        try Queries.insertSession(db, type: .b, date: "2026-02-19", startedAt: "2026-02-19T08:00:00", durationSeconds: 2400, isPartial: true)
        try Queries.insertSession(db, type: .c, date: "2026-02-20", startedAt: "2026-02-20T08:00:00", durationSeconds: 2400)

        let dates = try Queries.nonPartialSessionDates(db)
        XCTAssertEqual(dates.count, 2)
    }

    // MARK: - Daily Challenge

    func testUpsertChallengeCreatesNew() throws {
        let challenge = try Queries.upsertChallenge(db, date: "2026-02-20", setsCompleted: 2)
        XCTAssertEqual(challenge.setsCompleted, 2)

        let fetched = try Queries.challengeForDate(db, date: "2026-02-20")
        XCTAssertEqual(fetched?.setsCompleted, 2)
    }

    func testUpsertChallengeUpdatesExisting() throws {
        try Queries.upsertChallenge(db, date: "2026-02-20", setsCompleted: 1)
        let updated = try Queries.upsertChallenge(db, date: "2026-02-20", setsCompleted: 3)
        XCTAssertEqual(updated.setsCompleted, 3)

        let fetched = try Queries.challengeForDate(db, date: "2026-02-20")
        XCTAssertEqual(fetched?.setsCompleted, 3)
    }

    func testIncrementChallenge() throws {
        let first = try Queries.incrementChallenge(db, date: "2026-02-20")
        XCTAssertEqual(first.setsCompleted, 1)

        let second = try Queries.incrementChallenge(db, date: "2026-02-20")
        XCTAssertEqual(second.setsCompleted, 2)

        let third = try Queries.incrementChallenge(db, date: "2026-02-20")
        XCTAssertEqual(third.setsCompleted, 3)

        // Caps at 3
        let fourth = try Queries.incrementChallenge(db, date: "2026-02-20")
        XCTAssertEqual(fourth.setsCompleted, 3)
    }

    func testCompletedChallengeDates() throws {
        try Queries.upsertChallenge(db, date: "2026-02-18", setsCompleted: 3)
        try Queries.upsertChallenge(db, date: "2026-02-19", setsCompleted: 2)
        try Queries.upsertChallenge(db, date: "2026-02-20", setsCompleted: 3)

        let dates = try Queries.completedChallengeDates(db)
        XCTAssertEqual(dates.count, 2)
    }

    func testCompletedChallengeCount() throws {
        try Queries.upsertChallenge(db, date: "2026-02-18", setsCompleted: 3)
        try Queries.upsertChallenge(db, date: "2026-02-19", setsCompleted: 2)
        try Queries.upsertChallenge(db, date: "2026-02-20", setsCompleted: 3)

        let count = try Queries.completedChallengeCount(db, from: "2026-02-01", to: "2026-02-28")
        XCTAssertEqual(count, 2)
    }

    func testChallengeForDateNilWhenNoEntry() throws {
        let challenge = try Queries.challengeForDate(db, date: "2026-02-20")
        XCTAssertNil(challenge)
    }
}
