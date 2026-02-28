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

    /// Longest consecutive streak ever across all recorded dates.
    public static func longestGymStreak(sessionDates: [Date]) -> Int {
        longestStreakEver(dates: sessionDates)
    }

    /// Longest consecutive challenge streak ever across all completed dates.
    public static func longestChallengeStreak(completedDates: [Date]) -> Int {
        longestStreakEver(dates: completedDates)
    }

    private static func longestStreakEver(dates: [Date]) -> Int {
        let cal = Calendar.current
        let uniqueDays = Array(Set(dates.map { cal.startOfDay(for: $0) })).sorted()
        guard !uniqueDays.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<uniqueDays.count {
            let expected = cal.date(byAdding: .day, value: 1, to: uniqueDays[i - 1])!
            if uniqueDays[i] == expected {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
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
