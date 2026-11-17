import Foundation
@testable import WAIHCore

/// Fixed New York calendar so hour-of-day assertions do not depend on the machine running the tests.
let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    calendar.firstWeekday = 2 // Monday
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}()

/// A date in November 2025 by default. Nov 3 2025, the day on the prototype's Today screen, is a Monday.
func date(_ day: Int, _ hour: Int = 12, _ minute: Int = 0, month: Int = 11, year: Int = 2025) -> Date {
    testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

@MainActor
final class FakeReminders: ReminderScheduling {
    var scheduled: [ReminderPlan] = []
    var cancelled: [UUID] = []
    func schedule(_ plan: ReminderPlan) { scheduled.append(plan) }
    func cancelReminders(pickupID: UUID) { cancelled.append(pickupID) }
    /// Plans still in effect: scheduled after the last cancel for that pickup.
    var active: [ReminderPlan] {
        Dictionary(grouping: scheduled, by: \.pickupID).compactMap { $0.value.last }
    }
}

@MainActor
final class Harness {
    let store: PickupStore
    let reminders = FakeReminders()
    let engine: CheckInEngine
    var clock: Date

    nonisolated static let instagram = AppCatalog.builtIn.first { $0.id == "instagram" }!
    nonisolated static let tiktok = AppCatalog.builtIn.first { $0.id == "tiktok" }!

    init(start: Date = date(3, 9), configure: (inout WAIHSettings) -> Void = { _ in }) throws {
        store = try PickupStore(inMemory: true)
        var settings = WAIHSettings()
        settings.frequency = .everyOpen
        configure(&settings)
        clock = start
        engine = CheckInEngine(store: store, settings: settings, reminders: reminders, calendar: testCalendar)
        engine.now = { [unowned self] in self.clock }
    }

    func advance(minutes: Double) { clock = clock.addingTimeInterval(minutes * 60) }

    /// Opens the app and returns the pickup id when the engine decides to ask.
    func open(_ app: WatchedApp = Harness.instagram) -> UUID? {
        if case .prompt(let id, _) = engine.appOpened(app) { return id }
        return nil
    }
}
