import SwiftUI
import WAIHCore

struct ReflectionView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let week = model.week
        ScrollView {
            VStack(spacing: 0) {
                ScreenHeader(eyebrow: Format.weekRange(week.interval), title: "Reflection")

                StatTriple(items: [
                    .init(value: Format.duration(week.screenTime, compact: true), label: "Screen Time"),
                    .init(value: "\(week.pickups)", label: "Pickups"),
                    .init(value: week.changePercent.map(Format.signedPercent) ?? "–", label: "vs Last Week"),
                ])
                .padding(.top, 33)

                DailyPickupsCard(week: week)
                    .padding(.top, 33)

                WeeklyReasonsCard(reasons: week.topReasons)
                    .padding(.top, 33)

                InsightCard(text: week.insight) { model.selectedTab = .settings }
                    .padding(.top, 33)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .background(Color.black)
    }
}

private struct DailyPickupsCard: View {
    let week: WeekSummary
    /// The day whose count is shown; nil shows the busiest day.
    @State private var selected: Int?

    private let plotHeight: CGFloat = 132
    private let labelSpace: CGFloat = 24

    var body: some View {
        let top = max(1, week.days.map(\.count).max() ?? 1)
        let usable = plotHeight - labelSpace
        let shown = selected ?? week.busiestIndex
        Card(padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)) {
            VStack(spacing: 10) {
                HStack {
                    CardTitle(text: "Daily Pickups")
                    Spacer()
                    Text("Average \(Int(week.averagePerDay.rounded()))")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                }

                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(week.days.enumerated()), id: \.element.id) { index, day in
                        let highlighted = index == shown
                        VStack(spacing: 4) {
                            if highlighted {
                                Text("\(day.count)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())
                            }
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(highlighted ? Theme.accent : Color.white.opacity(day.count == 0 ? 0.12 : 0.34))
                                .frame(width: 30, height: max(6, usable * CGFloat(day.count) / CGFloat(top)))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.15)) { selected = selected == index ? nil : index }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Format.weekday(day.date))
                        .accessibilityValue(day.isFuture ? "Not yet" : "\(day.count) pickups")
                        .accessibilityAddTraits(highlighted ? [.isButton, .isSelected] : .isButton)
                        .accessibilityIdentifier("day.\(index)")
                    }
                }
                .frame(height: plotHeight)
                .sensoryFeedback(.selection, trigger: selected)
                .overlay(alignment: .bottom) {
                    if week.pickups > 0 {
                        AverageLine()
                            .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(height: 1)
                            .offset(y: -usable * CGFloat(week.averagePerDay) / CGFloat(top))
                    }
                }

                HStack(spacing: 0) {
                    ForEach(Array(week.days.enumerated()), id: \.element.id) { index, day in
                        Text(day.letter)
                            .font(.system(size: 12))
                            .foregroundStyle(index == shown ? .white : Theme.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)

                if week.pickups > 0 {
                    Text(selected.map { "\(Format.weekday(week.days[$0].date)). Tap again for the busiest day." }
                         ?? "Tap a day to see its pickups.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily pickups, average \(Int(week.averagePerDay.rounded())) a day")
    }
}

private struct AverageLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private struct WeeklyReasonsCard: View {
    let reasons: [ReasonStat]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                CardTitle(text: "Top Reasons")
                if reasons.isEmpty {
                    Text("Reasons you give this week will show up here.")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(reasons) { stat in
                        ReasonRow(stat: stat, trailing: "\(stat.percent)%", barWidth: 84, trailingWidth: 48)
                            .frame(height: 34)
                    }
                }
            }
        }
    }
}

private struct InsightCard: View {
    let text: String
    let adjust: () -> Void

    var body: some View {
        Card(padding: EdgeInsets(top: 14, leading: 16, bottom: 4, trailing: 16)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 24, height: 24)
                    Text(text)
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("insight")
                }
                Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                Button(action: adjust) {
                    HStack {
                        Text("Adjust Reminders")
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.accent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.tertiary)
                    }
                    .frame(height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("adjustReminders")
            }
        }
    }
}
