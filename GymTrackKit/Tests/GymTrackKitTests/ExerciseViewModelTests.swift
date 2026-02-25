import XCTest
@testable import GymTrackKit

final class ExerciseViewModelTests: XCTestCase {
    private var db: AppDatabase!

    override func setUp() async throws {
        db = try AppDatabase.empty()
    }

    func testInitializesWithCorrectExercises() throws {
        let vm = ExerciseViewModel(database: db, sessionType: .a)
        let exercises = try WorkoutPlan.exercises(for: .a, database: db)
        XCTAssertEqual(vm.exercises.count, exercises.count)
        XCTAssertEqual(vm.completedSteps.count, 0)
    }

    func testMarkStepCompleted() {
        let vm = ExerciseViewModel(database: db, sessionType: .a)
        let firstExercise = vm.exercises[0]
        vm.markStepCompleted(firstExercise.id)

        XCTAssertTrue(vm.completedSteps.contains(firstExercise.id))
    }

    func testCompletionPercentage() {
        let vm = ExerciseViewModel(database: db, sessionType: .a)
        XCTAssertEqual(vm.completionPercentage, 0.0)

        for exercise in vm.exercises {
            vm.markStepCompleted(exercise.id)
        }
        XCTAssertEqual(vm.completionPercentage, 1.0, accuracy: 0.01)
    }

    func testIsPartialSessionWhenLessThanHalf() {
        let vm = ExerciseViewModel(database: db, sessionType: .a)
        XCTAssertTrue(vm.isPartialSession)

        // Complete less than 50%
        vm.markStepCompleted(vm.exercises[0].id)
        XCTAssertTrue(vm.isPartialSession)
    }

    func testIsNotPartialWhenHalfOrMoreCompleted() {
        let vm = ExerciseViewModel(database: db, sessionType: .a)
        let halfCount = vm.exercises.count / 2 + 1
        for i in 0..<halfCount {
            vm.markStepCompleted(vm.exercises[i].id)
        }
        XCTAssertFalse(vm.isPartialSession)
    }

    func testFinishWorkoutLogsSession() throws {
        let vm = ExerciseViewModel(database: db, sessionType: .b)
        for exercise in vm.exercises {
            vm.markStepCompleted(exercise.id)
        }

        vm.finishWorkout(feedback: .ok)

        let session = try Queries.lastSession(db)
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.sessionType, "B")
        XCTAssertFalse(session?.isPartial ?? true)
        XCTAssertEqual(session?.feedback, "ok")
    }

    func testFinishPartialWorkoutSetsPartialFlag() throws {
        let vm = ExerciseViewModel(database: db, sessionType: .c)
        // Complete only one step (less than 50%)
        vm.markStepCompleted(vm.exercises[0].id)

        vm.finishWorkout(feedback: .hard)

        let session = try Queries.lastSession(db)
        XCTAssertNotNil(session)
        XCTAssertTrue(session?.isPartial ?? false)
        XCTAssertEqual(session?.feedback, "hard")
    }

    func testWeightPreFillFromHistory() throws {
        // First workout: set weights for weight exercises
        let vm1 = ExerciseViewModel(database: db, sessionType: .a)
        let weightExercise = vm1.exercises.first { $0.hasWeight }!
        vm1.setWeight(weightExercise.id, weight: 14.0)
        for exercise in vm1.exercises {
            vm1.markStepCompleted(exercise.id)
        }
        vm1.finishWorkout(feedback: .ok)

        // Second workout: weights should be pre-filled
        let vm2 = ExerciseViewModel(database: db, sessionType: .a)
        let entry = vm2.exerciseLogs[weightExercise.id]
        XCTAssertEqual(entry?.weight, 14.0)
    }

    func testSetWeight() {
        let vm = ExerciseViewModel(database: db, sessionType: .a)
        let exercise = vm.exercises.first { $0.hasWeight }!
        vm.setWeight(exercise.id, weight: 20.0)
        XCTAssertEqual(vm.exerciseLogs[exercise.id]?.weight, 20.0)
    }

    func testMarkFailedAndClear() {
        let vm = ExerciseViewModel(database: db, sessionType: .a)
        let exercise = vm.exercises[0]

        vm.markFailed(exercise.id, achievedValue: 7)
        XCTAssertTrue(vm.exerciseLogs[exercise.id]?.failed ?? false)
        XCTAssertEqual(vm.exerciseLogs[exercise.id]?.achievedValue, 7)
        XCTAssertTrue(vm.hasAnyFailure)

        vm.clearFailure(exercise.id)
        XCTAssertFalse(vm.exerciseLogs[exercise.id]?.failed ?? true)
        XCTAssertNil(vm.exerciseLogs[exercise.id]?.achievedValue)
        XCTAssertFalse(vm.hasAnyFailure)
    }

    func testDefaultFeedbackBasedOnFailures() {
        let vm = ExerciseViewModel(database: db, sessionType: .a)
        XCTAssertEqual(vm.defaultFeedback, .ok)

        vm.markFailed(vm.exercises[0].id, achievedValue: nil)
        XCTAssertEqual(vm.defaultFeedback, .hard)
    }

    func testAbortWorkoutDoesNotLogSession() throws {
        let vm = ExerciseViewModel(database: db, sessionType: .a)
        vm.startTimer()
        vm.abortWorkout()

        let session = try Queries.lastSession(db)
        XCTAssertNil(session)
    }

    func testDailyChallengeStepIncrementsChallengeCounter() throws {
        let vm = ExerciseViewModel(database: db, sessionType: .a)
        let challengeStep = vm.exercises.first { $0.isDailyChallenge }!

        vm.markStepCompleted(challengeStep.id)

        let today = DateHelpers.dateString(from: Date())
        let challenge = try Queries.challengeForDate(db, date: today)
        XCTAssertEqual(challenge?.setsCompleted, 1)
    }
}
