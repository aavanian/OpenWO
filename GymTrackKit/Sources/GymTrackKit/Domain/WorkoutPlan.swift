import Foundation

public enum WorkoutPlan {
    /// Load exercises for a session type from the database.
    public static func exercises(for sessionType: SessionType, database: AppDatabase) throws -> [Exercise] {
        guard let workout = try Queries.workoutByName(database, name: sessionType.workoutName) else {
            return []
        }
        guard let workoutId = workout.id else { return [] }
        let rows = try Queries.exercisesForWorkout(database, workoutId: workoutId)
        return rows.map { record, we in
            let value = we.counterValue ?? record.defaultValue
            let repsLabel = we.counterLabel ?? Self.formatCounter(unit: record.counterUnit, value: value)
            return Exercise(
                id: "\(we.workoutId)-\(we.position)",
                name: record.name,
                instruction: record.advice,
                sets: we.sets > 1 ? we.sets : nil,
                reps: repsLabel,
                isDailyChallenge: record.isDailyChallenge,
                isTimed: record.isTimed,
                hasWeight: record.hasWeight,
                workoutExerciseId: we.id!,
                counterSeconds: record.isTimed ? value : nil
            )
        }
    }

    /// Format a counter value + unit into a human-readable label.
    static func formatCounter(unit: String, value: Int) -> String {
        if unit == "timer" {
            if value >= 60 && value % 60 == 0 {
                let mins = value / 60
                return "\(mins) min"
            } else {
                return "\(value) sec"
            }
        } else {
            return "\(value) reps"
        }
    }
}
