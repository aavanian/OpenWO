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
        isPartial: Bool = false
    ) throws -> Session {
        var session = Session(
            sessionType: type,
            date: date,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            isPartial: isPartial
        )
        try db.dbWriter.write { dbConn in
            try session.insert(dbConn)
        }
        return session
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
                var challenge = DailyChallenge(date: date, setsCompleted: setsCompleted)
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
}
