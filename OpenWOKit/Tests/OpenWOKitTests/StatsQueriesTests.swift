import XCTest
@testable import OpenWOKit

final class StatsQueriesTests: XCTestCase {
    private var db: AppDatabase!

    override func setUp() async throws {
        db = try AppDatabase.empty()
    }

    // MARK: - Weight History

    func testWeightHistoryEmptyWhenNoLogs() throws {
        let history = try Queries.weightHistory(db, exerciseId: 1)
        XCTAssertTrue(history.isEmpty)
    }

    func testWeightHistoryForExercise() throws {
        let workout = try Queries.workoutByName(db, name: "Day A")!
        let entries = try Queries.exercisesForWorkout(db, workoutId: workout.id!)
        let rowsWE = entries[2].1 // Dumbbell rows
        let exerciseId = rowsWE.exerciseId

        let session = try Queries.insertSession(
            db, type: .a, date: "2026-02-20",
            startedAt: "2026-02-20T08:00:00", durationSeconds: 2400
        )
        try Queries.insertExerciseLogs(db, sessionId: session.id!, logs: [
            ExerciseLog(sessionId: session.id!, workoutExerciseId: rowsWE.id!, weight: 12.5)
        ])

        let history = try Queries.weightHistory(db, exerciseId: exerciseId)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].date, "2026-02-20")
        XCTAssertEqual(history[0].weight, 12.5)
    }

    func testWeightHistoryMultipleDatesInOrder() throws {
        let workout = try Queries.workoutByName(db, name: "Day A")!
        let entries = try Queries.exercisesForWorkout(db, workoutId: workout.id!)
        let rowsWE = entries[2].1
        let exerciseId = rowsWE.exerciseId

        let s1 = try Queries.insertSession(
            db, type: .a, date: "2026-02-18",
            startedAt: "2026-02-18T08:00:00", durationSeconds: 2400
        )
        let s2 = try Queries.insertSession(
            db, type: .a, date: "2026-02-22",
            startedAt: "2026-02-22T08:00:00", durationSeconds: 2400
        )
        try Queries.insertExerciseLogs(db, sessionId: s1.id!, logs: [
            ExerciseLog(sessionId: s1.id!, workoutExerciseId: rowsWE.id!, weight: 10.0)
        ])
        try Queries.insertExerciseLogs(db, sessionId: s2.id!, logs: [
            ExerciseLog(sessionId: s2.id!, workoutExerciseId: rowsWE.id!, weight: 12.5)
        ])

        let history = try Queries.weightHistory(db, exerciseId: exerciseId)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].date, "2026-02-18")
        XCTAssertEqual(history[0].weight, 10.0)
        XCTAssertEqual(history[1].date, "2026-02-22")
        XCTAssertEqual(history[1].weight, 12.5)
    }

    func testWeightHistoryIgnoresNilWeight() throws {
        let workout = try Queries.workoutByName(db, name: "Day A")!
        let entries = try Queries.exercisesForWorkout(db, workoutId: workout.id!)
        let warmupWE = entries[0].1
        let exerciseId = warmupWE.exerciseId

        let session = try Queries.insertSession(
            db, type: .a, date: "2026-02-20",
            startedAt: "2026-02-20T08:00:00", durationSeconds: 2400
        )
        try Queries.insertExerciseLogs(db, sessionId: session.id!, logs: [
            ExerciseLog(sessionId: session.id!, workoutExerciseId: warmupWE.id!, weight: nil)
        ])

        let history = try Queries.weightHistory(db, exerciseId: exerciseId)
        XCTAssertTrue(history.isEmpty)
    }

    // MARK: - Exercises With Weight Logs

    func testExercisesWithWeightLogsEmptyInitially() throws {
        let exercises = try Queries.exercisesWithWeightLogs(db)
        XCTAssertTrue(exercises.isEmpty)
    }

    func testExercisesWithWeightLogsAfterLogging() throws {
        let workout = try Queries.workoutByName(db, name: "Day A")!
        let entries = try Queries.exercisesForWorkout(db, workoutId: workout.id!)
        let rowsWE = entries[2].1
        let chestWE = entries[3].1

        let session = try Queries.insertSession(
            db, type: .a, date: "2026-02-20",
            startedAt: "2026-02-20T08:00:00", durationSeconds: 2400
        )
        try Queries.insertExerciseLogs(db, sessionId: session.id!, logs: [
            ExerciseLog(sessionId: session.id!, workoutExerciseId: rowsWE.id!, weight: 10.0),
            ExerciseLog(sessionId: session.id!, workoutExerciseId: chestWE.id!, weight: 15.0),
        ])

        let exercises = try Queries.exercisesWithWeightLogs(db)
        XCTAssertEqual(exercises.count, 2)
        // Verify ordered by name
        XCTAssertEqual(exercises.map(\.name), exercises.map(\.name).sorted())
    }

    func testExercisesWithWeightLogsExcludesNilWeight() throws {
        let workout = try Queries.workoutByName(db, name: "Day A")!
        let entries = try Queries.exercisesForWorkout(db, workoutId: workout.id!)
        let warmupWE = entries[0].1

        let session = try Queries.insertSession(
            db, type: .a, date: "2026-02-20",
            startedAt: "2026-02-20T08:00:00", durationSeconds: 2400
        )
        try Queries.insertExerciseLogs(db, sessionId: session.id!, logs: [
            ExerciseLog(sessionId: session.id!, workoutExerciseId: warmupWE.id!, weight: nil)
        ])

        let exercises = try Queries.exercisesWithWeightLogs(db)
        XCTAssertTrue(exercises.isEmpty)
    }

    func testExercisesWithWeightLogsDeduplicatesAcrossWorkouts() throws {
        // Dumbbell Rows appears in Day A and Day C — should only count once
        let dayA = try Queries.workoutByName(db, name: "Day A")!
        let dayAEntries = try Queries.exercisesForWorkout(db, workoutId: dayA.id!)
        let dayARowsWE = dayAEntries[2].1

        let dayC = try Queries.workoutByName(db, name: "Day C")!
        let dayCEntries = try Queries.exercisesForWorkout(db, workoutId: dayC.id!)
        let dayCRowsWE = dayCEntries[2].1

        let s1 = try Queries.insertSession(
            db, type: .a, date: "2026-02-20",
            startedAt: "2026-02-20T08:00:00", durationSeconds: 2400
        )
        let s2 = try Queries.insertSession(
            db, type: .c, date: "2026-02-22",
            startedAt: "2026-02-22T08:00:00", durationSeconds: 2400
        )
        try Queries.insertExerciseLogs(db, sessionId: s1.id!, logs: [
            ExerciseLog(sessionId: s1.id!, workoutExerciseId: dayARowsWE.id!, weight: 10.0)
        ])
        try Queries.insertExerciseLogs(db, sessionId: s2.id!, logs: [
            ExerciseLog(sessionId: s2.id!, workoutExerciseId: dayCRowsWE.id!, weight: 12.0)
        ])

        let exercises = try Queries.exercisesWithWeightLogs(db)
        // Same exercise logged across two workouts — deduplicated to 1
        XCTAssertEqual(exercises.count, 1)
    }

    // MARK: - Session Counts By Period

    func testSessionCountsByPeriodEmptyWhenNoSessions() throws {
        let counts = try Queries.sessionCountsByPeriod(db, granularity: .weekly)
        XCTAssertTrue(counts.isEmpty)
    }

    func testSessionCountsByPeriodWeekly() throws {
        // Feb 23–24 are in the same week; Mar 2 is the following Monday
        try Queries.insertSession(db, type: .a, date: "2026-02-23", startedAt: "2026-02-23T08:00:00", durationSeconds: 2400)
        try Queries.insertSession(db, type: .b, date: "2026-02-24", startedAt: "2026-02-24T08:00:00", durationSeconds: 2400)
        try Queries.insertSession(db, type: .c, date: "2026-03-02", startedAt: "2026-03-02T08:00:00", durationSeconds: 2400)

        let counts = try Queries.sessionCountsByPeriod(db, granularity: .weekly)
        XCTAssertEqual(counts.count, 2)
        XCTAssertEqual(counts[0].count, 2)
        XCTAssertEqual(counts[1].count, 1)
    }

    func testSessionCountsByPeriodMonthly() throws {
        try Queries.insertSession(db, type: .a, date: "2026-02-20", startedAt: "2026-02-20T08:00:00", durationSeconds: 2400)
        try Queries.insertSession(db, type: .b, date: "2026-02-21", startedAt: "2026-02-21T08:00:00", durationSeconds: 2400)
        try Queries.insertSession(db, type: .c, date: "2026-03-01", startedAt: "2026-03-01T08:00:00", durationSeconds: 2400)

        let counts = try Queries.sessionCountsByPeriod(db, granularity: .monthly)
        XCTAssertEqual(counts.count, 2)
        XCTAssertEqual(counts[0].count, 2)
        XCTAssertEqual(counts[1].count, 1)
    }

    func testSessionCountsByPeriodExcludesPartialSessions() throws {
        try Queries.insertSession(db, type: .a, date: "2026-02-20", startedAt: "2026-02-20T08:00:00", durationSeconds: 2400)
        try Queries.insertSession(db, type: .b, date: "2026-02-21", startedAt: "2026-02-21T08:00:00", durationSeconds: 2400, isPartial: true)

        let counts = try Queries.sessionCountsByPeriod(db, granularity: .weekly)
        XCTAssertEqual(counts.count, 1)
        XCTAssertEqual(counts[0].count, 1)
    }

    func testSessionCountsDominantType() throws {
        // Two type A, one type B in the same week
        try Queries.insertSession(db, type: .a, date: "2026-02-23", startedAt: "2026-02-23T08:00:00", durationSeconds: 2400)
        try Queries.insertSession(db, type: .a, date: "2026-02-24", startedAt: "2026-02-24T08:00:00", durationSeconds: 2400)
        try Queries.insertSession(db, type: .b, date: "2026-02-25", startedAt: "2026-02-25T08:00:00", durationSeconds: 2400)

        let counts = try Queries.sessionCountsByPeriod(db, granularity: .weekly)
        XCTAssertEqual(counts.count, 1)
        XCTAssertEqual(counts[0].dominantType, .a)
    }

    // MARK: - Personal Bests

    func testPersonalBestsEmptyDatabase() throws {
        let bests = try Queries.personalBests(db)
        XCTAssertNil(bests.heaviestLift)
        XCTAssertEqual(bests.longestSessionStreak, 0)
        XCTAssertEqual(bests.longestChallengeStreak, 0)
        XCTAssertEqual(bests.mostSessionsInWeek, 0)
    }

    func testPersonalBestsHeaviestLift() throws {
        let workout = try Queries.workoutByName(db, name: "Day A")!
        let entries = try Queries.exercisesForWorkout(db, workoutId: workout.id!)
        let rowsWE = entries[2].1
        let chestWE = entries[3].1

        let session = try Queries.insertSession(
            db, type: .a, date: "2026-02-20",
            startedAt: "2026-02-20T08:00:00", durationSeconds: 2400
        )
        try Queries.insertExerciseLogs(db, sessionId: session.id!, logs: [
            ExerciseLog(sessionId: session.id!, workoutExerciseId: rowsWE.id!, weight: 10.0),
            ExerciseLog(sessionId: session.id!, workoutExerciseId: chestWE.id!, weight: 20.0),
        ])

        let bests = try Queries.personalBests(db)
        XCTAssertNotNil(bests.heaviestLift)
        XCTAssertEqual(bests.heaviestLift?.weight, 20.0)
    }

    func testPersonalBestsMostSessionsInWeek() throws {
        // 3 sessions in one week
        try Queries.insertSession(db, type: .a, date: "2026-02-23", startedAt: "2026-02-23T08:00:00", durationSeconds: 2400)
        try Queries.insertSession(db, type: .b, date: "2026-02-24", startedAt: "2026-02-24T08:00:00", durationSeconds: 2400)
        try Queries.insertSession(db, type: .c, date: "2026-02-25", startedAt: "2026-02-25T08:00:00", durationSeconds: 2400)
        // 1 session in another week
        try Queries.insertSession(db, type: .a, date: "2026-03-02", startedAt: "2026-03-02T08:00:00", durationSeconds: 2400)

        let bests = try Queries.personalBests(db)
        XCTAssertEqual(bests.mostSessionsInWeek, 3)
    }

    // MARK: - Challenge History

    func testChallengeHistoryEmptyYear() throws {
        let history = try Queries.challengeHistory(db, year: 2026)
        XCTAssertTrue(history.isEmpty)
    }

    func testChallengeHistoryForYear() throws {
        try Queries.upsertChallenge(db, date: "2026-02-20", setsCompleted: 3)
        try Queries.upsertChallenge(db, date: "2026-02-21", setsCompleted: 1)
        try Queries.upsertChallenge(db, date: "2026-02-22", setsCompleted: 0)   // zero excluded
        try Queries.upsertChallenge(db, date: "2025-12-31", setsCompleted: 3)   // wrong year excluded

        let history = try Queries.challengeHistory(db, year: 2026)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history["2026-02-20"], 3)
        XCTAssertEqual(history["2026-02-21"], 1)
        XCTAssertNil(history["2026-02-22"])
        XCTAssertNil(history["2025-12-31"])
    }
}
