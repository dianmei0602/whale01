import Foundation

struct AgentMemoryRecord: Codable, Identifiable, Sendable {
    let id: String
    let conversationId: String
    let request: String
    let reply: String
    let keywords: [String]
    let updatedAt: Date
}

/// Local episodic memory. It stores compact user/assistant turn summaries and
/// retrieves them by lexical relevance. No web page, system prompt or secret is
/// stored here.
final class AgentMemoryStore: @unchecked Sendable {
    static let shared = AgentMemoryStore()

    private let lock = NSLock()
    private let fileURL: URL
    private var records: [AgentMemoryRecord] = []
    private let capacity = 120

    init(fileURL suppliedURL: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        fileURL = suppliedURL ?? documents.appendingPathComponent("agent-memory-v1.json")
        load()
    }

    func record(userText: String, reply: String, conversationId: String) {
        let request = String(userText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(700))
        let answer = String(reply.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
        guard request.count >= 4, !answer.isEmpty else { return }
        let record = AgentMemoryRecord(
            id: UUID().uuidString.lowercased(),
            conversationId: conversationId,
            request: request,
            reply: answer,
            keywords: Self.tokens(request + "\n" + answer).map(\.key).sorted(),
            updatedAt: Date()
        )

        lock.lock()
        defer { lock.unlock() }
        if let index = records.firstIndex(where: {
            $0.conversationId == conversationId && $0.request == request
        }) {
            records[index] = record
        } else {
            records.insert(record, at: 0)
        }
        if records.count > capacity { records.removeLast(records.count - capacity) }
        persistLocked()
    }

    func snapshotText(matching request: String) -> String {
        let query = Self.tokens(request)
        guard !query.isEmpty else { return "本轮没有检索到相关历史记录。" }

        lock.lock()
        let values = records
        lock.unlock()

        let now = Date()
        let ranked = values.compactMap { record -> (AgentMemoryRecord, Double)? in
            let ageDays = max(0, now.timeIntervalSince(record.updatedAt) / 86_400)
            guard ageDays <= 180 else { return nil }
            let recordFeatures = Self.tokens(record.request + "\n" + record.reply)
            let score = Self.similarity(query, recordFeatures) + max(0, 0.12 - ageDays / 1800)
            return score > 0.05 ? (record, score) : nil
        }.sorted { $0.1 > $1.1 }.prefix(4)

        guard !ranked.isEmpty else { return "本轮没有检索到相关历史记录。" }
        return ranked.map {
            let date = ToolDate.day($0.0.updatedAt, timezone: TimeZone.current.identifier)
            return "- \(date)｜用户曾说：\($0.0.request)\n  当时答复：\(String($0.0.reply.prefix(260)))"
        }.joined(separator: "\n")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([AgentMemoryRecord].self, from: data) else {
            return
        }
        records = Array(decoded.prefix(capacity)).sorted { $0.updatedAt > $1.updatedAt }
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    private static func similarity(_ lhs: [String: Double], _ rhs: [String: Double]) -> Double {
        let lhsNorm = sqrt(lhs.values.reduce(0) { $0 + $1 * $1 })
        let rhsNorm = sqrt(rhs.values.reduce(0) { $0 + $1 * $1 })
        guard lhsNorm > 0, rhsNorm > 0 else { return 0 }
        let dot = lhs.reduce(0.0) { partial, item in
            partial + item.value * (rhs[item.key] ?? 0)
        }
        return dot / (lhsNorm * rhsNorm)
    }

    private static func tokens(_ raw: String) -> [String: Double] {
        let normalized = raw.lowercased()
        let words = normalized.components(
            separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-")).inverted
        ).filter { $0.count >= 2 }
        let chinese = normalized.filter { character in
            character.unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) }
        }
        var result: [String: Double] = [:]
        for word in words where word.unicodeScalars.contains(where: { (0x0041...0x007A).contains($0.value) }) {
            result[word, default: 0] += 1
        }
        let chars = Array(chinese)
        if !chars.isEmpty {
            for index in chars.indices {
                result[String(chars[index]), default: 0] += 0.25
                if index + 1 < chars.count {
                    result[String(chars[index...index + 1]), default: 0] += 1
                }
            }
        }
        let stopwords: Set<String> = [
            "这个", "那个", "什么", "怎么", "可以", "帮我", "一个", "现在", "然后",
            "就是", "还是", "已经", "需要", "用户", "回答"
        ]
        return result.filter { !stopwords.contains($0.key) }
    }
}
