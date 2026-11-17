import AppIntents
import WAIHCore

/// Run from a Shortcuts automation with the trigger "When [App] is closed".
struct MarkAppClosedIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark App Closed"
    static let description = IntentDescription(
        "Tells Why Am I Here? that you left a watched app, so screen time stops counting and reminders are cancelled. Add it to an automation that runs when the app is closed.",
        categoryName: "Check-In")

    static let supportedModes: IntentModes = [.background]

    @Parameter(title: "App", description: "The app that was just closed.")
    var app: WatchedAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$app) as closed")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.handleAppClosed(appID: app.id)
        Log.intents.info("MarkAppClosed \(app.id, privacy: .public)")
        return .result()
    }
}
