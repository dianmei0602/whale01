import Combine
import Foundation

enum WorkspaceRoute: Hashable {
    case todos
    case todoDetail(String)
}

@MainActor
final class RootNavigationModel: ObservableObject {
    @Published var selectedTab: AppTab
    @Published var conversationMode: ConversationEntryMode
    @Published var discoverPath: [DiscoverRoute]
    @Published var workspacePath: [WorkspaceRoute]

    init(
        selectedTab: AppTab = .conversation,
        conversationMode: ConversationEntryMode = .home,
        discoverPath: [DiscoverRoute] = [],
        workspacePath: [WorkspaceRoute] = []
    ) {
        self.selectedTab = selectedTab
        self.conversationMode = conversationMode
        self.discoverPath = discoverPath
        self.workspacePath = workspacePath
    }

    func select(_ tab: AppTab) {
        selectedTab = tab
    }

    func reselect(_ tab: AppTab) {
        selectedTab = tab
        switch tab {
        case .conversation:
            conversationMode = .home
        case .discover:
            discoverPath = []
        case .records:
            workspacePath = []
        case .settings:
            selectedTab = .conversation
            conversationMode = .home
        }
    }

    func openWorkspace(_ route: WorkspaceRoute? = nil) {
        selectedTab = .records
        workspacePath = route.map { [$0] } ?? []
    }
}
