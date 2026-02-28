import Foundation
import GRDB

public enum Queries {
    // MARK: - Sessions

    @discardableResult
    public static func insertSession(
        _ db: AppDatabase,
        type: SessionType,
        date: String,
        startedAt: String,
        durationSeconds: Int,
        isPartial: Bool = false,
        feedback: WorkoutFeedback? = nil
    ) throws -> Session {
        let session = Session(
            sessionType: type,
            date: date,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            isPartial: isPartial,
            feedback: feedback?.rawValue
        )
        return try db.dbWriter.write { dbConn in
            try session.inserted(dbConn)
        }
    }

    public static func lastSession(_ db: AppDatabase) throws -> Session? {
        try db.dbWriter.read { db in
            try Session
                .order(Column("id").desc)
                .fetchOne(db)
        }
    }

    public static func sessionsInDateRange(
        _ db: AppDatabase,
        from startDate: String,
        to endDate: String
    ) throws -> [Session] {
        try db.dbWriter.read { db in
            try Session
                .filter(Column("date") >= startDate && Column("date") <= endDate)
                .order(Column("date").desc)
                .fetchAll(db)
        }
    }

    /// All dates with at least one non-partial session
    public static func nonPartialSessionDates(_ db: AppDatabase) throws -> [Date] {
        try db.dbWriter.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT DISTINCT date FROM session WHERE isPartial = 0 ORDER BY date DESC"
            )
            return rows.compactMap { DateHelpers.date(from: $0["date"]) }
        }
    }

    // MARK: - Daily Challenge

    public static func challengeForDate(_ db: AppDatabase, date: String) throws -> DailyChallenge? {
        try db.dbWriter.read { db in
            try DailyChallenge
                .filter(Column("date") == date)
                .fetchOne(db)
        }
    }

    @discardableResult
    public static func upsertChallenge(
        _ db: AppDatabase,
        date: String,
        setsCompleted: Int
    ) throws -> DailyChallenge {
        try db.dbWriter.write { dbConn in
            if var existing = try DailyChallenge.filter(Column("date") == date).fetchOne(dbConn) {
                existing.setsCompleted = setsCompleted
                try existing.update(dbConn)
                return existing
            } else {
                let challenge = DailyChallenge(date: date, setsCompleted: setsCompleted)
                try challenge.insert(dbConn)
                return challenge
            }
        }
    }

    /// Increment challenge sets for a date, capping at 3
    @discardableResult
    public static func incrementChallenge(_ db: AppDatabase, date: String) throws -> DailyChallenge {
        let current = try challengeForDate(db, date: date)
        let newSets = min((current?.setsCompleted ?? 0) + 1, 3)
        return try upsertChallenge(db, date: date, setsCompleted: newSets)
    }

    /// All dates where challenge was fully completed (3 sets)
    public static func completedChallengeDates(_ db: AppDatabase) throws -> [Date] {
        try db.dbWriter.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT date FROM dailyChallenge WHERE setsCompleted = 3 ORDER BY date DESC"
            )
            return rows.compactMap { DateHelpers.date(from: $0["date"]) }
        }
    }

    /// Count of completed challenge days in a date range
    public static func completedChallengeCount(
        _ db: AppDatabase,
        from startDate: String,
        to endDate: String
    ) throws -> Int {
        try db.dbWriter.read { db in
            try DailyChallenge
                .filter(Column("date") >= startDate && Column("date") <= endDate)
                .filter(Column("setsCompleted") == 3)
                .fetchCount(db)
        }
    }

    // MARK: - Workouts & Exercises

    /// Fetch all workouts
    public static func allWorkouts(_ db: AppDatabase) throws -> [Workout] {
        try db.dbWriter.read { dbConn in
            try Workout.fetchAll(dbConn)
        }
    }

    /// Fetch a workout by name
    public static func workoutByName(_ db: AppDatabase, name: String) throws -> Workout? {
        try db.dbWriter.read { dbConn in
            try Workout
                .filter(Column("name") == name)
                .fetchOne(dbConn)
        }
    }

    /// Fetch exercises for a workout, ordered by position.
    /// Returns tuples of (ExerciseRecord, WorkoutExercise) so callers have both
    /// the exercise catalog data and the per-workout programming.
    public static func exercisesForWorkout(
        _ db: AppDatabase,
        workoutId: Int64
    ) throws -> [(ExerciseRecord, WorkoutExercise)] {
        try db.dbWriter.read { dbConn in
            let rows = try Row.fetchAll(
                dbConn,
                sql: """
                    SELECT e.id, e.name, e.description, e.instructions, e.tip,
                           we.id AS weId, we.workoutId, we.exerciseId, we.position,
                           we.counterUnit, we.counterValue, we.counterLabel,
                           we.restSeconds, we.sets, we.isDailyChallenge, we.hasWeight,
                           we.isActive
                    FROM workoutExercise we
                    JOIN exercise e ON e.id = we.exerciseId
                    WHERE we.workoutId = ?
                      AND we.isActive = 1
                    ORDER BY we.position
                    """,
                arguments: [workoutId]
            )
            return rows.map { row in
                let exercise = ExerciseRecord(
                    id: row["id"],
                    name: row["name"],
                    description: row["description"],
                    instructions: row["instructions"],
                    tip: row["tip"]
                )
                let we = WorkoutExercise(
                    id: row["weId"],
                    workoutId: row["workoutId"],
                    exerciseId: row["exerciseId"],
                    position: row["position"],
                    counterUnit: row["counterUnit"],
                    counterValue: row["counterValue"],
                    counterLabel: row["counterLabel"],
                    restSeconds: row["restSeconds"],
                    sets: row["sets"],
                    isDailyChallenge: row["isDailyChallenge"],
                    hasWeight: row["hasWeight"],
                    isActive: row["isActive"]
                )
                return (exercise, we)
            }
        }
    }

    // MARK: - Exercise Logs

    /// Bulk insert exercise log entries for a session
    public static func insertExerciseLogs(
        _ db: AppDatabase,
        sessionId: Int64,
        logs: [ExerciseLog]
    ) throws {
        try db.dbWriter.write { dbConn in
            for var log in logs {
                log.sessionId = sessionId
                try log.insert(dbConn)
            }
        }
    }

    // MARK: - Stats

    /// Max weight per date for a given exercise, ordered chronologically.
    public static func weightHistory(
        _ db: AppDatabase,
        exerciseId: Int64
    ) throws -> [(date: String, weight: Double)] {
        try db.dbWriter.read { dbConn in
            let rows = try Row.fetchAll(
                dbConn,
                sql: """
                    SELECT s.date, MAX(el.weight) AS maxWeight
                    FROM exerciseLog el
                    JOIN session s ON s.id = el.sessionId
                    JOIN workoutExercise we ON we.id = el.workoutExerciseId
                    WHERE we.exerciseId = ? AND el.weight > 0
                    GROUP BY s.date
                    ORDER BY s.date ASC
                    """,
                arguments: [exerciseId]
            )
            return rows.compactMap { row -> (date: String, weight: Double)? in
                guard let date: String = row["date"],
                      let weight: Double = row["maxWeight"] else { return nil }
                return (date: date, weight: weight)
            }
        }
    }

    /// Exercises that have at least one weight log entry.
    public static func exercisesWithWeightLogs(_ db: AppDatabase) throws -> [ExerciseRecord] {
        try db.dbWriter.read { dbConn in
            let rows = try Row.fetchAll(
                dbConn,
                sql: """
                    SELECT e.id, e.name, e.description, e.instructions, e.tip
                    FROM exercise e
                    WHERE e.id IN (
                        SELECT DISTINCT we.exerciseId
                        FROM workoutExercise we
                        JOIN exerciseLog el ON el.workoutExerciseId = we.id
                        WHERE el.weight > 0
                    )
                    ORDER BY e.name
                    """
            )
            return rows.map { row in
                ExerciseRecord(
                    id: row["id"],
                    name: row["name"],
                    description: row["description"],
                    instructions: row["instructions"],
                    tip: row["tip"]
                )
            }
        }
    }

    /// Non-partial sessions grouped into weekly or monthly buckets, ordered chronologically.
    public static func sessionCountsByPeriod(
        _ db: AppDatabase,
        granularity: Granularity
    ) throws -> [SessionCountBucket] {
        let sessions = try db.dbWriter.read { dbConn in
            try Session
                .filter(Column("isPartial") == false)
                .order(Column("date"))
                .fetchAll(dbConn)
        }

        let cal = Calendar.current
        var bucketKeys: [String] = []
        var bucketSessions: [String: [Session]] = [:]

        for session in sessions {
            guard let date = DateHelpers.date(from: session.date) else { continue }
            let key: String
            switch granularity {
            case .weekly:
                let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
                let year = comps.yearForWeekOfYear ?? 0
                let week = comps.weekOfYear ?? 0
                key = String(format: "%04d-W%02d", year, week)
            case .monthly:
                let comps = cal.dateComponents([.year, .month], from: date)
                let year = comps.year ?? 0
                let month = comps.month ?? 0
                key = String(format: "%04d-%02d", year, month)
            }
            if bucketSessions[key] == nil {
                bucketKeys.append(key)
                bucketSessions[key] = []
            }
            bucketSessions[key]!.append(session)
        }

        return bucketKeys.map { key in
            let sessionList = bucketSessions[key] ?? []
            var typeCounts: [String: Int] = [:]
            for s in sessionList {
                typeCounts[s.sessionType, default: 0] += 1
            }
            let dominantType = typeCounts.max(by: { $0.value < $1.value })
                .flatMap { SessionType(rawValue: $0.key) }
            return SessionCountBucket(
                id: key,
                label: key,
                count: sessionList.count,
                dominantType: dominantType
            )
        }
    }

    /// All-time personal bests computed from session and exercise log data.
    public static func personalBests(_ db: AppDatabase) throws -> PersonalBests {
        let heaviestRow = try db.dbWriter.read { dbConn in
            try Row.fetchOne(
                dbConn,
                sql: """
                    SELECT e.name, MAX(el.weight) AS maxWeight
                    FROM exerciseLog el
                    JOIN workoutExercise we ON we.id = el.workoutExerciseId
                    JOIN exercise e ON e.id = we.exerciseId
                    WHERE el.weight > 0
                    GROUP BY we.exerciseId
                    ORDER BY MAX(el.weight) DESC
                    LIMIT 1
                    """
            )
        }

        let heaviestLift: (exercise: String, weight: Double)?
        if let row = heaviestRow,
           let name: String = row["name"],
           let weight: Double = row["maxWeight"] {
            heaviestLift = (exercise: name, weight: weight)
        } else {
            heaviestLift = nil
        }

        let sessionDates = try nonPartialSessionDates(db)
        let challengeDates = try completedChallengeDates(db)
        let weeklyCounts = try sessionCountsByPeriod(db, granularity: .weekly)

        return PersonalBests(
            heaviestLift: heaviestLift,
            longestSessionStreak: StreakLogic.longestGymStreak(sessionDates: sessionDates),
            longestChallengeStreak: StreakLogic.longestChallengeStreak(completedDates: challengeDates),
            mostSessionsInWeek: weeklyCounts.map(\.count).max() ?? 0
        )
    }

    /// All challenge entries for a given year, keyed by date string.
    public static func challengeHistory(
        _ db: AppDatabase,
        year: Int
    ) throws -> [String: Int] {
        let startDate = String(format: "%04d-01-01", year)
        let endDate = String(format: "%04d-12-31", year)
        return try db.dbWriter.read { dbConn in
            let rows = try Row.fetchAll(
                dbConn,
                sql: """
                    SELECT date, setsCompleted
                    FROM dailyChallenge
                    WHERE date >= ? AND date <= ? AND setsCompleted > 0
                    """,
                arguments: [startDate, endDate]
            )
            var result: [String: Int] = [:]
            for row in rows {
                if let date: String = row["date"], let sets: Int = row["setsCompleted"] {
                    result[date] = sets
                }
            }
            return result
        }
    }

    /// Fetch the most recent weight per exercise for a given workout.
    /// Looks across all workouts sharing the same exerciseId so that
    /// weights carry over (e.g., Day A rows → Day C rows).
    /// Returns a mapping of workoutExerciseId → last weight used.
    public static func lastWeights(
        _ db: AppDatabase,
        forWorkoutId workoutId: Int64
    ) throws -> [Int64: Double] {
        try db.dbWriter.read { dbConn in
            let rows = try Row.fetchAll(
                dbConn,
                sql: """
                    SELECT cur.id AS weId, el.weight
                    FROM workoutExercise cur
                    JOIN workoutExercise any_we ON any_we.exerciseId = cur.exerciseId
                    JOIN exerciseLog el ON el.workoutExerciseId = any_we.id
                    JOIN session s ON s.id = el.sessionId
                    WHERE cur.workoutId = ?
                      AND cur.isActive = 1
                      AND el.weight IS NOT NULL
                    ORDER BY s.id DESC
                    """,
                arguments: [workoutId]
            )
            var result: [Int64: Double] = [:]
            for row in rows {
                let weId: Int64 = row["weId"]
                // First row per weId is the most recent (ORDER BY s.id DESC)
                if result[weId] == nil {
                    result[weId] = row["weight"]
                }
            }
            return result
        }
    }
}
