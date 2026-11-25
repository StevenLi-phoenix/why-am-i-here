import SwiftUI
import UIKit
import WAIHCore

enum AppTab: Hashable {
    case today, reflection, settings
}

struct CheckInContext: Identifiable, Equatable {
    let id: UUID
    let app: WatchedApp
    let pickupNumber: Int
    /// A walkthrough started from the setup guide; nothing is recorded.
    var isPreview = false
}

struct ReminderContext: Identifiable, Equatable {
    let id: UUID
    let app: WatchedApp
    let reasonLabel: String?
    let minutes: Int
    var isPreview = false

    var title: String { ReminderPlan.title(reasonLabel: reasonLabel, appName: app.name) }
}

enum Overlay: Identifiable, Equatable {
    case checkIn(CheckInContext)
    case reminder(ReminderContext)

    var id: String {
        switch self {
        case .checkIn(let context): "checkin-\(context.id)"
        case .reminder(let context): "reminder-\(context.id)"
        }
    }
}

/// App-wide state: settings, the screens presented over the tabs, and cached statistics.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let launch: LaunchOptions
    let store: PickupStore
    let engine: CheckInEngine
    let notifications: NotificationManager
    private let settingsStore: SettingsStore

    var settings: WAIHSettings {
        didSet {
            guard settings != oldValue else { return }
            settingsStore.save(settings)
            engine.settings = settings
            let remindersChanged = settings.remindInWatchedApps != oldValue.remindInWatchedApps
                || settings.remindAfterMinutes != oldValue.remindAfterMinutes
                || settings.pauseDuringQuietHours != oldValue.pauseDuringQuietHours
                || settings.quietStartHour != oldValue.quietStartHour
                || settings.quietEndHour != oldValue.quietEndHour
            if remindersChanged { engine.refreshReminders() }
            // A newly watched app needs its setup status.
            if settings.watchedAppIDs != oldValue.watchedAppIDs { refresh() }
            Log.settings.info("settings saved (reminders replanned: \(remindersChanged))")
        }
    }

    var selectedTab: AppTab = .today
    var overlay: Overlay?
    /// Short message shown at the top of the screen, e.g. when a watched app could not be reopened.
    var notice: String?

    private(set) var today: DaySummary
    private(set) var week: WeekSummary
    private(set) var lastCheckIn: LastCheckIn?
    /// False until the first pickup is recorded; drives the setup card on Today.
    private(set) var hasHistory = false
    /// Last time each watched app's automation reported an open, by app id. Absent = never, so the
    /// automation is probably not set up yet.
    private(set) var lastOpens: [String: Date] = [:]

    private var noticeTask: Task<Void, Never>?
    private var didHandleLaunchURL = false

    private init() {
        let launch = LaunchOptions()
        self.launch = launch

        let defaults: UserDefaults
        if launch.uiTesting {
            let suite = "waih.uitesting"
            UserDefaults().removePersistentDomain(forName: suite)
            defaults = UserDefaults(suiteName: suite) ?? .standard
        } else {
            defaults = .standard
        }
        settingsStore = SettingsStore(defaults: defaults)
        var settings = settingsStore.load()
        if launch.uiTesting {
            // Ask on every open so UI tests do not depend on how many opens came before.
            settings.frequency = .everyOpen
        }
        self.settings = settings

        do {
            store = try PickupStore(inMemory: launch.uiTesting || launch.demoData)
        } catch {
            // A store that cannot open on disk still lets the app run for this launch.
            Log.store.fault("persistent store failed, falling back to memory: \(error.localizedDescription, privacy: .public)")
            store = try! PickupStore(inMemory: true)
        }

        notifications = NotificationManager(enabled: !launch.uiTesting)
        engine = CheckInEngine(store: store, settings: settings, reminders: notifications)

        let now = Date()
        today = Stats.day(records: [], on: now, now: now)
        week = Stats.week(records: [], previous: [], now: now)

        if launch.demoData {
            DemoData.seed(store, now: now)
        }
        refresh()
        Log.ui.info("launched uiTesting=\(launch.uiTesting) demoData=\(launch.demoData) pickups=\(self.store.totalCount)")
    }

    // MARK: Statistics

    /// Recomputes the cached summaries. Reads today's records plus two weeks, a few hundred rows at most.
    func refresh() {
        let now = Date()
        let calendar = engine.calendar
        let weekInterval = engine.weekInterval(for: now)
        let previousStart = calendar.date(byAdding: .day, value: -7, to: weekInterval.start) ?? weekInterval.start
        let records = store.records(in: weekInterval)
        let previous = store.records(in: DateInterval(start: previousStart, end: weekInterval.start))

        today = Stats.day(records: records, on: now, now: now, calendar: calendar)
        week = Stats.week(records: records, previous: previous, now: now, calendar: calendar)
        lastCheckIn = Stats.lastCheckIn(store.lastCheckIn()?.record)
        hasHistory = store.totalCount > 0
        // One indexed fetch per watched app; a handful at most.
        var opens: [String: Date] = [:]
        for app in settings.watchedApps {
            if let last = store.lastPickup(appID: app.id, before: .distantFuture) { opens[app.id] = last.openedAt }
        }
        lastOpens = opens
    }

    func becameActive() {
        refresh()
        Task { await notifications.refreshStatus() }
        if !didHandleLaunchURL, let url = launch.openURL {
            didHandleLaunchURL = true
            handle(url: url)
        }
    }

    /// Asks for notification permission once, when reminders are on.
    func requestNotificationsIfNeeded() {
        guard settings.remindInWatchedApps else { return }
        Task { await notifications.requestAuthorizationIfUndetermined() }
    }

    // MARK: Opening a watched app

    /// Called by the "Is Opened" automation. Returns true when the Intent Check must come to the foreground.
    @discardableResult
    func handleAppOpened(appID: String, source: String) -> Bool {
        guard let app = settings.app(id: appID) else {
            Log.intents.error("open from \(source, privacy: .public): unknown app \(appID, privacy: .public)")
            return false
        }
        let outcome = engine.appOpened(app)
        refresh()
        switch outcome {
        case .prompt(let pickupID, let pickupNumber):
            overlay = .checkIn(CheckInContext(id: pickupID, app: app, pickupNumber: pickupNumber))
            return true
        case .passthrough:
            return false
        }
    }

    func handleAppClosed(appID: String) {
        engine.appClosed(appID: appID)
        refresh()
    }

    // MARK: Intent Check

    /// "Continue" (with a reason) or "Skip for Now" (reason nil).
    func completeCheckIn(_ context: CheckInContext, reason: Reason?, note: String?) {
        if context.isPreview {
            // Walk on to the reminder so the whole flow can be seen without waiting.
            let label = PickupRecord(appID: context.app.id, appName: context.app.name, openedAt: Date(),
                                     reason: reason, note: note).reasonLabel
            overlay = .reminder(ReminderContext(id: context.id, app: context.app, reasonLabel: label,
                                                minutes: settings.remindAfterMinutes, isPreview: true))
            return
        }
        engine.completeCheckIn(pickupID: context.id, reason: reason, note: note)
        overlay = nil
        refresh()
        handOff(to: context.app)
    }

    /// "Never Mind": stays out of the watched app (the storyboard's "Maybe not.").
    func changeMind(_ context: CheckInContext) {
        overlay = nil
        selectedTab = .today
        if context.isPreview {
            show(notice: "That was a preview. Nothing was saved.")
            return
        }
        engine.changeMind(pickupID: context.id)
        refresh()
        show(notice: "Nice. \(context.app.name) can wait.")
    }

    // MARK: Gentle Reminder

    func showReminder(pickupID: UUID, minutes: Int?) {
        guard let pickup = store.pickup(id: pickupID) else {
            Log.ui.error("reminder for unknown pickup \(pickupID.uuidString, privacy: .public)")
            return
        }
        let record = pickup.record
        let app = settings.app(id: record.appID) ?? WatchedApp(id: record.appID, name: record.appName, urlScheme: nil)
        let elapsed = Int((record.duration(now: Date()) / 60).rounded())
        overlay = .reminder(ReminderContext(id: pickupID, app: app, reasonLabel: record.reasonLabel,
                                            minutes: minutes ?? max(1, elapsed)))
    }

    /// "I'm Done for Now".
    func finishReminder(_ context: ReminderContext) {
        overlay = nil
        guard !context.isPreview else {
            show(notice: "That was a preview. Nothing was saved.")
            return
        }
        finishSession(pickupID: context.id)
        selectedTab = .today
    }

    /// Ends the session and congratulates the user with a banner that leads to Today.
    func finishSession(pickupID: UUID) {
        engine.finish(pickupID: pickupID)
        refresh()
        notifications.postNiceWork()
    }

    /// "Keep Going".
    func keepGoing(_ context: ReminderContext) {
        overlay = nil
        guard !context.isPreview else {
            show(notice: "That was a preview. Nothing was saved.")
            return
        }
        engine.keepGoing(pickupID: context.id)
        refresh()
        handOff(to: context.app)
    }

    // MARK: Preview

    /// Runs the Intent Check and reminder screens without recording anything.
    func startPreview() {
        let app = settings.watchedApps.first ?? AppCatalog.builtIn[0]
        overlay = .checkIn(CheckInContext(id: UUID(), app: app, pickupNumber: today.pickups + 1, isPreview: true))
    }

    // MARK: Data

    /// Replaces the history with the prototype's sample week, for demos and usability sessions.
    func loadSampleWeek() {
        notifications.cancelAll()
        DemoData.seed(store, now: Date(), calendar: engine.calendar)
        refresh()
        selectedTab = .today
        show(notice: "Sample week loaded.")
        Log.store.notice("sample week loaded from Settings: \(self.store.totalCount) pickups")
    }

    /// Deletes every pickup and restores the default settings, like a fresh install.
    func eraseAll() {
        notifications.cancelAll()
        store.deleteAll()
        settings = WAIHSettings()
        refresh()
        selectedTab = .today
        show(notice: "All data and settings erased.")
        Log.store.notice("erased all data and settings")
    }

    // MARK: Handoff

    /// Sends the user on to the app they were opening.
    private func handOff(to app: WatchedApp) {
        engine.noteHandoff(appID: app.id)
        guard let url = app.launchURL else {
            show(notice: "Checked in. Switch back to \(app.name) to continue.")
            return
        }
        UIApplication.shared.open(url) { [weak self] opened in
            Log.ui.info("handoff to \(app.id, privacy: .public): \(opened ? "opened" : "failed", privacy: .public)")
            if !opened {
                self?.show(notice: "Checked in. Switch back to \(app.name) to continue.")
            }
        }
    }

    func show(notice message: String) {
        notice = message
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    // MARK: Deep links

    /// `whyamihere://ask?app=<id>`, `closed?app=<id>`, `reminder`, `preview`, `preview-reminder`, `today`,
    /// `reflection`, `settings`.
    func handle(url: URL) {
        guard url.scheme == "whyamihere" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let appID = components?.queryItems?.first { $0.name == "app" }?.value
        Log.ui.info("deep link \(url.host() ?? "", privacy: .public) app=\(appID ?? "-", privacy: .public)")
        switch url.host() {
        case "ask":
            if let appID { handleAppOpened(appID: appID, source: "url") }
        case "closed":
            if let appID { handleAppClosed(appID: appID) }
        case "reminder":
            if let active = store.activeSessions().first { showReminder(pickupID: active.id, minutes: nil) }
        case "preview":
            startPreview()
        case "preview-reminder":
            // The reminder half of the preview on its own; used for screenshots.
            let app = settings.watchedApps.first ?? AppCatalog.builtIn[0]
            overlay = .reminder(ReminderContext(id: UUID(), app: app, reasonLabel: Reason.messages.title,
                                                minutes: settings.remindAfterMinutes, isPreview: true))
        case "today":
            overlay = nil
            selectedTab = .today
        case "reflection":
            overlay = nil
            selectedTab = .reflection
        case "settings":
            overlay = nil
            selectedTab = .settings
        default:
            Log.ui.error("unhandled deep link \(url.absoluteString, privacy: .public)")
        }
    }

    // MARK: Notifications

    func handleNotification(kind: String?, action: String, pickupID: UUID?, minutes: Int?) {
        Log.notifications.info("response kind=\(kind ?? "-", privacy: .public) action=\(action, privacy: .public)")
        switch (kind, action) {
        case (NotificationManager.Kind.reminder, NotificationManager.Action.done):
            if let pickupID { finishSession(pickupID: pickupID) }
        case (NotificationManager.Kind.reminder, NotificationManager.Action.keepGoing):
            break // Later nudges are already scheduled.
        case (NotificationManager.Kind.reminder, _):
            if let pickupID { showReminder(pickupID: pickupID, minutes: minutes) }
        case (NotificationManager.Kind.niceWork, _):
            overlay = nil
            selectedTab = .today
            refresh()
        default:
            break
        }
    }

    // MARK: Watched apps

    func setWatched(_ app: WatchedApp, _ watched: Bool) {
        var ids = settings.watchedAppIDs.filter { $0 != app.id }
        if watched { ids.append(app.id) }
        settings.watchedAppIDs = ids
    }

    /// Adds a custom app and starts watching it. Returns false when the name is empty or already taken.
    func addCustomApp(name: String, urlScheme: String) -> Bool {
        guard let app = WatchedApp.custom(name: name, urlScheme: urlScheme),
              settings.app(id: app.id) == nil else { return false }
        settings.customApps.append(app)
        settings.watchedAppIDs.append(app.id)
        return true
    }

    func removeCustomApp(_ app: WatchedApp) {
        settings.customApps.removeAll { $0.id == app.id }
        settings.watchedAppIDs.removeAll { $0 == app.id }
    }
}
