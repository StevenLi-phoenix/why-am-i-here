import Foundation

/// One scheduled "Still here?" nudge.
public struct ReminderFire: Equatable, Sendable {
    public var date: Date
    /// Minutes since the session started, quoted in the reminder.
    public var minutes: Int
    public var index: Int
}

public struct ReminderPlan: Equatable, Sendable {
    public static let maxFires = 4

    public var pickupID: UUID
    public var appID: String
    public var appName: String
    public var reasonLabel: String?
    public var fires: [ReminderFire]

    /// "Still here for “Messages”?" or, with no reason on record, "Still on Instagram?".
    public var title: String { Self.title(reasonLabel: reasonLabel, appName: appName) }

    public static func title(reasonLabel: String?, appName: String) -> String {
        if let reasonLabel { return "Still here for “\(reasonLabel)”?" }
        return "Still on \(appName)?"
    }
}

@MainActor
public protocol ReminderScheduling: AnyObject {
    func schedule(_ plan: ReminderPlan)
    func cancelReminders(pickupID: UUID)
}

public enum PassReason: String, Sendable {
    /// We just sent the user to this app ourselves.
    case handoff
    case notWatched
    case askDisabled
    case quietHours
    case frequency
}

public enum OpenOutcome: Equatable, Sendable {
    /// Show the Intent Check. `pickupNumber` is today's running count across watched apps.
    case prompt(pickupID: UUID, pickupNumber: Int)
    /// Let the user through without asking.
    case passthrough(PassReason)
}

/// Decides when to ask, and keeps pickup and session records consistent.
@MainActor
public final class CheckInEngine {
    /// After we hand the user to an app, opens of it inside this window are our own doing.
    public static let handoffGrace: TimeInterval = 20

    public let store: PickupStore
    public var settings: WAIHSettings
    public weak var reminders: ReminderScheduling?
    public var calendar: Calendar
    public var now: () -> Date

    private var lastHandoff: (appID: String, at: Date)?

    public init(store: PickupStore, settings: WAIHSettings, reminders: ReminderScheduling? = nil,
                calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.settings = settings
        self.reminders = reminders
        self.calendar = calendar
        self.now = now
    }

    // MARK: Opening

    /// Called when a watched app comes to the foreground.
    public func appOpened(_ app: WatchedApp) -> OpenOutcome {
        let date = now()
        if isHandoff(appID: app.id, at: date) {
            Log.engine.info("open \(app.id, privacy: .public): passthrough handoff")
            return .passthrough(.handoff)
        }
        guard settings.isWatched(app.id) else {
            Log.engine.info("open \(app.id, privacy: .public): passthrough notWatched")
            return .passthrough(.notWatched)
        }

        closeStaleSessions(appID: app.id, at: date)
        let previous = store.lastPickup(appID: app.id, before: date)
        let today = dayInterval(for: date)
        let appCountToday = store.count(appID: app.id, in: today) + 1
        let pickupNumber = store.count(in: today) + 1

        let pass = passReason(appCountToday: appCountToday, previous: previous, at: date)
        let pickup = Pickup(appID: app.id, appName: app.name, openedAt: date, prompted: pass == nil)
        if pass != nil {
            // Not asking: the session starts right away.
            pickup.sessionStart = date
        }
        store.insert(pickup)

        if let pass {
            scheduleReminders(for: pickup, from: date)
            Log.engine.info("open \(app.id, privacy: .public) #\(pickupNumber): passthrough \(pass.rawValue, privacy: .public)")
            return .passthrough(pass)
        }
        Log.engine.info("open \(app.id, privacy: .public) #\(pickupNumber): prompt")
        return .prompt(pickupID: pickup.id, pickupNumber: pickupNumber)
    }

    private func passReason(appCountToday: Int, previous: Pickup?, at date: Date) -> PassReason? {
        guard settings.askBeforeWatchedApps else { return .askDisabled }
        if settings.isQuiet(at: date, calendar: calendar) { return .quietHours }
        switch settings.frequency {
        case .everyOpen:
            return nil
        case .everyThirdOpen:
            // Opens 1, 4, 7… of the day ask, so the first open always does.
            return (appCountToday - 1) % 3 == 0 ? nil : .frequency
        case .afterThirtyMinutesAway:
            guard let previous else { return nil }
            let lastSeen = previous.sessionEnd ?? previous.sessionStart ?? previous.openedAt
            return date.timeIntervalSince(lastSeen) >= WAIHSettings.awayThreshold ? nil : .frequency
        }
    }

    private func isHandoff(appID: String, at date: Date) -> Bool {
        if let lastHandoff, lastHandoff.appID == appID,
           date.timeIntervalSince(lastHandoff.at) < Self.handoffGrace {
            return true
        }
        // Covers a relaunch between "Continue" and the automation firing.
        if let active = store.activeSessions(appID: appID).first, let start = active.sessionStart,
           active.prompted, date.timeIntervalSince(start) < Self.handoffGrace {
            return true
        }
        return false
    }

    /// Records that we are about to send the user to `appID`, so the open that follows is not asked about.
    public func noteHandoff(appID: String) {
        lastHandoff = (appID, now())
    }

    /// Without an "Is Closed" automation a session never ends on its own; cap it when the next open arrives.
    private func closeStaleSessions(appID: String, at date: Date) {
        for stale in store.activeSessions(appID: appID) {
            guard let start = stale.sessionStart else { continue }
            let cap = start.addingTimeInterval(TimeInterval(settings.remindAfterMinutes * 60))
            stale.sessionEnd = min(date, cap)
            stale.endedBy = .stale
            reminders?.cancelReminders(pickupID: stale.id)
            Log.engine.info("closed stale session \(stale.id.uuidString, privacy: .public)")
        }
        store.save()
    }

    // MARK: Check-in

    /// Finishes the Intent Check. A nil `reason` means "Skip for Now".
    @discardableResult
    public func completeCheckIn(pickupID: UUID, reason: Reason?, note: String? = nil) -> Pickup? {
        guard let pickup = store.pickup(id: pickupID) else {
            Log.engine.error("completeCheckIn: unknown pickup \(pickupID.uuidString, privacy: .public)")
            return nil
        }
        let date = now()
        pickup.reason = reason
        pickup.note = reason == .other ? note : nil
        pickup.skipped = reason == nil
        pickup.sessionStart = date
        pickup.sessionEnd = nil
        pickup.endedBy = nil
        store.save()
        scheduleReminders(for: pickup, from: date)
        Log.engine.info("check-in \(pickup.appID, privacy: .public): \(reason?.rawValue ?? "skipped", privacy: .public)")
        return pickup
    }

    /// "Never Mind": the user decided not to go into the app. No session starts and no reminders are planned.
    public func changeMind(pickupID: UUID) {
        guard let pickup = store.pickup(id: pickupID) else {
            Log.engine.error("changeMind: unknown pickup \(pickupID.uuidString, privacy: .public)")
            return
        }
        pickup.reason = nil
        pickup.note = nil
        pickup.skipped = false
        pickup.sessionStart = nil
        pickup.sessionEnd = now()
        pickup.endedBy = .changedMind
        store.save()
        reminders?.cancelReminders(pickupID: pickupID)
        Log.engine.info("changed mind \(pickup.appID, privacy: .public)")
    }

    // MARK: Session end

    /// Called by the "Is Closed" automation.
    public func appClosed(appID: String) {
        let date = now()
        let active = store.activeSessions(appID: appID)
        for pickup in active {
            pickup.sessionEnd = date
            pickup.endedBy = .closed
            reminders?.cancelReminders(pickupID: pickup.id)
        }
        store.save()
        Log.engine.info("closed \(appID, privacy: .public): ended \(active.count) session(s)")
    }

    /// "I'm Done for Now".
    public func finish(pickupID: UUID) {
        guard let pickup = store.pickup(id: pickupID) else { return }
        if pickup.sessionEnd == nil { pickup.sessionEnd = now() }
        pickup.endedBy = .done
        store.save()
        reminders?.cancelReminders(pickupID: pickupID)
        Log.engine.info("done \(pickup.appID, privacy: .public)")
    }

    /// "Keep Going": resumes the session (the close automation may have ended it when the reminder
    /// brought us forward) and plans the next nudges. Returns the pickup so the caller can reopen the app.
    @discardableResult
    public func keepGoing(pickupID: UUID) -> Pickup? {
        guard let pickup = store.pickup(id: pickupID) else { return nil }
        let date = now()
        pickup.sessionEnd = nil
        pickup.endedBy = nil
        pickup.keepGoingCount += 1
        if pickup.sessionStart == nil { pickup.sessionStart = date }
        store.save()
        scheduleReminders(for: pickup, from: date)
        noteHandoff(appID: pickup.appID)
        Log.engine.info("keep going \(pickup.appID, privacy: .public) x\(pickup.keepGoingCount)")
        return pickup
    }

    // MARK: Reminders

    /// Plans nudges every `remindAfterMinutes` counted from `anchor`, skipping quiet hours.
    public func reminderPlan(for pickup: Pickup, from anchor: Date) -> ReminderPlan? {
        guard settings.remindInWatchedApps, let start = pickup.sessionStart else { return nil }
        let step = TimeInterval(settings.remindAfterMinutes * 60)
        var fires: [ReminderFire] = []
        for index in 1...ReminderPlan.maxFires {
            let date = anchor.addingTimeInterval(step * Double(index))
            if settings.isQuiet(at: date, calendar: calendar) { continue }
            let minutes = Int((date.timeIntervalSince(start) / 60).rounded())
            fires.append(ReminderFire(date: date, minutes: minutes, index: index))
        }
        guard !fires.isEmpty else { return nil }
        return ReminderPlan(pickupID: pickup.id, appID: pickup.appID, appName: pickup.appName,
                            reasonLabel: pickup.record.reasonLabel, fires: fires)
    }

    private func scheduleReminders(for pickup: Pickup, from anchor: Date) {
        reminders?.cancelReminders(pickupID: pickup.id)
        guard let plan = reminderPlan(for: pickup, from: anchor) else { return }
        reminders?.schedule(plan)
    }

    /// Re-plans nudges for running sessions after the reminder settings change.
    public func refreshReminders() {
        let date = now()
        for pickup in store.activeSessions() {
            reminders?.cancelReminders(pickupID: pickup.id)
            guard let start = pickup.sessionStart, let plan = reminderPlan(for: pickup, from: start) else { continue }
            let upcoming = plan.fires.filter { $0.date > date }
            guard !upcoming.isEmpty else { continue }
            var trimmed = plan
            trimmed.fires = upcoming
            reminders?.schedule(trimmed)
        }
    }

    // MARK: Dates

    public func dayInterval(for date: Date) -> DateInterval {
        calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86_400)
    }

    public func weekInterval(for date: Date) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
    }
}
