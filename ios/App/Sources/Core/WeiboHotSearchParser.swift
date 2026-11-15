import Foundation

enum WeiboHotSearchParser {

    static func parse(data: Data, limit: Int = 20) throws -> [TrendingTopic] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any],
              let rows = payload["realtime"] as? [[String: Any]]
        else {
            throw WeiboHotSearchError.invalidPayload
        }

        var seen = Set<String>()
        var topics: [TrendingTopic] = []

        for row in rows {
            guard let word = (row["word"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !word.isEmpty,
                  seen.insert(word).inserted,
                  let link = searchURL(for: word)
            else { continue }

            let heat = number(row["num"]).map(formatHeat) ?? ""
            let label = (row["label_name"] as? String) ?? ""
            topics.append(
                TrendingTopic(
                    id: word,
                    rank: topics.count + 1,
                    title: word,
                    heatText: heat,
                    label: label,
                    link: link
                )
            )
            if topics.count >= limit { break }
        }

        guard !topics.isEmpty else { throw WeiboHotSearchError.empty }
        return topics
    }

    private static func searchURL(for word: String) -> URL? {
        var components = URLComponents(string: "https://s.weibo.com/weibo")
        components?.queryItems = [URLQueryItem(name: "q", value: word)]
        return components?.url
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }

    private static func formatHeat(_ value: Double) -> String {
        if value >= 10_000 {
            return String(format: "%.1f万", value / 10_000)
        }
        return String(format: "%.0f", value)
    }
}

enum WeiboHotSearchError: LocalizedError {
    case invalidPayload
    case empty

    var errorDescription: String? {
        switch self {
        case .invalidPayload: return "微博热搜格式暂时无法识别"
        case .empty: return "目前没有拿到微博热搜"
        }
    }
}

