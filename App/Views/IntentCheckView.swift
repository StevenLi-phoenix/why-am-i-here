import SwiftUI
import WAIHCore

/// "Why Are You Here?" — shown before a watched app opens.
struct IntentCheckView: View {
    @Environment(AppModel.self) private var model
    let context: CheckInContext

    @State private var selection: Reason?
    @State private var note = ""
    @State private var draftNote = ""
    @State private var askingForNote = false

    private let paired: [[Reason]] = [
        [.messages, .lookSomethingUp],
        [.workOrSchool, .directions],
        [.checkTheTime, .justBored],
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("Opening \(context.app.name) · Pickup #\(context.pickupNumber) today")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("Why Are You Here?")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.top, 22)

            Spacer(minLength: 20)

            VStack(spacing: 12) {
                ForEach(paired, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(row) { reason in
                            ReasonTile(reason: reason, selected: selection == reason) { select(reason) }
                        }
                    }
                }
                OtherRow(selected: selection == .other, note: note) {
                    draftNote = note
                    askingForNote = true
                }
            }

            Spacer(minLength: 20)

            VStack(spacing: 10) {
                Text("We’ll remind you of this if you stay a while.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondary)
                PrimaryButton(title: "Continue", enabled: selection != nil) {
                    model.completeCheckIn(context, reason: selection, note: note)
                }
                .accessibilityIdentifier("continueButton")
                QuietButton(title: "Skip for Now") {
                    model.completeCheckIn(context, reason: nil, note: nil)
                }
                .accessibilityIdentifier("skipButton")
            }
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: selection)
        .alert("What brings you here?", isPresented: $askingForNote) {
            TextField("Optional", text: $draftNote)
            Button("Cancel", role: .cancel) {}
            Button("OK") {
                note = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
                selection = .other
            }
        }
        .interactiveDismissDisabled()
    }

    private func select(_ reason: Reason) {
        withAnimation(.easeOut(duration: 0.15)) {
            selection = selection == reason ? nil : reason
        }
    }
}

private struct ReasonTile: View {
    let reason: Reason
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    Image(systemName: reason.symbolName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(selected ? .white : Theme.accent)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                Spacer(minLength: 8)
                Text(reason.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 124, alignment: .leading)
            .background(selected ? Theme.accent : Theme.card,
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reason.\(reason.rawValue)")
        .accessibilityLabel(reason.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct OtherRow: View {
    let selected: Bool
    let note: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: Reason.other.symbolName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(selected ? .white : Theme.accent)
                    .frame(width: 24)
                Text(selected && !note.isEmpty ? note : Reason.other.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(selected ? Theme.accent : Theme.card,
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reason.other")
        .accessibilityLabel("Other")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
