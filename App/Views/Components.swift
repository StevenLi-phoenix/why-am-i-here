import SwiftUI
import WAIHCore

/// Small date line above a large title, as on Today and Reflection.
struct ScreenHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.secondary)
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Three figures side by side, separated by hairlines.
struct StatTriple: View {
    struct Item: Identifiable {
        let value: String
        let label: String
        var id: String { label }
    }

    let items: [Item]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle().fill(Theme.hairline).frame(width: 1, height: 34)
                }
                VStack(spacing: 1) {
                    Text(item.value)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(item.label)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("stat.\(item.label)")
            }
        }
    }
}

/// The rounded dark panel used for every grouped block.
struct Card<Content: View>: View {
    var padding = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

struct CardTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.secondary)
    }
}

/// Icon, reason, a proportional bar and a trailing figure.
struct ReasonRow: View {
    let stat: ReasonStat
    let trailing: String
    let barWidth: CGFloat
    let trailingWidth: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: stat.reason.symbolName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 24, height: 24)
            Text(stat.reason.summaryTitle)
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Capsule().fill(Color.white.opacity(0.14))
                .frame(width: barWidth, height: 6)
                .overlay(alignment: .leading) {
                    Capsule().fill(Theme.accent)
                        .frame(width: max(6, barWidth * stat.barFraction), height: 6)
                }
            Text(trailing)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: trailingWidth, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.reason.summaryTitle), \(trailing)")
    }
}

/// Circular gauge that starts at 12 o'clock and fills clockwise.
struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    var track: Color = Theme.track

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
        }
        .padding(lineWidth / 2)
    }
}

/// Full-width capsule button used at the bottom of the check-in and reminder screens.
struct PrimaryButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? .white : Theme.tertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(enabled ? Theme.accent : Theme.disabledFill, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.easeOut(duration: 0.15), value: enabled)
    }
}

/// Plain accent-colored text button ("Skip for Now", "Keep Going").
struct QuietButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(Theme.accent)
                .frame(minWidth: 140, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
