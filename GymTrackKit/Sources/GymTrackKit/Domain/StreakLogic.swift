import Foundation

public enum StreakLogic {
    /// Gym streak: consecutive calendar days with at least one session,
    /// ending today or yesterday.
    public static func gymStreak(sessionDates: [Date], today: Date) -> Int {
        consecutiveStreak(dates: sessionDates, today: today)
    }

    /// Challenge streak: consecutive calendar days with completed challenge (3/3 sets),
    /// ending today or yesterday.
    public static func challengeStreak(completedDates: [Date], today: Date) -> Int {
        consecutiveStreak(dates: completedDates, today: today)
    }

    private static func consecutiveStreak(dates: [Date], today: Date) -> Int {
        let cal = Calendar.current
        let uniqueDays = Set(dates.map { cal.startOfDay(for: $0) })
        let sorted = uniqueDays.sorted(by: >)

        guard !sorted.isEmpty else { return 0 }

        let todayStart = cal.startOfDay(for: today)
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!

        // Streak must end on today or yesterday
        guard sorted[0] == todayStart || sorted[0] == yesterdayStart else {
            return 0
        }

        var streak = 1
        var currentDay = sorted[0]

        for i in 1..<sorted.count {
            let expectedPrevious = cal.date(byAdding: .day, value: -1, to: currentDay)!
            if sorted[i] == expectedPrevious {
                streak += 1
                currentDay = sorted[i]
            } else {
                break
            }
        }

        return streak
    }
}
