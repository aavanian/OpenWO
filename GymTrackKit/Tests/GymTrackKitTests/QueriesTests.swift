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

    // MARK: - Session Feedback

    func testInsertSessionWithFeedback() throws {
        let session = try Queries.insertSession(
            db,
            type: .a,
            date: "2026-02-25",
            startedAt: "2026-02-25T08:00:00",
            durationSeconds: 2400,
            feedback: .hard
        )
        XCTAssertEqual(session.feedback, "hard")

        let fetched = try Queries.lastSession(db)
        XCTAssertEqual(fetched?.feedback, "hard")
    }

    func testInsertSessionWithoutFeedback() throws {
        let session = try Queries.insertSession(
            db,
            type: .b,
            date: "2026-02-25",
            startedAt: "2026-02-25T08:00:00",
            durationSeconds: 2400
        )
        XCTAssertNil(session.feedback)
    }

    // MARK: - Exercise Logs

    func testInsertExerciseLogs() throws {
        let session = try Queries.insertSession(
            db,
            type: .a,
            date: "2026-02-25",
            startedAt: "2026-02-25T08:00:00",
            durationSeconds: 2400
        )

        let workout = try Queries.workoutByName(db, name: "Day A")!
        let entries = try Queries.exercisesForWorkout(db, workoutId: workout.id!)
        let rowsExercise = entries[2] // Dumbbell rows, workoutExercise position 2

        let logs = [
            ExerciseLog(
                sessionId: session.id!,
                workoutExerciseId: rowsExercise.1.id!,
                weight: 12.5,
                failed: false
            )
        ]
        try Queries.insertExerciseLogs(db, sessionId: session.id!, logs: logs)

        let count = try db.dbWriter.read { dbConn in
            try Int.fetchOne(dbConn, sql: "SELECT COUNT(*) FROM exerciseLog")
        }
        XCTAssertEqual(count, 1)
    }

    func testLastWeightsReturnsCorrectValues() throws {
        let workout = try Queries.workoutByName(db, name: "Day A")!
        let entries = try Queries.exercisesForWorkout(db, workoutId: workout.id!)
        let rowsWE = entries[2].1 // Dumbbell rows
        let chestWE = entries[3].1 // Chest press

        // Session 1 with weights
        let s1 = try Queries.insertSession(
            db, type: .a, date: "2026-02-20",
            startedAt: "2026-02-20T08:00:00", durationSeconds: 2400
        )
        try Queries.insertExerciseLogs(db, sessionId: s1.id!, logs: [
            ExerciseLog(sessionId: s1.id!, workoutExerciseId: rowsWE.id!, weight: 10.0),
            ExerciseLog(sessionId: s1.id!, workoutExerciseId: chestWE.id!, weight: 15.0),
        ])

        // Session 2 with updated weight for rows only
        let s2 = try Queries.insertSession(
            db, type: .a, date: "2026-02-22",
            startedAt: "2026-02-22T08:00:00", durationSeconds: 2400
        )
        try Queries.insertExerciseLogs(db, sessionId: s2.id!, logs: [
            ExerciseLog(sessionId: s2.id!, workoutExerciseId: rowsWE.id!, weight: 12.5),
        ])

        let weights = try Queries.lastWeights(db, forWorkoutId: workout.id!)
        XCTAssertEqual(weights[rowsWE.id!], 12.5)
        XCTAssertEqual(weights[chestWE.id!], 15.0)
    }

    func testLastWeightsCarriesAcrossWorkouts() throws {
        // Log weight for Dumbbell rows (exerciseId=3) in Day A
        let dayA = try Queries.workoutByName(db, name: "Day A")!
        let dayAEntries = try Queries.exercisesForWorkout(db, workoutId: dayA.id!)
        let dayARowsWE = dayAEntries[2].1 // Dumbbell rows in Day A

        let s1 = try Queries.insertSession(
            db, type: .a, date: "2026-02-20",
            startedAt: "2026-02-20T08:00:00", durationSeconds: 2400
        )
        try Queries.insertExerciseLogs(db, sessionId: s1.id!, logs: [
            ExerciseLog(sessionId: s1.id!, workoutExerciseId: dayARowsWE.id!, weight: 14.0),
        ])

        // Query Day C — Dumbbell rows (same exerciseId=3) should get 14.0
        let dayC = try Queries.workoutByName(db, name: "Day C")!
        let dayCEntries = try Queries.exercisesForWorkout(db, workoutId: dayC.id!)
        let dayCRowsWE = dayCEntries[2].1 // Dumbbell rows in Day C

        let weights = try Queries.lastWeights(db, forWorkoutId: dayC.id!)
        XCTAssertEqual(weights[dayCRowsWE.id!], 14.0)
    }

    // MARK: - Workouts & Exercises

    func testAllWorkouts() throws {
        let workouts = try Queries.allWorkouts(db)
        XCTAssertEqual(workouts.count, 3)
    }

    func testWorkoutByName() throws {
        let workout = try Queries.workoutByName(db, name: "Day A")
        XCTAssertNotNil(workout)
        XCTAssertEqual(workout?.name, "Day A")

        let missing = try Queries.workoutByName(db, name: "Day Z")
        XCTAssertNil(missing)
    }

    func testExercisesForWorkout() throws {
        let workout = try Queries.workoutByName(db, name: "Day A")!
        let entries = try Queries.exercisesForWorkout(db, workoutId: workout.id!)
        XCTAssertEqual(entries.count, 9)

        // Verify ordering
        for (index, entry) in entries.enumerated() {
            XCTAssertEqual(entry.1.position, index)
        }

        // Verify first exercise is the warm-up
        XCTAssertEqual(entries[0].0.name, "Cardio warm-up (cycling)")
        XCTAssertEqual(entries[0].0.counterUnit, "timer")
    }

    func testExercisesForWorkoutDayB() throws {
        let workout = try Queries.workoutByName(db, name: "Day B")!
        let entries = try Queries.exercisesForWorkout(db, workoutId: workout.id!)
        XCTAssertEqual(entries.count, 7)
    }

    func testExercisesForWorkoutDayC() throws {
        let workout = try Queries.workoutByName(db, name: "Day C")!
        let entries = try Queries.exercisesForWorkout(db, workoutId: workout.id!)
        XCTAssertEqual(entries.count, 7)
    }

    func testWorkoutPlanExercisesFromDB() throws {
        let exercises = try WorkoutPlan.exercises(for: .a, database: db)
        XCTAssertEqual(exercises.count, 9)

        // Verify the first exercise maps correctly
        let warmup = exercises[0]
        XCTAssertEqual(warmup.name, "Cardio warm-up (cycling)")
        XCTAssertTrue(warmup.isTimed)
        XCTAssertEqual(warmup.reps, "10 min")

        // Verify a rep-based exercise
        let chestPress = exercises[3]
        XCTAssertEqual(chestPress.name, "Dumbbell chest press (push)")
        XCTAssertFalse(chestPress.isTimed)
        XCTAssertEqual(chestPress.sets, 4)
        XCTAssertEqual(chestPress.reps, "10 reps")

        // Verify daily challenge
        let challenge = exercises[1]
        XCTAssertTrue(challenge.isDailyChallenge)
        XCTAssertEqual(challenge.reps, "10 + 10 reps")
    }
}
