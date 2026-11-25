import Foundation

public enum Format {
    /// "41m", "2h 41m"; with `compact`, ten hours and up drop the minutes ("17h").
    public static func duration(_ interval: TimeInterval, compact: Bool = false) -> String {
        let minutes = max(0, Int((interval / 60).rounded()))
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 || (compact && h >= 10) { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    /// 22 -> "10 PM", 7 -> "7 AM", 0 -> "12 AM".
    public static func hour(_ hour: Int) -> String {
        let h = ((hour % 24) + 24) % 24
        let twelve = h % 12 == 0 ? 12 : h % 12
        return "\(twelve) \(h < 12 ? "AM" : "PM")"
    }

    /// "Tue, Nov 3"
    public static func dayHeader(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("EEE, MMM d", calendar).string(from: date)
    }

    /// "9:12 PM"
    public static func time(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("h:mm a", calendar).string(from: date)
    }

    /// "Oct 27 – Nov 2". `interval.end` is exclusive.
    public static func weekRange(_ interval: DateInterval, calendar: Calendar = .current) -> String {
        let f = formatter("MMM d", calendar)
        let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        return "\(f.string(from: interval.start)) – \(f.string(from: last))"
    }

    /// "Monday"
    public static func weekday(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("EEEE", calendar).string(from: date)
    }

    /// When a watched app was last opened through its automation: "today at 9:41 AM", "yesterday", "on Nov 20".
    public static func lastSeen(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "today at \(time(date, calendar: calendar))" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "yesterday" }
        return "on \(formatter("MMM d", calendar).string(from: date))"
    }

    /// "+8%", "−8%" (true minus sign), "0%".
    public static func signedPercent(_ value: Int) -> String {
        if value > 0 { return "+\(value)%" }
        if value < 0 { return "−\(-value)%" }
        return "0%"
    }

    /// "Down 8%", "Up 8%", "No Change".
    public static func trend(_ value: Int) -> String {
        if value > 0 { return "Up \(value)%" }
        if value < 0 { return "Down \(-value)%" }
        return "No Change"
    }

    private static func formatter(_ format: String, _ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }
}
