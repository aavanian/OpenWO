import XCTest
@testable import GymTrackKit

final class StreakLogicTests: XCTestCase {
    private let cal = Calendar.current

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - Gym Streak

    func testGymStreakZeroWhenNoDates() {
        XCTAssertEqual(StreakLogic.gymStreak(sessionDates: [], today: date(2026, 2, 20)), 0)
    }

    func testGymStreakOneWhenOnlyToday() {
        let dates = [date(2026, 2, 20)]
        XCTAssertEqual(StreakLogic.gymStreak(sessionDates: dates, today: date(2026, 2, 20)), 1)
    }

    func testGymStreakCountsConsecutiveDaysEndingToday() {
        let dates = [
            date(2026, 2, 18),
            date(2026, 2, 19),
            date(2026, 2, 20),
        ]
        XCTAssertEqual(StreakLogic.gymStreak(sessionDates: dates, today: date(2026, 2, 20)), 3)
    }

    func testGymStreakCountsFromYesterdayIfNoSessionToday() {
        let dates = [
            date(2026, 2, 18),
            date(2026, 2, 19),
        ]
        XCTAssertEqual(StreakLogic.gymStreak(sessionDates: dates, today: date(2026, 2, 20)), 2)
    }

    func testGymStreakResetsOnGap() {
        let dates = [
            date(2026, 2, 15),
            date(2026, 2, 19),
            date(2026, 2, 20),
        ]
        XCTAssertEqual(StreakLogic.gymStreak(sessionDates: dates, today: date(2026, 2, 20)), 2)
    }

    func testGymStreakZeroWhenGapBeforeToday() {
        let dates = [date(2026, 2, 17)]
        XCTAssertEqual(StreakLogic.gymStreak(sessionDates: dates, today: date(2026, 2, 20)), 0)
    }

    func testGymStreakDeduplicatesSameDay() {
        let dates = [
            date(2026, 2, 19),
            date(2026, 2, 19),
            date(2026, 2, 20),
        ]
        XCTAssertEqual(StreakLogic.gymStreak(sessionDates: dates, today: date(2026, 2, 20)), 2)
    }

    // MARK: - Challenge Streak

    func testChallengeStreakZeroWhenNoDates() {
        XCTAssertEqual(StreakLogic.challengeStreak(completedDates: [], today: date(2026, 2, 20)), 0)
    }

    func testChallengeStreakCountsConsecutive() {
        let dates = [
            date(2026, 2, 18),
            date(2026, 2, 19),
            date(2026, 2, 20),
        ]
        XCTAssertEqual(StreakLogic.challengeStreak(completedDates: dates, today: date(2026, 2, 20)), 3)
    }

    func testChallengeStreakFromYesterday() {
        let dates = [
            date(2026, 2, 19),
        ]
        XCTAssertEqual(StreakLogic.challengeStreak(completedDates: dates, today: date(2026, 2, 20)), 1)
    }
}
