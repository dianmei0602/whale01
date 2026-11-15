import Foundation

enum ZhihuHotParser {
    static func parse(data: Data, limit: Int = 20) throws -> [TrendingTopic] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["data"] as? [[String: Any]]
        else {
            throw ZhihuHotError.invalidPayload
        }

        var seen = Set<String>()
        var topics: [TrendingTopic] = []
        for row in rows {
            guard let target = row["target"] as? [String: Any],
                  let title = (target["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty,
                  seen.insert(title).inserted
            else { continue }

            let rawURL = target["url"] as? String ?? ""
            let link = webURL(from: rawURL) ?? URL(string: "https://www.zhihu.com/hot")!
            let heat = row["detail_text"] as? String ?? ""
            let label = (row["card_label"] as? [String: Any])?["type"] as? String ?? ""
            topics.append(
                TrendingTopic(
                    id: "zhihu-\(topics.count + 1)",
                    rank: topics.count + 1,
                    title: title,
                    heatText: heat,
                    label: label == "hot" ? "热" : label,
                    link: link
                )
            )
            if topics.count >= limit { break }
        }
        guard !topics.isEmpty else { throw ZhihuHotError.empty }
        return topics
    }

    private static func webURL(from apiURL: String) -> URL? {
        guard let id = apiURL.split(separator: "/").last,
              !id.isEmpty
        else { return nil }
        return URL(string: "https://www.zhihu.com/question/\(id)")
    }
}

enum ZhihuHotError: LocalizedError {
    case invalidPayload
    case empty

    var errorDescription: String? {
        switch self {
        case .invalidPayload: return "知乎热榜格式暂时无法识别"
        case .empty: return "目前没有拿到知乎热榜"
        }
    }
}

