import Foundation
import GRDB

public final class AppDatabase {
    public let dbWriter: any DatabaseWriter

    public init(_ dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "session") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sessionType", .text).notNull()
                t.column("date", .text).notNull()
                t.column("startedAt", .text).notNull()
                t.column("durationSeconds", .integer).notNull()
                t.column("isPartial", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "dailyChallenge") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("date", .text).notNull().unique()
                t.column("setsCompleted", .integer).notNull().defaults(to: 0)
            }
        }

        migrator.registerMigration("v2") { db in
            try db.create(table: "exercise") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("description", .text).notNull().defaults(to: "")
                t.column("advice", .text).notNull().defaults(to: "")
                t.column("counterUnit", .text).notNull()
                t.column("defaultValue", .integer).notNull()
                t.column("isDailyChallenge", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "workout") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("description", .text).notNull().defaults(to: "")
            }

            try db.create(table: "workoutExercise") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("workoutId", .integer).notNull()
                    .references("workout", onDelete: .cascade)
                t.column("exerciseId", .integer).notNull()
                    .references("exercise", onDelete: .cascade)
                t.column("position", .integer).notNull()
                t.column("counterValue", .integer)
                t.column("counterLabel", .text)
                t.column("restSeconds", .integer).notNull().defaults(to: 30)
                t.column("sets", .integer).notNull().defaults(to: 1)
                t.uniqueKey(["workoutId", "position"])
            }

            // Seed from bundled JSON
            let exercises = try AppDatabase.loadSeedExercises()
            let workouts = try AppDatabase.loadSeedWorkouts()

            // Derive per-exercise programming defaults from the first workout-exercise entry
            var exerciseDefaults: [String: (counterUnit: String, defaultValue: Int, isDailyChallenge: Bool)] = [:]
            for workout in workouts {
                for entry in workout.exercises {
                    if exerciseDefaults[entry.exerciseName] == nil {
                        exerciseDefaults[entry.exerciseName] = (entry.counterUnit, entry.counterValue, entry.isDailyChallenge)
                    }
                }
            }

            for e in exercises {
                let defaults = exerciseDefaults[e.name] ?? (counterUnit: "reps", defaultValue: 10, isDailyChallenge: false)
                try db.execute(
                    sql: """
                        INSERT INTO exercise (name, description, advice, counterUnit, defaultValue, isDailyChallenge)
                        VALUES (?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [e.name, "", e.tip, defaults.counterUnit, defaults.defaultValue, defaults.isDailyChallenge]
                )
            }

            // Build name→id lookup
            let rows = try Row.fetchAll(db, sql: "SELECT id, name FROM exercise")
            var exerciseIdByName: [String: Int64] = [:]
            for row in rows {
                exerciseIdByName[row["name"]] = row["id"]
            }

            for workout in workouts {
                try db.execute(
                    sql: "INSERT INTO workout (name, description) VALUES (?, ?)",
                    arguments: [workout.name, workout.description]
                )
                let workoutId = db.lastInsertedRowID

                for entry in workout.exercises {
                    guard let exerciseId = exerciseIdByName[entry.exerciseName] else {
                        continue
                    }
                    try db.execute(
                        sql: """
                            INSERT INTO workoutExercise (workoutId, exerciseId, position, counterValue, counterLabel, restSeconds, sets)
                            VALUES (?, ?, ?, ?, ?, ?, ?)
                            """,
                        arguments: [workoutId, exerciseId, entry.position, entry.counterValue, entry.counterLabel, entry.restSeconds, entry.sets]
                    )
                }
            }
        }

        migrator.registerMigration("v3") { db in
            try db.alter(table: "exercise") { t in
                t.add(column: "hasWeight", .boolean).notNull().defaults(to: false)
            }
            try db.execute(sql: "UPDATE exercise SET hasWeight = 1 WHERE id IN (3, 4, 5, 6)")

            try db.alter(table: "session") { t in
                t.add(column: "feedback", .text)
            }

            try db.create(table: "exerciseLog") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sessionId", .integer).notNull()
                    .references("session", onDelete: .cascade)
                t.column("workoutExerciseId", .integer).notNull()
                    .references("workoutExercise", onDelete: .cascade)
                t.column("weight", .double)
                t.column("failed", .integer).notNull().defaults(to: 0)
                t.column("achievedValue", .integer)
                t.uniqueKey(["sessionId", "workoutExerciseId"])
            }
        }

        migrator.registerMigration("v4") { db in
            // 1. Add programming fields to workoutExercise
            try db.alter(table: "workoutExercise") { t in
                t.add(column: "counterUnit", .text).notNull().defaults(to: "reps")
                t.add(column: "isDailyChallenge", .boolean).notNull().defaults(to: false)
                t.add(column: "hasWeight", .boolean).notNull().defaults(to: false)
            }

            // 2. Populate from joined exercise data
            try db.execute(sql: """
                UPDATE workoutExercise SET
                  counterUnit = (SELECT counterUnit FROM exercise WHERE exercise.id = workoutExercise.exerciseId),
                  isDailyChallenge = (SELECT isDailyChallenge FROM exercise WHERE exercise.id = workoutExercise.exerciseId),
                  hasWeight = (SELECT hasWeight FROM exercise WHERE exercise.id = workoutExercise.exerciseId)
                """)

            // 3. Fill NULL counterValue from exercise defaults
            try db.execute(sql: """
                UPDATE workoutExercise SET
                  counterValue = (SELECT defaultValue FROM exercise WHERE exercise.id = workoutExercise.exerciseId)
                  WHERE counterValue IS NULL
                """)

            // 4. Add catalog columns to exercise
            try db.alter(table: "exercise") { t in
                t.add(column: "externalId", .text)
                t.add(column: "instructions", .text).notNull().defaults(to: "")
                t.add(column: "level", .text)
                t.add(column: "category", .text)
                t.add(column: "force", .text)
                t.add(column: "mechanic", .text)
                t.add(column: "equipment", .text)
                t.add(column: "primaryMuscles", .text)
                t.add(column: "secondaryMuscles", .text)
            }

            // 5. Copy advice → instructions
            try db.execute(sql: "UPDATE exercise SET instructions = advice")
        }

        migrator.registerMigration("v5") { db in
            try db.alter(table: "exercise") { t in
                t.add(column: "tip", .text).notNull().defaults(to: "")
            }
            // Existing instructions column holds the short coaching cue (via advice → instructions in v4)
            try db.execute(sql: "UPDATE exercise SET tip = instructions")
        }

        migrator.registerMigration("v6") { db in
            let columns = try db.columns(in: "workoutExercise").map(\.name)
            if !columns.contains("isActive") {
                try db.alter(table: "workoutExercise") { t in
                    t.add(column: "isActive", .boolean).notNull().defaults(to: true)
                }
            }
        }

        return migrator
    }

    /// In-memory database for testing
    public static func empty() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(configuration: Configuration())
        return try AppDatabase(dbQueue)
    }

    // MARK: - Seed Data Loading

    struct SeedExercise: Decodable {
        let id: String
        let name: String
        let tip: String
        let instructions: [String]
        let hasWeight: Bool
        let level: String?
        let category: String?
        let force: String?
        let mechanic: String?
        let equipment: String?
        let primaryMuscles: [String]?
        let secondaryMuscles: [String]?
    }

    struct SeedWorkoutExercise: Decodable {
        let exerciseName: String
        let position: Int
        let counterUnit: String
        let counterValue: Int
        let counterLabel: String?
        let restSeconds: Int
        let sets: Int
        let isDailyChallenge: Bool
        let hasWeight: Bool
    }

    struct SeedWorkout: Decodable {
        let name: String
        let description: String
        let exercises: [SeedWorkoutExercise]
    }

    static func loadSeedExercises() throws -> [SeedExercise] {
        guard let url = Bundle.module.url(forResource: "seed-exercises", withExtension: "json") else {
            throw DatabaseError(message: "seed-exercises.json not found in bundle")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([SeedExercise].self, from: data)
    }

    static func loadSeedWorkouts() throws -> [SeedWorkout] {
        guard let url = Bundle.module.url(forResource: "seed-workouts", withExtension: "json") else {
            throw DatabaseError(message: "seed-workouts.json not found in bundle")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([SeedWorkout].self, from: data)
    }
}

struct DatabaseError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
