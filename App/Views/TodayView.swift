import SwiftUI
import WAIHCore

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var showSetup = false

    var body: some View {
        let today = model.today
        ScrollView {
            VStack(spacing: 0) {
                ScreenHeader(eyebrow: Format.dayHeader(today.date), title: "Today")

                IntentionalRing(percent: today.intentionalPercent)
                    .padding(.top, 31)

                StatTriple(items: [
                    .init(value: Format.duration(today.screenTime), label: "Screen Time"),
                    .init(value: "\(today.pickups)", label: "Pickups"),
                    .init(value: "\(today.mindless)", label: "Mindless"),
                ])
                .padding(.top, 30)

                if !model.hasHistory {
                    SetupCard { showSetup = true }
                        .padding(.top, 31)
                } else {
                    TopReasonsCard(reasons: today.topReasons)
                        .padding(.top, 31)
                }

                WeekCard(week: model.week) { model.selectedTab = .reflection }
                    .padding(.top, 30)

                if let last = model.lastCheckIn {
                    Text("Last check-in: \(last.label) · \(Format.time(last.date))")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 31)
                        .accessibilityIdentifier("lastCheckIn")
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .background(Color.black)
        .sheet(isPresented: $showSetup) {
            NavigationStack {
                SetupGuideView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSetup = false }
                        }
                    }
            }
            .environment(model)
            .preferredColorScheme(.dark)
        }
    }
}

private struct IntentionalRing: View {
    let percent: Int?

    var body: some View {
        ZStack {
            ProgressRing(progress: Double(percent ?? 0) / 100, lineWidth: 26)
            VStack(spacing: 0) {
                Text(percent.map { "\($0)%" } ?? "–")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("intentionalPercent")
                Text(percent == nil ? "No check-ins yet" : "Intentional")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
            }
        }
        .frame(width: 252, height: 252)
        .accessibilityElement(children: .combine)
    }
}

private struct TopReasonsCard: View {
    let reasons: [ReasonStat]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                CardTitle(text: "Top Reasons")
                if reasons.isEmpty {
                    Text("Reasons you give today will show up here.")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(reasons) { stat in
                        ReasonRow(stat: stat, trailing: "\(stat.count)", barWidth: 112, trailingWidth: 28)
                            .frame(height: 36)
                    }
                }
            }
        }
    }
}

/// "This Week / Down 8%" with a seven-bar sparkline; opens Reflection.
private struct WeekCard: View {
    let week: WeekSummary
    let action: () -> Void

    private var headline: String {
        if let change = week.changePercent { return Format.trend(change) }
        return week.pickups == 1 ? "1 Pickup" : "\(week.pickups) Pickups"
    }

    var body: some View {
        Button(action: action) {
            Card {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        CardTitle(text: "This Week")
                        Text(headline)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer(minLength: 8)
                    MiniChart(days: week.days, highlight: week.busiestIndex)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("weekCard")
        .accessibilityLabel("This week, \(headline). Opens Reflection.")
    }
}

private struct MiniChart: View {
    let days: [DayCount]
    let highlight: Int?

    var body: some View {
        let top = max(1, days.map(\.count).max() ?? 1)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                Capsule()
                    .fill(index == highlight ? Theme.accent : Color.white.opacity(day.count == 0 ? 0.16 : 0.42))
                    .frame(width: 7, height: max(7, 44 * CGFloat(day.count) / CGFloat(top)))
            }
        }
        .frame(height: 44, alignment: .bottom)
    }
}

/// Shown until the first pickup is recorded.
private struct SetupCard: View {
    let action: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(text: "Finish Setup")
                Text("Add a Shortcuts automation so Why Am I Here? can ask when you open a watched app.")
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: action) {
                    Text("Show Me How")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("setupButton")
            }
        }
    }
}
