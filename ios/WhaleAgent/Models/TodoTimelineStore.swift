import Combine
import Foundation

#if DEBUG
enum TodoDemoMode {
    static var isSyncFixture: Bool {
        ProcessInfo.processInfo.environment["WHALE_DEMO_TODO_SYNC"] == "1"
    }
}
#endif

@MainActor
final class TodoTimelineStore: ObservableObject {
    @Published private(set) var items: [TodoReminder] = []
    @Published private(set) var lastLoadedAt: Date?

    var pending: [TodoReminder] {
        items
            .filter { !$0.completed }
            .sorted {
                ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture)
            }
    }

    var completed: [TodoReminder] {
        items.filter(\.completed)
    }

    func replaceLoaded(_ incoming: [TodoReminder]) {
        var unique: [String: TodoReminder] = [:]
        for item in incoming {
            unique[item.id] = item
        }
        items = unique.values.sorted {
            ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture)
        }
    }

    func upsert(_ item: TodoReminder) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
    }

    func markLoaded() {
        lastLoadedAt = Date()
    }
}
