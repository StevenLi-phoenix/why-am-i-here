import Foundation

public enum PromptFrequency: String, Codable, CaseIterable, Sendable, Identifiable {
    case everyOpen
    case everyThirdOpen
    case afterThirtyMinutesAway

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .everyOpen: "Every Open"
        case .everyThirdOpen: "Every 3rd Open"
        case .afterThirtyMinutesAway: "After 30+ Minutes Away"
        }
    }
}

public struct WAIHSettings: Codable, Equatable, Sendable {
    public static let remindMinutesRange = 5...60
    public static let remindMinutesStep = 5
    /// How long a watched app must have been closed for `.afterThirtyMinutesAway` to ask again.
    public static let awayThreshold: TimeInterval = 30 * 60

    public var askBeforeWatchedApps = true
    public var frequency: PromptFrequency = .everyThirdOpen
    public var remindInWatchedApps = true
    public var remindAfterMinutes = 15
    public var watchedAppIDs: [String] = ["instagram", "tiktok"]
    public var customApps: [WatchedApp] = []
    public var pauseDuringQuietHours = false
    public var quietStartHour = 22
    public var quietEndHour = 7

    public init() {}

    // Decodes field by field so settings saved by an older build keep loading after new fields are added.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WAIHSettings()
        askBeforeWatchedApps = try c.decodeIfPresent(Bool.self, forKey: .askBeforeWatchedApps) ?? d.askBeforeWatchedApps
        frequency = try c.decodeIfPresent(PromptFrequency.self, forKey: .frequency) ?? d.frequency
        remindInWatchedApps = try c.decodeIfPresent(Bool.self, forKey: .remindInWatchedApps) ?? d.remindInWatchedApps
        let minutes = try c.decodeIfPresent(Int.self, forKey: .remindAfterMinutes) ?? d.remindAfterMinutes
        remindAfterMinutes = min(max(minutes, Self.remindMinutesRange.lowerBound), Self.remindMinutesRange.upperBound)
        watchedAppIDs = try c.decodeIfPresent([String].self, forKey: .watchedAppIDs) ?? d.watchedAppIDs
        customApps = try c.decodeIfPresent([WatchedApp].self, forKey: .customApps) ?? d.customApps
        pauseDuringQuietHours = try c.decodeIfPresent(Bool.self, forKey: .pauseDuringQuietHours) ?? d.pauseDuringQuietHours
        quietStartHour = try c.decodeIfPresent(Int.self, forKey: .quietStartHour) ?? d.quietStartHour
        quietEndHour = try c.decodeIfPresent(Int.self, forKey: .quietEndHour) ?? d.quietEndHour
    }

    /// Built-in apps followed by the user's own, in catalog order.
    public var allApps: [WatchedApp] { AppCatalog.builtIn + customApps }

    public var watchedApps: [WatchedApp] {
        let watched = Set(watchedAppIDs)
        return allApps.filter { watched.contains($0.id) }
    }

    public func app(id: String) -> WatchedApp? {
        allApps.first { $0.id == id }
    }

    public func isWatched(_ id: String) -> Bool { watchedAppIDs.contains(id) }

    /// Summary shown in the Watched Apps row, e.g. "Instagram, TikTok".
    public var watchedSummary: String {
        let names = watchedApps.map(\.name)
        switch names.count {
        case 0: return "None"
        case 1...2: return names.joined(separator: ", ")
        default: return "\(names[0]), \(names[1]) + \(names.count - 2)"
        }
    }

    /// True when prompts are paused at `date`. The window may cross midnight (10 PM to 7 AM).
    public func isQuiet(at date: Date, calendar: Calendar = .current) -> Bool {
        guard pauseDuringQuietHours, quietStartHour != quietEndHour else { return false }
        let hour = calendar.component(.hour, from: date)
        if quietStartHour < quietEndHour {
            return hour >= quietStartHour && hour < quietEndHour
        }
        return hour >= quietStartHour || hour < quietEndHour
    }

    /// "From 10 PM to 7 AM."
    public var quietHoursDescription: String {
        "From \(Format.hour(quietStartHour)) to \(Format.hour(quietEndHour))."
    }
}

/// Persists settings as one JSON blob in UserDefaults.
public final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "waih.settings.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> WAIHSettings {
        guard let data = defaults.data(forKey: key) else { return WAIHSettings() }
        do {
            return try JSONDecoder().decode(WAIHSettings.self, from: data)
        } catch {
            Log.settings.error("settings decode failed, using defaults: \(error.localizedDescription, privacy: .public)")
            return WAIHSettings()
        }
    }

    public func save(_ settings: WAIHSettings) {
        do {
            defaults.set(try JSONEncoder().encode(settings), forKey: key)
        } catch {
            Log.settings.error("settings encode failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
