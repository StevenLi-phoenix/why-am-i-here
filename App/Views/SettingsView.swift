import SwiftUI
import UIKit
import WAIHCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmSample = false
    @State private var confirmErase = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                // First, because the list drives both the Intent Check and the reminders.
                Section {
                    NavigationLink {
                        WatchedAppsView()
                    } label: {
                        LabeledContent("Watched Apps", value: model.settings.watchedSummary)
                    }
                    .accessibilityIdentifier("watchedApps")
                } header: {
                    SectionTitle("Apps")
                } footer: {
                    Text("The apps that ask why you’re there and remind you later.")
                }

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
                } footer: {
                    Text(model.settings.frequency.detail)
                        .accessibilityIdentifier("frequencyDetail")
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
                    if model.settings.pauseDuringQuietHours {
                        HourPicker(title: "From", hour: $model.settings.quietStartHour)
                            .accessibilityIdentifier("quietStart")
                        HourPicker(title: "To", hour: $model.settings.quietEndHour)
                            .accessibilityIdentifier("quietEnd")
                    }
                } header: {
                    SectionTitle("Quiet Hours")
                } footer: {
                    Text(quietFooter)
                        .accessibilityIdentifier("quietFooter")
                }

                Section {
                    Button("Load Sample Week") { confirmSample = true }
                        .accessibilityIdentifier("loadSample")
                    Button("Erase All Data and Settings", role: .destructive) { confirmErase = true }
                        .accessibilityIdentifier("eraseAll")
                } header: {
                    SectionTitle("Data")
                } footer: {
                    Text("Everything stays on this iPhone. The sample week fills Today and Reflection with made-up pickups, for demos and user testing.")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Replace your history with a sample week?", isPresented: $confirmSample,
                                titleVisibility: .visible) {
                Button("Load Sample Week", role: .destructive) { model.loadSampleWeek() }
                    .accessibilityIdentifier("confirmLoadSample")
            } message: {
                Text("Your own pickups are deleted. Settings stay as they are.")
            }
            .confirmationDialog("Erase all data and settings?", isPresented: $confirmErase,
                                titleVisibility: .visible) {
                Button("Erase", role: .destructive) { model.eraseAll() }
                    .accessibilityIdentifier("confirmErase")
            } message: {
                Text("Every pickup is deleted and settings go back to how they were after installing. Your Shortcuts automations stay in the Shortcuts app.")
            }
            .toggleStyle(SwitchToggleStyle(tint: Theme.switchOn))
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .onChange(of: model.settings.remindInWatchedApps) { _, isOn in
                if isOn { model.requestNotificationsIfNeeded() }
            }
        }
    }
}

extension SettingsView {
    private var quietFooter: String {
        let settings = model.settings
        let window = "from \(Format.hour(settings.quietStartHour)) to \(Format.hour(settings.quietEndHour))"
        guard settings.pauseDuringQuietHours else {
            return "Turn on to stop questions and reminders \(window)."
        }
        if settings.quietStartHour == settings.quietEndHour { return "Pick different start and end times." }
        return "No questions or reminders \(window)."
    }
}

/// One hour of the day, "10 PM", chosen from a menu.
private struct HourPicker: View {
    let title: String
    @Binding var hour: Int

    var body: some View {
        Picker(title, selection: $hour) {
            ForEach(0..<24, id: \.self) { value in
                Text(Format.hour(value)).tag(value)
            }
        }
        .pickerStyle(.menu)
        .tint(Theme.secondary)
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
