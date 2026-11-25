import SwiftUI
import WAIHCore

/// Chooses which apps prompt a check-in, and links to the automation setup.
struct WatchedAppsView: View {
    @Environment(AppModel.self) private var model
    @State private var showAddApp = false

    var body: some View {
        List {
            Section {
                NavigationLink("Set Up Automations") { SetupGuideView() }
                    .accessibilityIdentifier("setupGuide")
                Button("Try a Check-In") { model.startPreview() }
                    .accessibilityIdentifier("previewCheckIn")
            } footer: {
                Text("Each watched app needs its own automation in the Shortcuts app.")
            }

            Section {
                ForEach(AppCatalog.builtIn) { app in
                    AppRow(app: app, watched: model.settings.isWatched(app.id), lastOpen: model.lastOpens[app.id]) {
                        model.setWatched(app, !model.settings.isWatched(app.id))
                    }
                }
            } header: {
                SectionTitle("Apps")
            }

            Section {
                ForEach(model.settings.customApps) { app in
                    AppRow(app: app, watched: model.settings.isWatched(app.id), lastOpen: model.lastOpens[app.id]) {
                        model.setWatched(app, !model.settings.isWatched(app.id))
                    }
                }
                .onDelete { offsets in
                    offsets.map { model.settings.customApps[$0] }.forEach(model.removeCustomApp)
                }
                Button("Add App…") { showAddApp = true }
                    .accessibilityIdentifier("addApp")
            } header: {
                SectionTitle("Your Apps")
            } footer: {
                Text("Add any app by name. Its URL scheme lets Why Am I Here? send you back to it after a check-in.")
            }
        }
        .navigationTitle("Watched Apps")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .sheet(isPresented: $showAddApp) {
            AddAppSheet()
                .environment(model)
                .preferredColorScheme(.dark)
        }
    }
}

private struct AppRow: View {
    let app: WatchedApp
    let watched: Bool
    let lastOpen: Date?
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).foregroundStyle(.white)
                    // Watched apps say whether their automation has reached us yet.
                    if watched {
                        Text(SetupStatusRow.status(lastOpen))
                            .font(.system(size: 13))
                            .foregroundStyle(lastOpen == nil ? Theme.secondary : Theme.switchOn)
                    }
                }
                Spacer()
                if watched {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("app.\(app.id)")
        .accessibilityAddTraits(watched ? .isSelected : [])
    }
}

private struct AddAppSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var scheme = ""
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("customName")
                    TextField("URL Scheme (optional)", text: $scheme)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .accessibilityIdentifier("customScheme")
                } footer: {
                    Text(failed
                         ? "An app with this name is already in the list."
                         : "Example: “instagram” opens instagram://. Without a scheme you switch back to the app yourself.")
                        .foregroundStyle(failed ? Color.red : Theme.secondary)
                }
            }
            .navigationTitle("Add App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if model.addCustomApp(name: name, urlScheme: scheme) {
                            dismiss()
                        } else {
                            failed = true
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
