import XCTest
@testable import GymTrackKit

final class HomeViewModelTests: XCTestCase {
    private var db: AppDatabase!

    override func setUp() async throws {
        db = try AppDatabase.empty()
    }

    func testInitialStateShowsZeroStreakAndSessionA() throws {
        let vm = HomeViewModel(database: db)
        vm.refresh()

        XCTAssertEqual(vm.gymStreak, 0)
        XCTAssertEqual(vm.nextSessionType, .a)
        XCTAssertEqual(vm.challengeSetsToday, 0)
        XCTAssertEqual(vm.challengeStreak, 0)
    }

    func testNextSessionRotatesAfterLogging() throws {
        try Queries.insertSession(
            db,
            type: .a,
            date: "2026-02-20",
            startedAt: "2026-02-20T08:00:00",
            durationSeconds: 2400
        )

        let vm = HomeViewModel(database: db)
        vm.refresh()

        XCTAssertEqual(vm.nextSessionType, .b)
    }

    func testGymStreakUpdatesAfterRefresh() throws {
        let today = DateHelpers.dateString(from: Date())
        try Queries.insertSession(
            db,
            type: .a,
            date: today,
            startedAt: "\(today)T08:00:00",
            durationSeconds: 2400
        )

        let vm = HomeViewModel(database: db)
        vm.refresh()

        XCTAssertGreaterThanOrEqual(vm.gymStreak, 1)
    }

    func testChallengeSetsReflectsDatabase() throws {
        let today = DateHelpers.dateString(from: Date())
        try Queries.upsertChallenge(db, date: today, setsCompleted: 2)

        let vm = HomeViewModel(database: db)
        vm.refresh()

        XCTAssertEqual(vm.challengeSetsToday, 2)
    }

    func testIncrementChallengeUpdatesState() throws {
        let vm = HomeViewModel(database: db)
        vm.refresh()
        XCTAssertEqual(vm.challengeSetsToday, 0)

        vm.incrementChallenge()
        XCTAssertEqual(vm.challengeSetsToday, 1)

        vm.incrementChallenge()
        XCTAssertEqual(vm.challengeSetsToday, 2)
    }

    func testSetChallengeUpdatesState() throws {
        let vm = HomeViewModel(database: db)
        vm.refresh()

        vm.setChallenge(sets: 3)
        XCTAssertEqual(vm.challengeSetsToday, 3)

        vm.setChallenge(sets: 0)
        XCTAssertEqual(vm.challengeSetsToday, 0)
    }

    func testQuickStats() throws {
        let today = DateHelpers.dateString(from: Date())
        try Queries.insertSession(db, type: .a, date: today, startedAt: "\(today)T08:00:00", durationSeconds: 2400)

        let vm = HomeViewModel(database: db)
        vm.refresh()

        XCTAssertGreaterThanOrEqual(vm.sessionsThisWeek, 1)
        XCTAssertGreaterThanOrEqual(vm.sessionsThisMonth, 1)
        XCTAssertNotNil(vm.lastSession)
    }
}
