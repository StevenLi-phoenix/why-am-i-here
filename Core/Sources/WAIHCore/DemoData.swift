import Foundation

/// Sample history that reproduces the numbers in the design prototype. Used for screenshots and UI tests.
public enum DemoData {
    /// Today: 37 pickups, 14 mindless, 62% intentional, 2h 41m.
    static let today: [(Reason?, Int)] = [
        (.messages, 12), (.justBored, 9), (.workOrSchool, 7), (.lookSomethingUp, 2),
        (.directions, 1), (.checkTheTime, 1), (nil, 5),
    ]

    @MainActor
    public static func seed(_ store: PickupStore, now: Date, calendar: Calendar = .current) {
        store.deleteAll()
        let startOfToday = calendar.startOfDay(for: now)
        let week = calendar.dateInterval(of: .weekOfYear, for: now)!
        let todayIndex = calendar.dateComponents([.day], from: week.start, to: startOfToday).day ?? 0

        // Earlier days of this week, and a last week that was about 8% busier ("Down 8%").
        var thisWeek = [30, 26, 33, 28, 38, 44, 42]
        thisWeek[todayIndex % 7] = today.reduce(0) { $0 + $1.1 }
        let lastWeek = thisWeek.map { Int((Double($0) / 0.92).rounded()) }
        for (offset, count) in lastWeek.enumerated() {
            let day = calendar.date(byAdding: .day, value: offset - 7, to: week.start)!
            fill(store, day: day, count: count, minutesEach: 4, calendar: calendar, seed: offset)
        }
        for offset in 0..<todayIndex {
            let day = calendar.date(byAdding: .day, value: offset, to: week.start)!
            fill(store, day: day, count: thisWeek[offset % 7], minutesEach: 4, calendar: calendar, seed: 7 + offset)
        }

        // Today, spread from 7 AM up to now. 161 minutes over 37 pickups.
        var plan: [Reason?] = []
        for (reason, count) in today { plan += Array(repeating: reason, count: count) }
        // Interleave reasons so they are not clustered by time of day (17 is coprime with 37).
        var slots = [Reason?](repeating: nil, count: plan.count)
        for (index, reason) in plan.enumerated() { slots[(index * 17) % plan.count] = reason }
        // The most recent check-in is "Messages", as in the prototype.
        if let last = slots.indices.last, slots[last] != .messages,
           let swap = slots.firstIndex(of: .messages) {
            slots.swapAt(last, swap)
        }
        let span = max(600, now.timeIntervalSince(startOfToday) - 7 * 3600 - 600)
        let durations = sessionDurations(count: slots.count, totalMinutes: 161)
        for (slot, reason) in slots.enumerated() {
            var opened = startOfToday.addingTimeInterval(7 * 3600 + span * Double(slot) / Double(slots.count))
            if opened > now { opened = now.addingTimeInterval(-Double(slots.count - slot) * 60) }
            let app = slot % 4 == 3 ? ("tiktok", "TikTok") : ("instagram", "Instagram")
            let pickup = Pickup(appID: app.0, appName: app.1, openedAt: opened, prompted: true)
            pickup.reason = reason
            pickup.skipped = reason == nil
            pickup.sessionStart = opened
            pickup.sessionEnd = opened.addingTimeInterval(durations[slot])
            pickup.endedBy = .closed
            store.insert(pickup)
        }
        Log.store.notice("demo data seeded: \(store.totalCount) pickups")
    }

    @MainActor
    private static func fill(_ store: PickupStore, day: Date, count: Int, minutesEach: Int, calendar: Calendar, seed: Int) {
        let reasons: [Reason?] = [.messages, .justBored, .messages, .workOrSchool, .justBored, .lookSomethingUp,
                                  .messages, .justBored, .workOrSchool, .lookSomethingUp, .messages, .justBored,
                                  .messages, .workOrSchool, .justBored, .lookSomethingUp, .messages, .directions,
                                  .messages, .justBored, .workOrSchool, .messages, .lookSomethingUp, .justBored,
                                  .checkTheTime, .messages, .other, .workOrSchool]
        for index in 0..<count {
            let reason = reasons[(index + seed) % reasons.count]
            // Boredom clusters late in the evening; everything else is spread through the day.
            let hour: Double = reason == .justBored && index % 5 != 0
                ? 21 + Double((index + seed) % 5) * 0.5
                : 8 + Double(index) * 12 / Double(count)
            let opened = day.addingTimeInterval(hour * 3600)
            let app = reason == .justBored || index % 3 != 2 ? ("instagram", "Instagram") : ("tiktok", "TikTok")
            let pickup = Pickup(appID: app.0, appName: app.1, openedAt: opened, prompted: true)
            pickup.reason = reason
            pickup.sessionStart = opened
            pickup.sessionEnd = opened.addingTimeInterval(Double(minutesEach * 60))
            pickup.endedBy = .closed
            store.insert(pickup)
        }
    }

    /// Splits `totalMinutes` into `count` sessions of varying length.
    static func sessionDurations(count: Int, totalMinutes: Int) -> [TimeInterval] {
        guard count > 0 else { return [] }
        let weights = (0..<count).map { Double(1 + ($0 * 7) % 5) }
        let sum = weights.reduce(0, +)
        return weights.map { $0 / sum * Double(totalMinutes) * 60 }
    }
}
