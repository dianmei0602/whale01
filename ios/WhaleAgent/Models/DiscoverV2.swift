import Combine
import Foundation

enum ReadingStatus: String, Codable, CaseIterable {
    case toRead
    case reading
    case finished

    var title: String {
        switch self {
        case .toRead: return "待读"
        case .reading: return "在读"
        case .finished: return "读完"
        }
    }
}

struct SavedArticle: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let summary: String
    let source: String
    let link: String
    let channel: String
    let savedAt: Date
    var isReadLater: Bool
    var status: ReadingStatus
    var progress: Double
    var excerpt: String?

    init(item: NewsItem, savedAt: Date = Date(), isReadLater: Bool = true) {
        id = item.id
        title = item.displayTitle
        summary = item.displaySummary
        source = item.source
        link = item.link
        channel = item.channel
        self.savedAt = savedAt
        self.isReadLater = isReadLater
        status = isReadLater ? .toRead : .finished
        progress = isReadLater ? 0 : 1
        excerpt = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
        link = try container.decodeIfPresent(String.self, forKey: .link) ?? ""
        channel = try container.decodeIfPresent(String.self, forKey: .channel) ?? ""
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
        isReadLater = try container.decodeIfPresent(Bool.self, forKey: .isReadLater) ?? true
        status = try container.decodeIfPresent(ReadingStatus.self, forKey: .status)
            ?? (isReadLater ? .toRead : .finished)
        progress = min(1, max(0, try container.decodeIfPresent(Double.self, forKey: .progress)
            ?? (isReadLater ? 0 : 1)))
        excerpt = try container.decodeIfPresent(String.self, forKey: .excerpt)
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
        saved[index].status = .finished
        saved[index].progress = 1
        persist()
    }

    func markReading(_ item: NewsItem) {
        guard let index = saved.firstIndex(where: { $0.id == item.id }) else { return }
        if saved[index].status != .finished {
            saved[index].isReadLater = true
            saved[index].status = .reading
            saved[index].progress = max(0.05, saved[index].progress)
        }
        persist()
    }

    func updateProgress(_ item: NewsItem, progress: Double) {
        guard let index = saved.firstIndex(where: { $0.id == item.id }) else { return }
        let value = min(1, max(0, progress))
        saved[index].progress = value
        saved[index].status = value >= 0.98 ? .finished : (value > 0 ? .reading : .toRead)
        saved[index].isReadLater = saved[index].status != .finished
        persist()
    }

    func saveExcerpt(_ item: NewsItem, excerpt: String) {
        guard let index = saved.firstIndex(where: { $0.id == item.id }) else { return }
        saved[index].excerpt = String(excerpt.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2_000))
        persist()
    }

    func articles(with status: ReadingStatus) -> [SavedArticle] {
        saved.filter { $0.status == status }
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
    let sourceCount: Int
    let latestPublishedAt: Date?
    let itemIDs: [String]
}

enum NewsTopicClusterer {
    private static let stopwords: Set<String> = [
        "公司", "表示", "今日", "今天", "最新", "宣布", "发布", "记者", "中国", "美国", "全球",
        "科技", "新闻", "一个", "这个", "以及", "已经", "可能", "如何", "什么", "为何"
    ]

    static func clusters(_ items: [NewsItem], limit: Int = 6) -> [NewsTopicCluster] {
        let dated = items.prefix(100).compactMap { item -> (NewsItem, Date?)? in
            item.id.isEmpty ? nil : (item, item.publishedAt)
        }
        let anchor = dated.compactMap(\.1).max() ?? Date()
        let windowStart = anchor.addingTimeInterval(-36 * 3_600)
        let candidateItems = dated.filter { $0.1 == nil || $0.1! >= windowStart }.map(\.0)
        guard candidateItems.count >= 2 else { return [] }

        let tokenSets = candidateItems.map { Set(tokens($0.displayTitle)) }
        var parents = Array(candidateItems.indices)
        func root(_ value: Int) -> Int {
            var value = value
            while parents[value] != value { value = parents[value] }
            return value
        }
        func union(_ lhs: Int, _ rhs: Int) {
            let a = root(lhs), b = root(rhs)
            if a != b { parents[b] = a }
        }
        for left in candidateItems.indices {
            for right in candidateItems.indices where right > left {
                let shared = tokenSets[left].intersection(tokenSets[right])
                let unionCount = tokenSets[left].union(tokenSets[right]).count
                let similarity = unionCount == 0 ? 0 : Double(shared.count) / Double(unionCount)
                if (shared.count >= 2 && similarity >= 0.30) || similarity >= 0.45 {
                    union(left, right)
                }
            }
        }
        let grouped = Dictionary(grouping: candidateItems.indices, by: root)
        return grouped.values.compactMap { indices -> NewsTopicCluster? in
            let rows = indices.map { candidateItems[$0] }
            let sources = Set(rows.map(\.source).filter { !$0.isEmpty })
            guard rows.count >= 2, sources.count >= 2 else { return nil }
            let tokenFrequency = Dictionary(grouping: rows.flatMap { tokens($0.displayTitle) }, by: \.self)
                .mapValues(\.count)
            let titleToken = tokenFrequency
                .filter { $0.value >= 2 && $0.key.count >= 2 }
                .sorted {
                    if $0.value != $1.value { return $0.value > $1.value }
                    return $0.key.count > $1.key.count
                }
                .first?.key
            let representative = titleToken ?? rows[0].displayTitle
            let latest = rows.compactMap(\.publishedAt).max()
            return NewsTopicCluster(
                id: "cluster-\(rows[0].id)-\(titleToken ?? "topic")",
                title: representative,
                count: sources.count,
                sourceCount: sources.count,
                latestPublishedAt: latest,
                itemIDs: rows.prefix(5).map(\.id)
            )
        }
        .sorted {
            if $0.sourceCount != $1.sourceCount { return $0.sourceCount > $1.sourceCount }
            return ($0.latestPublishedAt ?? .distantPast) > ($1.latestPublishedAt ?? .distantPast)
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
