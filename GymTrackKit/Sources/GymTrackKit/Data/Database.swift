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

            // Seed exercises
            // IDs are assigned in insertion order: 1..12
            let exercises: [(name: String, desc: String, advice: String, unit: String, value: Int, challenge: Bool)] = [
                // 1
                ("Cardio warm-up (cycling)", "", "Easy pace, joints only", "timer", 600, false),
                // 2
                ("Daily Challenge — squats + push-ups", "", "Counts toward daily challenge", "reps", 20, true),
                // 3
                ("Dumbbell rows (pull)", "", "Elbow back and up, knee on bench", "reps", 10, false),
                // 4
                ("Dumbbell chest press (push)", "", "2–3 sec descent, slow is the work", "reps", 10, false),
                // 5
                ("Shoulder press (push)", "", "Go light — easy to strain when returning", "reps", 10, false),
                // 6
                ("Bicep curls (pull)", "", "No swinging, controlled", "reps", 10, false),
                // 7
                ("Plank", "", "Hips level", "timer", 45, false),
                // 8
                ("Dead bugs", "", "Lower back pressed into mat", "reps", 10, false),
                // 9
                ("Stretch", "", "Chest opener, lat, shoulder cross-body", "timer", 300, false),
                // 10
                ("Main cardio block (cycling)", "", "6–7/10 effort, steady pace", "timer", 1200, false),
                // 11
                ("Leg raises", "", "Bend knees if lower back lifts", "reps", 10, false),
                // 12
                ("Flexibility & mobility", "", "Hip flexor lunge stretch, seated hamstring stretch, chest opener on mat, figure-4 glute stretch", "timer", 600, false),
            ]

            for e in exercises {
                try db.execute(
                    sql: """
                        INSERT INTO exercise (name, description, advice, counterUnit, defaultValue, isDailyChallenge)
                        VALUES (?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [e.name, e.desc, e.advice, e.unit, e.value, e.challenge]
                )
            }

            // Seed workouts: Day A (id=1), Day B (id=2), Day C (id=3)
            try db.execute(sql: "INSERT INTO workout (name, description) VALUES ('Day A', 'Upper Strength, 40-45 min')")
            try db.execute(sql: "INSERT INTO workout (name, description) VALUES ('Day B', 'Cardio + Core, 45-50 min')")
            try db.execute(sql: "INSERT INTO workout (name, description) VALUES ('Day C', 'Mixed / Maintenance, 35-40 min')")

            // Seed workoutExercise entries
            // Day A (workoutId=1): warmup, challenge, rows, chest press, shoulder press, curls, plank, dead bugs, stretch
            let dayA: [(exId: Int, pos: Int, value: Int?, label: String?, rest: Int, sets: Int)] = [
                (1,  0, 600,  "10 min",          0,  1),  // Cardio warm-up
                (2,  1, nil,  "10 + 10 reps",    0,  1),  // Daily Challenge
                (3,  2, 10,   "10 reps / side",  30, 4),  // Dumbbell rows — 1 warm-up + 3 working
                (4,  3, 10,   nil,               30, 4),  // Chest press
                (5,  4, 10,   nil,               30, 3),  // Shoulder press
                (6,  5, 10,   nil,               30, 3),  // Bicep curls
                (7,  6, 45,   "30–45 sec hold",  30, 2),  // Plank
                (8,  7, 10,   nil,               30, 2),  // Dead bugs
                (9,  8, 300,  "5 min",           0,  1),  // Stretch
            ]

            // Day B (workoutId=2): warmup, challenge, main cardio, plank, dead bugs, leg raises, flexibility
            let dayB: [(exId: Int, pos: Int, value: Int?, label: String?, rest: Int, sets: Int)] = [
                (1,  0, 300,  "5 min",           0,  1),  // Cardio warm-up
                (2,  1, nil,  "10 + 10 reps",    0,  1),  // Daily Challenge
                (10, 2, 1200, "20 min",          0,  1),  // Main cardio block
                (7,  3, 45,   "30–45 sec hold",  30, 3),  // Plank
                (8,  4, 10,   "10 reps / side",  30, 3),  // Dead bugs
                (11, 5, 10,   nil,               30, 3),  // Leg raises
                (12, 6, 600,  "10 min",          0,  1),  // Flexibility & mobility
            ]

            // Day C (workoutId=3): cardio, challenge, rows, chest, plank, dead bugs, stretch
            let dayC: [(exId: Int, pos: Int, value: Int?, label: String?, rest: Int, sets: Int)] = [
                (1,  0, 900,  "15 min",          0,  1),  // Cardio (cycling or stepper)
                (2,  1, nil,  "10 + 10 reps",    0,  1),  // Daily Challenge
                (3,  2, 10,   "10 reps / side",  30, 2),  // Dumbbell rows
                (4,  3, 10,   nil,               30, 2),  // Chest press or push-ups
                (7,  4, 40,   "30–40 sec",       0,  1),  // Plank
                (8,  5, 10,   "10 reps / side",  0,  1),  // Dead bugs
                (9,  6, 420,  "7 min",           0,  1),  // Stretch
            ]

            let allDays: [(workoutId: Int, entries: [(exId: Int, pos: Int, value: Int?, label: String?, rest: Int, sets: Int)])] = [
                (1, dayA), (2, dayB), (3, dayC),
            ]
            for day in allDays {
                for entry in day.entries {
                    try db.execute(
                        sql: """
                            INSERT INTO workoutExercise (workoutId, exerciseId, position, counterValue, counterLabel, restSeconds, sets)
                            VALUES (?, ?, ?, ?, ?, ?, ?)
                            """,
                        arguments: [day.workoutId, entry.exId, entry.pos, entry.value, entry.label, entry.rest, entry.sets]
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

        return migrator
    }

    /// In-memory database for testing
    public static func empty() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(configuration: Configuration())
        return try AppDatabase(dbQueue)
    }
}
