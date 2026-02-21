import Foundation
import Combine

public final class ExerciseViewModel: ObservableObject {
    private let database: AppDatabase
    public let sessionType: SessionType
    public let exercises: [Exercise]
    private let startTime: Date

    @Published public var completedSteps: Set<String> = []
    @Published public var elapsedSeconds: Int = 0

    private var timer: Timer?

    public init(database: AppDatabase, sessionType: SessionType) {
        self.database = database
        self.sessionType = sessionType
        self.exercises = WorkoutPlan.exercises(for: sessionType)
        self.startTime = Date()
    }

    public var completionPercentage: Double {
        guard !exercises.isEmpty else { return 0 }
        return Double(completedSteps.count) / Double(exercises.count)
    }

    public var isPartialSession: Bool {
        completionPercentage < 0.5
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

    public func finishWorkout() {
        stopTimer()
        let duration = Int(Date().timeIntervalSince(startTime))
        let today = DateHelpers.dateString(from: Date())
        let startedAtStr = DateHelpers.dateTimeString(from: startTime)

        do {
            try Queries.insertSession(
                database,
                type: sessionType,
                date: today,
                startedAt: startedAtStr,
                durationSeconds: duration,
                isPartial: isPartialSession
            )
        } catch {}
    }

    deinit {
        timer?.invalidate()
    }
}
