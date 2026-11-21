import XCTest
@testable import WhaleAgent

@MainActor
final class WorkspaceTests: XCTestCase {
    private func makeStore() -> WhaleWorkspaceStore {
        let suite = "workspace-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return WhaleWorkspaceStore(defaults: defaults, storageKey: "archive")
    }

    func testCaptureFallsBackToBodyAndSupportsKnowledgeSearch() {
        let store = makeStore()
        let item = store.capture(
            title: "",
            body: "周末整理旅行路线和酒店确认单",
            kind: .note,
            isKnowledge: true
        )

        XCTAssertEqual(store.inbox.count, 1)
        XCTAssertEqual(store.knowledge.count, 1)
        XCTAssertFalse(item.title.isEmpty)
        XCTAssertEqual(store.searchKnowledge("酒店").first?.id, item.id)
        XCTAssertTrue(store.searchKnowledge("不存在的关键词").isEmpty)
    }

    func testProjectAssignmentAndFollowUpArePersistedInStore() {
        let store = makeStore()
        let project = store.addProject(name: "春节旅行", summary: "交通、住宿与路线")
        let item = store.capture(
            title: "确认酒店入住时间",
            body: "周五前确认",
            kind: .note
        )
        store.assign(item, to: project?.id)
        _ = store.addFollowUp(
            subject: "确认酒店",
            detail: "检查入住和退房时间",
            dueAt: Date().addingTimeInterval(3_600),
            projectID: project?.id
        )

        XCTAssertEqual(store.captures.first?.projectID, project?.id)
        XCTAssertEqual(store.pendingFollowUps.count, 1)
        XCTAssertEqual(store.captures.first?.isArchived, false)
    }

    func testReviewAndFocusOnlyRecordExplicitActions() {
        let store = makeStore()
        let review = store.review()
        store.saveReview(review, morningFocus: "先完成报告", eveningNote: "报告已完成")
        store.startFocus(.writing)
        store.endFocus()

        XCTAssertEqual(store.review().morningFocus, "先完成报告")
        XCTAssertEqual(store.review().eveningNote, "报告已完成")
        XCTAssertNil(store.activeFocusMode)
        XCTAssertEqual(store.focusSessions.count, 1)
        XCTAssertNotNil(store.focusSessions.first?.endedAt)
    }
}
