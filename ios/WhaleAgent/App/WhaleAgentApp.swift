import SwiftUI
import UIKit

@main
@MainActor
struct WhaleAgentApp: App {
    init() {
        // 首次启动即按持久化样式设置 TabBar；样式切换由 ThemeManager.didSet 负责刷新。
        ThemeManager.shared.applyTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
