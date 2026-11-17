import Foundation
import SwiftData

public enum SessionEnd: String, Codable, Sendable {
    /// The user tapped "I'm Done for Now".
    case done
    /// The "Is Closed" automation reported the app closed.
    case closed
    /// A newer open arrived while this session was still marked active.
    case stale
}

/// One open of a watched app, with the check-in answer and the time spent afterwards.
@Model
public final class Pickup {
    #Index<Pickup>([\.openedAt], [\.appID, \.openedAt])

    public var id: UUID
    public var appID: String
    public var appName: String
    public var openedAt: Date
    /// Whether the Intent Check screen was shown for this open.
    public var prompted: Bool
    public var reasonRaw: String?
    /// Free text entered for "Other…".
    public var note: String?
    public var skipped: Bool
    public var sessionStart: Date?
    public var sessionEnd: Date?
    public var endedByRaw: String?
    /// Times the user chose "Keep Going".
    public var keepGoingCount: Int

    public init(appID: String, appName: String, openedAt: Date, prompted: Bool) {
        self.id = UUID()
        self.appID = appID
        self.appName = appName
        self.openedAt = openedAt
        self.prompted = prompted
        self.skipped = false
        self.keepGoingCount = 0
    }

    public var reason: Reason? {
        get { reasonRaw.flatMap(Reason.init(rawValue:)) }
        set { reasonRaw = newValue?.rawValue }
    }

    public var endedBy: SessionEnd? {
        get { endedByRaw.flatMap(SessionEnd.init(rawValue:)) }
        set { endedByRaw = newValue?.rawValue }
    }

    public var record: PickupRecord {
        PickupRecord(id: id, appID: appID, appName: appName, openedAt: openedAt, prompted: prompted,
                     reason: reason, note: note, skipped: skipped,
                     sessionStart: sessionStart, sessionEnd: sessionEnd)
    }
}

/// Value snapshot of a `Pickup`; all statistics are computed from these.
public struct PickupRecord: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var appID: String
    public var appName: String
    public var openedAt: Date
    public var prompted: Bool
    public var reason: Reason?
    public var note: String?
    public var skipped: Bool
    public var sessionStart: Date?
    public var sessionEnd: Date?

    public init(id: UUID = UUID(), appID: String, appName: String, openedAt: Date, prompted: Bool = true,
                reason: Reason? = nil, note: String? = nil, skipped: Bool = false,
                sessionStart: Date? = nil, sessionEnd: Date? = nil) {
        self.id = id
        self.appID = appID
        self.appName = appName
        self.openedAt = openedAt
        self.prompted = prompted
        self.reason = reason
        self.note = note
        self.skipped = skipped
        self.sessionStart = sessionStart
        self.sessionEnd = sessionEnd
    }

    /// Opened out of boredom, or went in without naming a reason.
    public var isMindless: Bool { skipped || reason == .justBored }
    public var isIntentional: Bool { reason?.isIntentional ?? false }

    /// What the reminder quotes back: the typed note for "Other…", else the reason title.
    public var reasonLabel: String? {
        guard let reason else { return nil }
        if reason == .other {
            let text = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? reason.summaryTitle : text
        }
        return reason.title
    }

    /// Time spent in the app. A session still running counts up to `now`.
    public func duration(now: Date) -> TimeInterval {
        guard let sessionStart else { return 0 }
        return max(0, (sessionEnd ?? now).timeIntervalSince(sessionStart))
    }
}
