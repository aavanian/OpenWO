import Foundation
import Combine

public struct ExerciseLogEntry {
    public var weight: Double?
    public var failed: Bool = false
    public var achievedValue: Int? = nil

    public init(weight: Double? = nil, failed: Bool = false, achievedValue: Int? = nil) {
        self.weight = weight
        self.failed = failed
        self.achievedValue = achievedValue
    }
}

public final class ExerciseViewModel: ObservableObject {
    private let database: AppDatabase
    public let sessionType: SessionType
    public let exercises: [Exercise]
    private let startTime: Date
    private let workoutId: Int64?

    @Published public var completedSteps: Set<String> = []
    @Published public var elapsedSeconds: Int = 0
    @Published public var exerciseLogs: [String: ExerciseLogEntry] = [:]

    private var timer: Timer?

    public init(database: AppDatabase, sessionType: SessionType) {
        self.database = database
        self.sessionType = sessionType
        self.exercises = (try? WorkoutPlan.exercises(for: sessionType, database: database)) ?? []
        self.startTime = Date()

        let wId = try? Queries.workoutByName(database, name: sessionType.workoutName)?.id
        self.workoutId = wId

        // Pre-fill weights from history
        if let workoutId = wId {
            let lastWeights = (try? Queries.lastWeights(database, forWorkoutId: workoutId)) ?? [:]
            for exercise in exercises where exercise.hasWeight {
                var entry = ExerciseLogEntry()
                if let weight = lastWeights[exercise.workoutExerciseId] {
                    entry.weight = weight
                }
                exerciseLogs[exercise.id] = entry
            }
        }
    }

    public var completionPercentage: Double {
        guard !exercises.isEmpty else { return 0 }
        return Double(completedSteps.count) / Double(exercises.count)
    }

    public var isPartialSession: Bool {
        completionPercentage < 0.5
    }

    public var hasAnyFailure: Bool {
        exerciseLogs.values.contains { $0.failed }
    }

    public var defaultFeedback: WorkoutFeedback {
        hasAnyFailure ? .hard : .ok
    }

    public func setWeight(_ exerciseId: String, weight: Double?) {
        var entry = exerciseLogs[exerciseId] ?? ExerciseLogEntry()
        entry.weight = weight
        exerciseLogs[exerciseId] = entry
    }

    public func markFailed(_ exerciseId: String, achievedValue: Int?) {
        var entry = exerciseLogs[exerciseId] ?? ExerciseLogEntry()
        entry.failed = true
        entry.achievedValue = achievedValue
        exerciseLogs[exerciseId] = entry
    }

    public func clearFailure(_ exerciseId: String) {
        var entry = exerciseLogs[exerciseId] ?? ExerciseLogEntry()
        entry.failed = false
        entry.achievedValue = nil
        exerciseLogs[exerciseId] = entry
    }

    public func markStepCompleted(_ exerciseId: String) {
        completedSteps.insert(exerciseId)

        // Auto-increment daily challenge when challenge step is completed
        if let exercise = exercises.first(where: { $0.id == exerciseId }),
           exercise.isDailyChallenge {
            do {
                let today = DateHelpers.dateString(from: Date())
                try Queries.incrementChallenge(database, date: today)
            } catch {}
        }
    }

    public func markStepIncomplete(_ exerciseId: String) {
        completedSteps.remove(exerciseId)
    }

    public func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsedSeconds = Int(Date().timeIntervalSince(self.startTime))
        }
    }

    public func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    public func abortWorkout() {
        stopTimer()
    }

    public func finishWorkout(feedback: WorkoutFeedback) {
        stopTimer()
        let duration = Int(Date().timeIntervalSince(startTime))
        let today = DateHelpers.dateString(from: Date())
        let startedAtStr = DateHelpers.dateTimeString(from: startTime)

        do {
            let session = try Queries.insertSession(
                database,
                type: sessionType,
                date: today,
                startedAt: startedAtStr,
                durationSeconds: duration,
                isPartial: isPartialSession,
                feedback: feedback
            )

            // Build exercise logs for exercises that have data
            var logs: [ExerciseLog] = []
            for exercise in exercises {
                guard let entry = exerciseLogs[exercise.id],
                      entry.weight != nil || entry.failed else { continue }
                logs.append(ExerciseLog(
                    sessionId: session.id!,
                    workoutExerciseId: exercise.workoutExerciseId,
                    weight: entry.weight,
                    failed: entry.failed,
                    achievedValue: entry.achievedValue
                ))
            }
            if !logs.isEmpty {
                try Queries.insertExerciseLogs(database, sessionId: session.id!, logs: logs)
            }
        } catch {}
    }

    deinit {
        timer?.invalidate()
    }
}
