import SwiftUI
import WAIHCore

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            Tab("Today", systemImage: "house.fill", value: AppTab.today) {
                TodayView()
            }
            Tab("Reflection", systemImage: "chart.bar.fill", value: AppTab.reflection) {
                ReflectionView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(Theme.accent)
        .fullScreenCover(item: $model.overlay) { overlay in
            Group {
                switch overlay {
                case .checkIn(let context):
                    IntentCheckView(context: context)
                case .reminder(let context):
                    GentleReminderView(context: context)
                }
            }
            .environment(model)
            .preferredColorScheme(.dark)
        }
        .overlay(alignment: .top) {
            if let notice = model.notice {
                NoticeBanner(text: notice)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: model.notice)
        .onOpenURL { model.handle(url: $0) }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { model.becameActive() }
        }
        .preferredColorScheme(.dark)
    }
}

private struct NoticeBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.12)))
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .accessibilityIdentifier("notice")
    }
}
