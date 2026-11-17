import Foundation

/// An app the user wants to be asked about. `urlScheme` is how we hand the user back to it after a check-in.
public struct WatchedApp: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var urlScheme: String?

    public init(id: String, name: String, urlScheme: String?) {
        self.id = id
        self.name = name
        self.urlScheme = urlScheme
    }

    public var launchURL: URL? {
        guard let scheme = urlScheme?.trimmingCharacters(in: .whitespaces), !scheme.isEmpty else { return nil }
        let bare = scheme.replacingOccurrences(of: "://", with: "").replacingOccurrences(of: ":", with: "")
        return URL(string: "\(bare)://")
    }

    /// Builds a custom app from user input; the id is derived from the name so it stays stable across edits of the scheme.
    public static func custom(name: String, urlScheme: String) -> WatchedApp? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let slug = trimmed.lowercased().unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }
            .joined()
            .split(separator: "-").joined(separator: "-")
        guard !trimmed.isEmpty, !slug.isEmpty else { return nil }
        let scheme = urlScheme.trimmingCharacters(in: .whitespacesAndNewlines)
        return WatchedApp(id: "custom-\(slug)", name: trimmed, urlScheme: scheme.isEmpty ? nil : scheme)
    }
}

public enum AppCatalog {
    /// URL schemes are the ones commonly documented by the community; none are published by Apple.
    /// When a scheme fails to open, the app tells the user to switch back manually.
    public static let builtIn: [WatchedApp] = [
        WatchedApp(id: "instagram", name: "Instagram", urlScheme: "instagram"),
        WatchedApp(id: "tiktok", name: "TikTok", urlScheme: "snssdk1233"),
        WatchedApp(id: "youtube", name: "YouTube", urlScheme: "youtube"),
        WatchedApp(id: "x", name: "X", urlScheme: "twitter"),
        WatchedApp(id: "facebook", name: "Facebook", urlScheme: "fb"),
        WatchedApp(id: "reddit", name: "Reddit", urlScheme: "reddit"),
        WatchedApp(id: "snapchat", name: "Snapchat", urlScheme: "snapchat"),
        WatchedApp(id: "threads", name: "Threads", urlScheme: "barcelona"),
        WatchedApp(id: "discord", name: "Discord", urlScheme: "discord"),
        WatchedApp(id: "twitch", name: "Twitch", urlScheme: "twitch"),
        WatchedApp(id: "netflix", name: "Netflix", urlScheme: "nflx"),
        WatchedApp(id: "pinterest", name: "Pinterest", urlScheme: "pinterest"),
        WatchedApp(id: "linkedin", name: "LinkedIn", urlScheme: "linkedin"),
        WatchedApp(id: "whatsapp", name: "WhatsApp", urlScheme: "whatsapp"),
        WatchedApp(id: "telegram", name: "Telegram", urlScheme: "tg"),
        WatchedApp(id: "wechat", name: "WeChat", urlScheme: "weixin"),
        WatchedApp(id: "bilibili", name: "Bilibili", urlScheme: "bilibili"),
        WatchedApp(id: "xiaohongshu", name: "Xiaohongshu", urlScheme: "xhsdiscover"),
        WatchedApp(id: "douyin", name: "Douyin", urlScheme: "snssdk1128"),
        WatchedApp(id: "weibo", name: "Weibo", urlScheme: "sinaweibo"),
    ]
}
