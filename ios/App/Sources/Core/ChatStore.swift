import Foundation

/// 一轮对话。只存文字，不存卡片（卡片可以重新查）。
struct ChatTurn: Codable, Equatable {
    let mine: Bool
    let text: String
    let date: Date
}

/// 聊天记录：存本地文件，重开 App 还在。
///
/// 为什么不用 UserDefaults：聊天会越来越长，文件更好控制，
/// 也方便以后做"导出会话"。
enum ChatStore {

    private static let fileName = "nomi-chat.json"
    /// 只保留最近这些轮，免得文件无限长
    private static let keepCount = 60

    private static var fileURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fileName)
    }

    // MARK: - 读

    static func load() -> [ChatTurn] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url)
        else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ChatTurn].self, from: data)) ?? []
    }

    /// 给模型用的上下文：最近 12 轮
    static func recentForModel(limit: Int = 12) -> [ChatTurn] {
        Array(load().suffix(limit))
    }

    // MARK: - 写

    static func append(_ turn: ChatTurn) {
        var turns = load()
        turns.append(turn)
        if turns.count > keepCount {
            turns = Array(turns.suffix(keepCount))
        }
        write(turns)
    }

    /// 删掉第 index 条
    static func remove(at index: Int) {
        var turns = load()
        guard turns.indices.contains(index) else { return }
        turns.remove(at: index)
        write(turns)
    }

    static var count: Int { load().count }

    static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func write(_ turns: [ChatTurn]) {
        guard let url = fileURL else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(turns) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
