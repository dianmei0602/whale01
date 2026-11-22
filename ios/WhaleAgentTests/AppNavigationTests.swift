import XCTest
@testable import WhaleAgent

@MainActor
final class AppNavigationTests: XCTestCase {
    func testWorkspaceReselectPopsToRoot() {
        let navigation = RootNavigationModel(selectedTab: .records)
        navigation.workspacePath = [.todos, .todoDetail("task-1")]

        navigation.reselect(.records)

        XCTAssertTrue(navigation.workspacePath.isEmpty)
        XCTAssertEqual(navigation.selectedTab, .records)
    }

    func testDiscoverReselectPopsToChannelRoot() {
        let navigation = RootNavigationModel(selectedTab: .discover)
        navigation.discoverPath = [
            .news(
                NewsItem(
                    id: "news-1",
                    title: "标题",
                    summary: "摘要",
                    source: "来源",
                    link: "https://example.com",
                    publishedAt: nil,
                    channel: .ai,
                    rank: nil
                )
            )
        ]

        navigation.reselect(.discover)

        XCTAssertTrue(navigation.discoverPath.isEmpty)
    }

    func testHomeReselectReturnsToLandingMode() {
        let navigation = RootNavigationModel(selectedTab: .conversation)
        navigation.conversationMode = .chat

        navigation.reselect(.conversation)

        XCTAssertEqual(navigation.conversationMode, .home)
    }

    func testOpeningWorkspaceRouteSelectsWorkspaceAndPushesRoute() {
        let navigation = RootNavigationModel(selectedTab: .discover)

        navigation.openWorkspace(.todos)

        XCTAssertEqual(navigation.selectedTab, .records)
        XCTAssertEqual(navigation.workspacePath, [.todos])
    }
}
