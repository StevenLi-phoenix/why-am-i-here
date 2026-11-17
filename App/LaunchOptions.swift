import Foundation

/// Switches read from launch arguments; used by UI tests and for taking screenshots.
struct LaunchOptions {
    /// Keeps data in memory and settings in a throwaway suite, and never asks for notification permission.
    var uiTesting = false
    /// Fills the store with the sample history from the prototype.
    var demoData = false
    /// Deep link to open right after launch, e.g. `whyamihere://ask?app=instagram`.
    var openURL: URL?

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        uiTesting = arguments.contains("-uiTesting")
        demoData = arguments.contains("-demoData")
        if let index = arguments.firstIndex(of: "-openURL"), arguments.indices.contains(index + 1) {
            openURL = URL(string: arguments[index + 1])
        }
    }
}
