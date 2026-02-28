import Foundation
import Combine

public enum StatsSection: String, CaseIterable {
    case weightProgression = "weight"
    case sessionFrequency  = "frequency"
    case personalBests     = "bests"
    case challengeHeatmap  = "heatmap"
}

public final class StatsViewModel: ObservableObject {
    @Published public var weightHistory: [(date: String, weight: Double)] = []
    @Published public var availableExercises: [ExerciseRecord] = []
    @Published public var selectedExerciseId: Int64? = nil

    @Published public var sessionCounts: [SessionCountBucket] = []
    @Published public var granularity: Granularity = .weekly

    @Published public var personalBests: PersonalBests? = nil

    @Published public var challengeGrid: [String: Int] = [:]

    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func refresh() {
        loadAvailableExercises()
        loadSessionFrequency()
        loadPersonalBests()
        let year = Calendar.current.component(.year, from: Date())
        loadChallengeHeatmap(year: year)
    }

    public func loadAvailableExercises() {
        do {
            availableExercises = try Queries.exercisesWithWeightLogs(database)
            if selectedExerciseId == nil {
                selectedExerciseId = availableExercises.first?.id
            }
            loadWeightHistory()
        } catch {}
    }

    public func loadWeightHistory() {
        guard let id = selectedExerciseId else {
            weightHistory = []
            return
        }
        do {
            weightHistory = try Queries.weightHistory(database, exerciseId: id)
        } catch {}
    }

    public func loadSessionFrequency() {
        do {
            sessionCounts = try Queries.sessionCountsByPeriod(database, granularity: granularity)
        } catch {}
    }

    public func loadPersonalBests() {
        do {
            personalBests = try Queries.personalBests(database)
        } catch {}
    }

    public func loadChallengeHeatmap(year: Int) {
        do {
            challengeGrid = try Queries.challengeHistory(database, year: year)
        } catch {}
    }
}
