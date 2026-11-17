import os

/// Shared loggers. Filter in Console.app with `subsystem:whyamihere`.
public enum Log {
    public static let subsystem = "whyamihere"
    public static let engine = Logger(subsystem: subsystem, category: "engine")
    public static let store = Logger(subsystem: subsystem, category: "store")
    public static let settings = Logger(subsystem: subsystem, category: "settings")
    public static let notifications = Logger(subsystem: subsystem, category: "notifications")
    public static let intents = Logger(subsystem: subsystem, category: "intents")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
}
