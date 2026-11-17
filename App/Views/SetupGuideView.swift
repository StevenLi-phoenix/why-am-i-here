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

                GuideCard(title: "Ask when it opens", steps: [
                    "Open Shortcuts and go to the Automation tab.",
                    "Tap + and choose App.",
                    "Pick \(exampleApp), keep “Is Opened” checked, and choose Run Immediately.",
                    "Tap Next, then New Blank Automation.",
                    "Search for “Ask Why I’m Here”, add it, and set App to \(exampleApp).",
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
