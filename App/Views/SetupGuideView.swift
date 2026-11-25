import SwiftUI
import UIKit
import WAIHCore

/// Walks through creating the two Shortcuts automations a watched app needs.
struct SetupGuideView: View {
    @Environment(AppModel.self) private var model

    private var exampleApp: String { model.settings.watchedApps.first?.name ?? "Instagram" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("iOS only lets an app step in when another one opens through the Shortcuts app. Set this up once for each watched app.")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SetupStatusCard()

                GuideCard(title: "Ask when it opens", steps: [
                    "Open Shortcuts and go to the Automation tab.",
                    "Tap + and choose App.",
                    "Pick \(exampleApp), keep “Is Opened” checked, and choose Run Immediately.",
                    "Tap Next, then New Blank Automation.",
                    "Search for “Ask Why I’m Here”, add it, and set App to \(exampleApp).",
                    "Open \(exampleApp) to try it. When it asks why you’re here, it works, and the list above says so.",
                ])

                GuideCard(title: "Stop the clock when it closes", steps: [
                    "Create another App automation for \(exampleApp).",
                    "This time check only “Is Closed”, and choose Run Immediately.",
                    "Add “Mark App Closed” and set App to \(exampleApp).",
                ])

                Button {
                    if let url = URL(string: "shortcuts://") { UIApplication.shared.open(url) }
                } label: {
                    Text("Open Shortcuts")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("openShortcuts")

                Button("Try a Check-In") { model.startPreview() }
                    .font(.system(size: 17))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("guidePreview")
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.vertical, 12)
        }
        .background(Color.black)
        .navigationTitle("Set Up Automations")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.requestNotificationsIfNeeded() }
    }
}

/// Whether each watched app's automation has reported an open yet, so the user can tell if setup worked.
private struct SetupStatusCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(text: "Your Watched Apps")
                if model.settings.watchedApps.isEmpty {
                    Text("No apps are watched. Choose some in Settings → Watched Apps.")
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                }
                ForEach(model.settings.watchedApps) { app in
                    SetupStatusRow(app: app, lastOpen: model.lastOpens[app.id])
                }
            }
        }
        .accessibilityIdentifier("setupStatus")
    }
}

/// "Instagram / Working · last opened today at 9:41 AM" or "TikTok / No opens yet. Set up its automation."
struct SetupStatusRow: View {
    let app: WatchedApp
    let lastOpen: Date?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: lastOpen == nil ? "circle.dashed" : "checkmark.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(lastOpen == nil ? Theme.secondary : Theme.switchOn)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(SetupStatusRow.status(lastOpen))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("status.\(app.id)")
    }

    static func status(_ lastOpen: Date?) -> String {
        guard let lastOpen else { return "No opens yet. Set up its automation." }
        return "Working · last opened \(Format.lastSeen(lastOpen, now: Date()))"
    }
}

private struct GuideCard: View {
    let title: String
    let steps: [String]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(text: title)
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 18, alignment: .leading)
                        Text(step)
                            .font(.system(size: 17))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
