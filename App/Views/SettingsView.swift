import SwiftUI
import UIKit
import WAIHCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Toggle("Ask Why Before Watched Apps", isOn: $model.settings.askBeforeWatchedApps)
                        .accessibilityIdentifier("askToggle")
                } header: {
                    SectionTitle("Intent Check")
                } footer: {
                    Text("Asks when you open an app you chose to watch.")
                }

                Section {
                    ForEach(PromptFrequency.allCases) { frequency in
                        Button {
                            model.settings.frequency = frequency
                        } label: {
                            HStack {
                                Text(frequency.title).foregroundStyle(.white)
                                Spacer()
                                if model.settings.frequency == frequency {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("frequency.\(frequency.rawValue)")
                        .accessibilityAddTraits(model.settings.frequency == frequency ? .isSelected : [])
                    }
                } header: {
                    SectionTitle("How Often")
                }
                .disabled(!model.settings.askBeforeWatchedApps)

                Section {
                    Toggle("Remind Me in Watched Apps", isOn: $model.settings.remindInWatchedApps)
                        .accessibilityIdentifier("remindToggle")
                    HStack {
                        Text("Remind After (Minutes)")
                        Spacer()
                        Text("\(model.settings.remindAfterMinutes)")
                            .foregroundStyle(Theme.secondary)
                            .monospacedDigit()
                            .accessibilityIdentifier("remindMinutes")
                        Stepper("Remind After (Minutes)", value: $model.settings.remindAfterMinutes,
                                in: WAIHSettings.remindMinutesRange, step: WAIHSettings.remindMinutesStep)
                            .labelsHidden()
                            .accessibilityIdentifier("remindStepper")
                    }
                    .disabled(!model.settings.remindInWatchedApps)
                    NavigationLink {
                        WatchedAppsView()
                    } label: {
                        LabeledContent("Watched Apps", value: model.settings.watchedSummary)
                    }
                    .accessibilityIdentifier("watchedApps")
                } header: {
                    SectionTitle("Gentle Reminder")
                } footer: {
                    if model.settings.remindInWatchedApps, model.notifications.isDenied {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notifications are turned off, so reminders can’t be delivered.")
                            Button("Open Notification Settings") {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.footnote)
                        }
                    }
                }

                Section {
                    Toggle("Pause All Prompts", isOn: $model.settings.pauseDuringQuietHours)
                        .accessibilityIdentifier("quietToggle")
                } header: {
                    SectionTitle("Quiet Hours")
                } footer: {
                    Text(model.settings.quietHoursDescription)
                }
            }
            .navigationTitle("Settings")
            .toggleStyle(SwitchToggleStyle(tint: Theme.switchOn))
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .onChange(of: model.settings.remindInWatchedApps) { _, isOn in
                if isOn { model.requestNotificationsIfNeeded() }
            }
        }
    }
}

/// Section header in the prototype's style: sentence case, 17 pt semibold.
struct SectionTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.secondary)
            .textCase(nil)
    }
}
