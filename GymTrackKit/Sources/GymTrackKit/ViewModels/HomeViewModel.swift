import Foundation
import Combine

public final class HomeViewModel: ObservableObject {
    private let database: AppDatabase

    @Published public var gymStreak: Int = 0
    @Published public var nextSessionType: SessionType = .a
    @Published public var challengeSetsToday: Int = 0
    @Published public var challengeStreak: Int = 0
    @Published public var challengeDaysPast365: Int = 0
    @Published public var challengeDaysYTD: Int = 0
    @Published public var sessionsThisWeek: Int = 0
    @Published public var sessionsThisMonth: Int = 0
    @Published public var lastSession: Session?

    public init(database: AppDatabase) {
        self.database = database
    }

    public func refresh() {
        let today = Date()
        let todayStr = DateHelpers.dateString(from: today)

        do {
            // Rotation
            let last = try Queries.lastSession(database)
            nextSessionType = RotationLogic.nextSessionType(after: last?.type)
            lastSession = last

            // Gym streak
            let sessionDates = try Queries.nonPartialSessionDates(database)
            gymStreak = StreakLogic.gymStreak(sessionDates: sessionDates, today: today)

            // Challenge
            let challenge = try Queries.challengeForDate(database, date: todayStr)
            challengeSetsToday = challenge?.setsCompleted ?? 0

            let completedDates = try Queries.completedChallengeDates(database)
            challengeStreak = StreakLogic.challengeStreak(completedDates: completedDates, today: today)

            // Challenge stats
            let yearAgo = Calendar.current.date(byAdding: .day, value: -365, to: today)!
            challengeDaysPast365 = try Queries.completedChallengeCount(
                database,
                from: DateHelpers.dateString(from: yearAgo),
                to: todayStr
            )

            let startOfYear = DateHelpers.startOfYear(containing: today)
            challengeDaysYTD = try Queries.completedChallengeCount(
                database,
                from: DateHelpers.dateString(from: startOfYear),
                to: todayStr
            )

            // Quick stats
            let startOfWeek = DateHelpers.startOfWeek(containing: today)
            sessionsThisWeek = try Queries.sessionsInDateRange(
                database,
                from: DateHelpers.dateString(from: startOfWeek),
                to: todayStr
            ).count

            let startOfMonth = DateHelpers.startOfMonth(containing: today)
            sessionsThisMonth = try Queries.sessionsInDateRange(
                database,
                from: DateHelpers.dateString(from: startOfMonth),
                to: todayStr
            ).count
        } catch {
            // Silently handle — UI shows defaults
        }
    }

    public func incrementChallenge() {
        let todayStr = DateHelpers.dateString(from: Date())
        do {
            let updated = try Queries.incrementChallenge(database, date: todayStr)
            challengeSetsToday = updated.setsCompleted
            refreshChallengeStreak()
        } catch {}
    }

    public func setChallenge(sets: Int) {
        let todayStr = DateHelpers.dateString(from: Date())
        do {
            let updated = try Queries.upsertChallenge(database, date: todayStr, setsCompleted: sets)
            challengeSetsToday = updated.setsCompleted
            refreshChallengeStreak()
        } catch {}
    }

    private func refreshChallengeStreak() {
        do {
            let completedDates = try Queries.completedChallengeDates(database)
            challengeStreak = StreakLogic.challengeStreak(completedDates: completedDates, today: Date())
        } catch {}
    }
}
