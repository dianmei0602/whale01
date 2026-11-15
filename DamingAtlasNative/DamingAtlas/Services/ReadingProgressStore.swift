import Foundation
import Observation

struct StoredRoute: Codable, Hashable, Identifiable {
    var id: String { "\(kind):\(routeID)" }
    let kind: String
    let routeID: String
    let title: String
    let updatedAt: Date

    init(route: AppRoute, title: String) {
        self.title = title
        updatedAt = .now
        switch route {
        case .person(let id): kind = "person"; routeID = id
        case .event(let id): kind = "event"; routeID = id
        case .chapter(let id): kind = "chapter"; routeID = String(id)
        case .memorial(let id): kind = "memorial"; routeID = id
        case .work(let id): kind = "work"; routeID = id
        case .source(let id): kind = "source"; routeID = id
        }
    }

    var route: AppRoute? {
        switch kind {
        case "person": .person(routeID)
        case "event": .event(routeID)
        case "chapter": Int(routeID).map(AppRoute.chapter)
        case "memorial": .memorial(routeID)
        case "work": .work(routeID)
        case "source": .source(routeID)
        default: nil
        }
    }
}

@MainActor
@Observable
final class ReadingProgressStore {
    private let lastKey = "dam.lastRead.v1"
    private let bookmarksKey = "dam.bookmarks.v1"
    private let defaults: UserDefaults
    var lastRead: StoredRoute?
    var bookmarks: [StoredRoute]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lastRead = Self.decode(StoredRoute.self, key: lastKey, defaults: defaults)
        bookmarks = Self.decode([StoredRoute].self, key: bookmarksKey, defaults: defaults) ?? []
    }

    func record(route: AppRoute, title: String) {
        lastRead = StoredRoute(route: route, title: title)
        encode(lastRead, key: lastKey)
    }

    func toggleBookmark(route: AppRoute, title: String) {
        let item = StoredRoute(route: route, title: title)
        if let index = bookmarks.firstIndex(where: { $0.id == item.id }) {
            bookmarks.remove(at: index)
        } else {
            bookmarks.insert(item, at: 0)
        }
        encode(bookmarks, key: bookmarksKey)
    }

    func isBookmarked(_ route: AppRoute) -> Bool {
        bookmarks.contains { $0.route == route }
    }

    private func encode<T: Encodable>(_ value: T?, key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
