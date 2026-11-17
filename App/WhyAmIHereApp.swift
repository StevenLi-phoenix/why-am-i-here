import SwiftUI
import WAIHCore

@main
struct WhyAmIHereApp: App {
    @State private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
