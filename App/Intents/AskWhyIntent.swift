import AppIntents
import WAIHCore

/// Run from a Shortcuts automation with the trigger "When [App] is opened".
struct AskWhyIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Why I’m Here"
    static let description = IntentDescription(
        "Asks why you are opening a watched app. Add it to an automation that runs when the app is opened.",
        categoryName: "Check-In")

    /// Stays in the background unless the Intent Check has to be shown.
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Parameter(title: "App", description: "The app that was just opened.")
    var app: WatchedAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Ask why I’m opening \(\.$app)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let shouldAsk = AppModel.shared.handleAppOpened(appID: app.id, source: "intent")
        Log.intents.info("AskWhy \(app.id, privacy: .public): ask=\(shouldAsk)")
        if shouldAsk {
            try await continueInForeground(nil, alwaysConfirm: false)
        }
        return .result()
    }
}
