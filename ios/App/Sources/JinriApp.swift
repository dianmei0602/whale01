import SwiftUI

@main
@MainActor
struct JinriApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .preferredColorScheme(state.settings.appearance.colorScheme)
        }
    }
}