import Combine
import Foundation

struct SavedArticle: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let summary: String
    let source: String
    let link: String
    let channel: String
    let savedAt: Date
    var isReadLater: Bool

    init(item: NewsItem, savedAt: Date = Date(), isReadLater: Bool = true) {
        id = item.id
        title = item.displayTitle
        summary = item.displaySummary
        source = item.source
        link = item.link
        channel = item.channel
        self.savedAt = savedAt
        self.isReadLater = isReadLater
    }
}

@MainActor
final class DiscoverReadingLibrary: ObservableObject {
    static let shared = DiscoverReadingLibrary()
    @Published private(set) var saved: [SavedArticle]
    @Published private(set) var mutedTopics: Set<String>

    private let defaults: UserDefaults
    private let savedKey = "whale.discover.saved.v2"
    private let mutedKey = "whale.discover.mutedTopics.v2"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        saved = Self.decode([SavedArticle].self, key: savedKey, defaults: defaults) ?? []
        mutedTopics = Set(defaults.stringArray(forKey: mutedKey) ?? [])
    }

    func isSaved(_ item: NewsItem) -> Bool {
        saved.contains { $0.id == item.id || (!item.link.isEmpty && $0.link == item.link) }
    }

    func toggleSaved(_ item: NewsItem) {
        if isSaved(item) {
            saved.removeAll { $0.id == item.id || (!item.link.isEmpty && $0.link == item.link) }
        } else {
            saved.insert(SavedArticle(item: item), at: 0)
        }
        persist()
    }

    func markRead(_ item: NewsItem) {
        guard let index = saved.firstIndex(where: { $0.id == item.id }) else { return }
        saved[index].isReadLater = false
        persist()
    }

    func mute(topic: String) {
        let cleaned = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        mutedTopics.insert(cleaned)
        defaults.set(Array(mutedTopics).sorted(), forKey: mutedKey)
    }

    func unmute(topic: String) {
        mutedTopics.remove(topic)
        defaults.set(Array(mutedTopics).sorted(), forKey: mutedKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(Array(saved.prefix(80))) {
            defaults.set(data, forKey: savedKey)
        }
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        key: String,
        defaults: UserDefaults
    ) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

struct NewsTopicCluster: Identifiable, Equatable {
    let id: String
    let title: String
    let count: Int
    let itemIDs: [String]
}

enum NewsTopicClusterer {
    private static let stopwords: Set<String> = [
        "公司", "表示", "今日", "今天", "最新", "宣布", "发布", "记者", "中国", "美国", "全球",
        "科技", "新闻", "一个", "这个", "以及", "已经", "可能", "如何", "什么", "为何"
    ]

    static func clusters(_ items: [NewsItem], limit: Int = 6) -> [NewsTopicCluster] {
        var buckets: [String: [NewsItem]] = [:]
        for item in items.prefix(60) {
            for token in tokens(item.displayTitle).prefix(4) {
                buckets[token, default: []].append(item)
            }
        }
        return buckets.compactMap { token, rows -> NewsTopicCluster? in
            let unique = Dictionary(grouping: rows, by: \.id).compactMap { $0.value.first }
            guard unique.count >= 2 else { return nil }
            return NewsTopicCluster(
                id: token,
                title: token,
                count: unique.count,
                itemIDs: unique.prefix(5).map(\.id)
            )
        }
        .sorted {
            $0.count == $1.count ? $0.title.count > $1.title.count : $0.count > $1.count
        }
        .prefix(max(1, limit))
        .map { $0 }
    }

    static func tokens(_ raw: String) -> [String] {
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "_-+"))
            .inverted
        let pieces = raw.components(separatedBy: allowed)
        var values: [String] = []
        for piece in pieces {
            let value = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.count >= 2, !stopwords.contains(value) else { continue }
            if value.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains($0.value) }) {
                if value.count <= 8 {
                    values.append(value)
                } else {
                    let chars = Array(value)
                    for size in [3, 2] where chars.count >= size {
                        for index in 0...(chars.count - size) {
                            let token = String(chars[index..<(index + size)])
                            if !stopwords.contains(token) { values.append(token) }
                            if values.count >= 14 { break }
                        }
                        if values.count >= 14 { break }
                    }
                }
            } else if value.count >= 3 {
                values.append(value)
            }
        }
        return Array(NSOrderedSet(array: values)) as? [String] ?? values
    }
}
