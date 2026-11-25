import Foundation
import UserNotifications
import WAIHCore

/// Schedules the "Still here?" nudges and routes taps on them back into the app.
@MainActor
@Observable
final class NotificationManager: NSObject, ReminderScheduling, UNUserNotificationCenterDelegate {
    enum Kind {
        static let reminder = "reminder"
        static let niceWork = "niceWork"
    }

    enum Action {
        static let done = "waih.done"
        static let keepGoing = "waih.keepGoing"
    }

    private static let reminderCategory = "waih.reminder"

    private(set) var status: UNAuthorizationStatus = .notDetermined
    private let enabled: Bool
    @ObservationIgnored private let center = UNUserNotificationCenter.current()

    /// With `enabled` false (UI tests) nothing is scheduled and permission is never requested.
    init(enabled: Bool) {
        self.enabled = enabled
        super.init()
        guard enabled else { return }
        center.delegate = self
        let done = UNNotificationAction(identifier: Action.done, title: "I’m Done for Now")
        let keepGoing = UNNotificationAction(identifier: Action.keepGoing, title: "Keep Going")
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.reminderCategory, actions: [done, keepGoing], intentIdentifiers: []),
        ])
    }

    var isDenied: Bool { status == .denied }

    func refreshStatus() async {
        guard enabled else { return }
        status = await center.notificationSettings().authorizationStatus
    }

    func requestAuthorizationIfUndetermined() async {
        guard enabled else { return }
        await refreshStatus()
        guard status == .notDetermined else { return }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            Log.notifications.info("authorization granted=\(granted)")
        } catch {
            Log.notifications.error("authorization failed: \(error.localizedDescription, privacy: .public)")
        }
        await refreshStatus()
    }

    // MARK: ReminderScheduling

    func schedule(_ plan: ReminderPlan) {
        guard enabled else { return }
        for fire in plan.fires {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = "\(fire.minutes) minutes on \(plan.appName) so far. No pressure. Just checking in."
            content.sound = .default
            content.categoryIdentifier = Self.reminderCategory
            content.userInfo = ["kind": Kind.reminder, "pickupID": plan.pickupID.uuidString, "minutes": fire.minutes]
            let interval = max(1, fire.date.timeIntervalSinceNow)
            let request = UNNotificationRequest(
                identifier: Self.identifier(plan.pickupID, fire.index), content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
            center.add(request) { error in
                if let error {
                    Log.notifications.error("schedule failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        Log.notifications.info("scheduled \(plan.fires.count) reminder(s) for \(plan.appID, privacy: .public)")
    }

    func cancelReminders(pickupID: UUID) {
        guard enabled else { return }
        let identifiers = (1...ReminderPlan.maxFires).map { Self.identifier(pickupID, $0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    /// Clears every pending and delivered notification; used when the history is erased or replaced.
    func cancelAll() {
        guard enabled else { return }
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        Log.notifications.info("all notifications cancelled")
    }

    /// The banner shown after "I'm Done for Now".
    func postNiceWork() {
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Why Am I Here?"
        content.body = "Nice work. Tap to see today’s usage."
        content.userInfo = ["kind": Kind.niceWork]
        let request = UNNotificationRequest(
            identifier: "waih.niceWork", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        center.add(request) { error in
            if let error {
                Log.notifications.error("nice-work banner failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func identifier(_ pickupID: UUID, _ index: Int) -> String {
        "waih.reminder.\(pickupID.uuidString).\(index)"
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Shown even while the app is in front, so "Nice work" appears right after tapping Done.
        completionHandler([.banner, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let kind = info["kind"] as? String
        let pickupID = (info["pickupID"] as? String).flatMap(UUID.init(uuidString:))
        let minutes = info["minutes"] as? Int
        let action = response.actionIdentifier
        Task { @MainActor in
            AppModel.shared.handleNotification(kind: kind, action: action, pickupID: pickupID, minutes: minutes)
            completionHandler()
        }
    }
}
