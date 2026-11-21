import Foundation

struct WhaleWidgetSnapshot: Codable, Equatable {
    var nextTitle: String
    var nextDetail: String
    var updatedAt: Date

    static let empty = WhaleWidgetSnapshot(
        nextTitle: "",
        nextDetail: "",
        updatedAt: .distantPast
    )
}

enum WhaleWidgetSnapshotStore {
    static let appGroup = "group.com.whale01.whaleagent"
    private static let key = "widget.snapshot.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func load() -> WhaleWidgetSnapshot {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(WhaleWidgetSnapshot.self, from: data) else {
            return .empty
        }
        return value
    }

    static func save(_ snapshot: WhaleWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
        defaults.synchronize()
    }
}
