import SwiftUI
import WAIHCore

/// "Still here for “Messages”?" — opened from a reminder notification.
struct GentleReminderView: View {
    @Environment(AppModel.self) private var model
    let context: ReminderContext

    var body: some View {
        VStack(spacing: 0) {
            Text(context.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(3)
                .padding(.top, 38)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("reminderTitle")

            Spacer(minLength: 24)

            ZStack {
                ProgressRing(progress: 1, lineWidth: 18, track: .clear)
                VStack(spacing: 0) {
                    Text("\(context.minutes)")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                    Text(context.minutes == 1 ? "minute" : "minutes")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                }
            }
            .frame(width: 232, height: 232)
            .accessibilityElement(children: .combine)

            VStack(spacing: 2) {
                Text("on \(context.app.name) so far.")
                    .foregroundStyle(.white)
                Text("No pressure. Just checking in.")
                    .foregroundStyle(Theme.secondary)
            }
            .font(.system(size: 17))
            .padding(.top, 24)

            Spacer(minLength: 24)

            VStack(spacing: 6) {
                PrimaryButton(title: "I’m Done for Now") { model.finishReminder(context) }
                    .accessibilityIdentifier("doneButton")
                QuietButton(title: "Keep Going") { model.keepGoing(context) }
                    .accessibilityIdentifier("keepGoingButton")
            }
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .interactiveDismissDisabled()
    }
}
