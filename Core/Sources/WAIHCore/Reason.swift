import Foundation

/// The answers offered on the Intent Check screen, in display order.
public enum Reason: String, CaseIterable, Codable, Sendable, Identifiable {
    case messages
    case lookSomethingUp
    case workOrSchool
    case directions
    case checkTheTime
    case justBored
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .messages: "Messages"
        case .lookSomethingUp: "Look Something Up"
        case .workOrSchool: "Work or School"
        case .directions: "Directions"
        case .checkTheTime: "Check the Time"
        case .justBored: "Just Bored"
        case .other: "Other…"
        }
    }

    /// Title used in summaries, where the trailing ellipsis of "Other…" reads wrong.
    public var summaryTitle: String {
        self == .other ? "Other" : title
    }

    /// SF Symbol name.
    public var symbolName: String {
        switch self {
        case .messages: "message.fill"
        case .lookSomethingUp: "magnifyingglass"
        case .workOrSchool: "briefcase.fill"
        case .directions: "location.fill"
        case .checkTheTime: "clock.fill"
        case .justBored: "moon.zzz.fill"
        case .other: "ellipsis"
        }
    }

    /// "Just Bored" is the only answer that counts as a mindless pickup.
    public var isIntentional: Bool { self != .justBored }
}
