import XCTest
@testable import GymTrackKit

final class ExerciseViewModelTests: XCTestCase {
    private var db: AppDatabase!

    override func setUp() async throws {
        db = try AppDatabase.empty()
    }

    func testInitializesWithCorrectExercises() {
        let vm = ExerciseViewModel(database: db, sessionType: .a)
        let exercises = WorkoutPlan.exercises(for: .a)
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

        vm.finishWorkout()

        let session = try Queries.lastSession(db)
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.sessionType, "B")
        XCTAssertFalse(session?.isPartial ?? true)
    }

    func testFinishPartialWorkoutSetsPartialFlag() throws {
        let vm = ExerciseViewModel(database: db, sessionType: .c)
        // Complete only one step (less than 50%)
        vm.markStepCompleted(vm.exercises[0].id)

        vm.finishWorkout()

        let session = try Queries.lastSession(db)
        XCTAssertNotNil(session)
        XCTAssertTrue(session?.isPartial ?? false)
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
