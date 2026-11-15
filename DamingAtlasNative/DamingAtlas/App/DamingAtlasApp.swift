import SwiftUI

@main
struct DamingAtlasApp: App {
    private let repository: ContentRepository?
    private let loadError: String?

    init() {
        do {
            repository = try ContentRepository.loadBundled()
            loadError = nil
        } catch {
            repository = nil
            loadError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let repository {
                AppShellView()
                    .environment(repository)
            } else {
                ContentUnavailableView("内容包未载入", systemImage: "exclamationmark.triangle", description: Text(loadError ?? "未知错误"))
            }
        }
    }
}
