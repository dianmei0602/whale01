import XCTest
@testable import WhaleAgent

@MainActor
final class TodoTimelineStoreTests: XCTestCase {
    private func item(
        id: String,
        title: String,
        completed: Bool = false,
        dueAt: Date? = nil
    ) throws -> TodoReminder {
        var object: [String: JSONValue] = [
            "recordId": .string(id),
            "title": .string(title),
            "completed": .bool(completed),
            "listName": .string("提醒事项")
        ]
        if let dueAt {
            object["dueAt"] = .string(ToolDate.iso(dueAt))
        }
        return try XCTUnwrap(TodoReminder(json: .object(object)))
    }

    func testUpsertUpdatesEveryObserverOfTheSameIdentity() throws {
        let store = TodoTimelineStore()
        let original = try item(id: "1", title: "写周报")
        store.replaceLoaded([original])

        let completed = try item(id: "1", title: "写周报", completed: true)
        store.upsert(completed)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(store.items[0].completed)
    }

    func testPendingSortsDatedItemsBeforeUndatedItems() throws {
        let store = TodoTimelineStore()
        let undated = try item(id: "a", title: "整理桌面")
        let dueSoon = try item(
            id: "b",
            title: "取快递",
            dueAt: Date().addingTimeInterval(3_600)
        )

        store.replaceLoaded([undated, dueSoon])

        XCTAssertEqual(store.pending.map(\.id), ["b", "a"])
    }

    func testRemoveDropsOnlyTheRequestedIdentity() throws {
        let store = TodoTimelineStore()
        store.replaceLoaded([
            try item(id: "a", title: "一项"),
            try item(id: "b", title: "二项")
        ])

        store.remove(id: "a")

        XCTAssertEqual(store.items.map(\.id), ["b"])
    }
}
