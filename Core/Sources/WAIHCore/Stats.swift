import Foundation

public struct ReasonStat: Equatable, Sendable, Identifiable {
    public var reason: Reason
    public var count: Int
    /// Share of all answered check-ins, 0–100.
    public var percent: Int
    /// Bar length relative to the top reason, 0–1.
    public var barFraction: Double
    public var id: String { reason.rawValue }
}

public struct LastCheckIn: Equatable, Sendable {
    public var label: String
    public var date: Date
}

public struct DaySummary: Equatable, Sendable {
    public var date: Date
    public var pickups: Int
    public var mindless: Int
    /// Share of check-ins that named a reason other than boredom; nil before the first check-in.
    public var intentionalPercent: Int?
    public var screenTime: TimeInterval
    public var topReasons: [ReasonStat]

    public var isEmpty: Bool { pickups == 0 }
}

public struct DayCount: Equatable, Sendable, Identifiable {
    public var date: Date
    public var count: Int
    /// Single-letter weekday, "M".
    public var letter: String
    public var isFuture: Bool
    public var id: Date { date }
}

public struct WeekSummary: Equatable, Sendable {
    public var interval: DateInterval
    public var days: [DayCount]
    public var pickups: Int
    public var screenTime: TimeInterval
    /// Pickups so far this week against the same days of last week; nil when last week has none.
    public var changePercent: Int?
    /// Mean pickups per day over the days that have happened.
    public var averagePerDay: Double
    public var busiestIndex: Int?
    public var topReasons: [ReasonStat]
    public var insight: String

    public var isEmpty: Bool { pickups == 0 }
}

public enum Stats {
    /// Summary of one calendar day. `records` may contain other days; they are filtered out.
    public static func day(records: [PickupRecord], on date: Date, now: Date, calendar: Calendar = .current) -> DaySummary {
        let today = records.filter { calendar.isDate($0.openedAt, inSameDayAs: date) }
        let mindless = today.filter(\.isMindless).count
        let intentional = today.filter(\.isIntentional).count
        let checkedIn = mindless + intentional
        return DaySummary(
            date: date,
            pickups: today.count,
            mindless: mindless,
            intentionalPercent: checkedIn == 0 ? nil : percent(intentional, of: checkedIn),
            screenTime: today.reduce(0) { $0 + $1.duration(now: now) },
            topReasons: topReasons(today, limit: 3))
    }

    public static func lastCheckIn(_ record: PickupRecord?) -> LastCheckIn? {
        guard let record else { return nil }
        if let label = record.reasonLabel { return LastCheckIn(label: label, date: record.openedAt) }
        if record.changedMind { return LastCheckIn(label: "Changed Your Mind", date: record.openedAt) }
        return record.skipped ? LastCheckIn(label: "Skipped", date: record.openedAt) : nil
    }

    /// Summary of the week containing `now`, compared with `previous` (last week's records).
    public static func week(records: [PickupRecord], previous: [PickupRecord], now: Date,
                            calendar: Calendar = .current) -> WeekSummary {
        let interval = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 7 * 86_400)
        let week = records.filter { interval.contains($0.openedAt) && $0.openedAt < interval.end }
        let todayStart = calendar.startOfDay(for: now)

        var days: [DayCount] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: interval.start) else { continue }
            let count = week.filter { calendar.isDate($0.openedAt, inSameDayAs: day) }.count
            let letter = String(calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: day) - 1].prefix(1))
            days.append(DayCount(date: day, count: count, letter: letter, isFuture: day > todayStart))
        }

        let elapsed = max(1, days.filter { !$0.isFuture }.count)
        let busiest = days.indices.filter { days[$0].count > 0 }.max { days[$0].count < days[$1].count }

        // Compare like with like: only the part of last week that matches the days elapsed so far.
        let previousStart = calendar.date(byAdding: .day, value: -7, to: interval.start) ?? interval.start
        let previousCutoff = calendar.date(byAdding: .day, value: elapsed, to: previousStart) ?? interval.start
        let previousSpan = previous.filter { $0.openedAt >= previousStart && $0.openedAt < previousCutoff }.count
        let change: Int? = previousSpan == 0 ? nil
            : Int((Double(week.count - previousSpan) / Double(previousSpan) * 100).rounded())

        return WeekSummary(
            interval: interval,
            days: days,
            pickups: week.count,
            screenTime: week.reduce(0) { $0 + $1.duration(now: now) },
            changePercent: change,
            averagePerDay: Double(week.count) / Double(elapsed),
            busiestIndex: busiest,
            topReasons: topReasons(week, limit: 4),
            insight: insight(week, calendar: calendar))
    }

    /// Reasons by frequency; ties keep the Intent Check display order.
    public static func topReasons(_ records: [PickupRecord], limit: Int) -> [ReasonStat] {
        var counts: [Reason: Int] = [:]
        for record in records {
            if let reason = record.reason { counts[reason, default: 0] += 1 }
        }
        let total = counts.values.reduce(0, +)
        let order = Reason.allCases
        let sorted = counts.sorted { a, b in
            a.value != b.value ? a.value > b.value : order.firstIndex(of: a.key)! < order.firstIndex(of: b.key)!
        }
        let top = sorted.first?.value ?? 0
        return sorted.prefix(limit).map { reason, count in
            ReasonStat(reason: reason, count: count, percent: percent(count, of: total),
                       barFraction: top == 0 ? 0 : Double(count) / Double(top))
        }
    }

    /// One sentence about the week, e.g. "You opened Instagram out of boredom 41 times, mostly after 9 PM."
    public static func insight(_ records: [PickupRecord], calendar: Calendar = .current) -> String {
        guard !records.isEmpty else {
            return "Your week will take shape here after your first check-in."
        }
        let bored = records.filter { $0.reason == .justBored }
        if !bored.isEmpty {
            let byApp = Dictionary(grouping: bored, by: \.appName)
            let (app, opens) = byApp.max { a, b in
                a.value.count != b.value.count ? a.value.count < b.value.count : a.key > b.key
            }!
            let times = opens.count == 1 ? "once" : "\(opens.count) times"
            let when = dominantTime(opens.map(\.openedAt), calendar: calendar).map { ", mostly \($0)" } ?? ""
            return "You opened \(app) out of boredom \(times)\(when)."
        }
        let intentional = records.filter(\.isIntentional).count
        let skipped = records.filter(\.skipped).count
        if skipped > intentional {
            let times = skipped == 1 ? "once" : "\(skipped) times"
            return "You skipped the check-in \(times) this week. Naming a reason makes reminders more useful."
        }
        if intentional > 0 {
            let noun = intentional == 1 ? "pickup" : "pickups"
            return "\(intentional) \(noun) this week had a clear reason, and none were out of boredom."
        }
        return "No check-ins yet this week. Answers will show up here as you go."
    }

    /// The part of the day holding at least half of `dates`, if any.
    static func dominantTime(_ dates: [Date], calendar: Calendar) -> String? {
        guard !dates.isEmpty else { return nil }
        let hours = dates.map { calendar.component(.hour, from: $0) }
        let buckets: [(String, (Int) -> Bool)] = [
            ("after 9 PM", { $0 >= 21 }),
            ("in the morning", { $0 >= 5 && $0 < 12 }),
            ("in the afternoon", { $0 >= 12 && $0 < 17 }),
            ("in the evening", { $0 >= 17 && $0 < 21 }),
            ("late at night", { $0 < 5 }),
        ]
        for (label, matches) in buckets where hours.filter(matches).count * 2 >= hours.count {
            return label
        }
        return nil
    }

    static func percent(_ part: Int, of total: Int) -> Int {
        total == 0 ? 0 : Int((Double(part) / Double(total) * 100).rounded())
    }
}
