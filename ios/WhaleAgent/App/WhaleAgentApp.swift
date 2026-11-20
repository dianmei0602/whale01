import SwiftUI
import UIKit

@main
@MainActor
struct WhaleAgentApp: App {
    init() {
        WhaleSystemChrome.apply(WhalePaletteStyle.current)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
