import Foundation

public enum DateHelpers {
    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    private static let isoDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    public static func dateString(from date: Date) -> String {
        isoDateFormatter.string(from: date)
    }

    public static func date(from string: String) -> Date? {
        isoDateFormatter.date(from: string)
    }

    public static func dateTimeString(from date: Date) -> String {
        isoDateTimeFormatter.string(from: date)
    }

    public static func dateTime(from string: String) -> Date? {
        isoDateTimeFormatter.date(from: string)
    }

    public static func startOfWeek(containing date: Date) -> Date {
        let cal = Calendar.current
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components)!
    }

    public static func startOfMonth(containing date: Date) -> Date {
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: components)!
    }

    public static func startOfYear(containing date: Date) -> Date {
        let cal = Calendar.current
        let components = cal.dateComponents([.year], from: date)
        return cal.date(from: components)!
    }
}
