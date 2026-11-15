import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum WeiboHotSearchService {
    static func load() async throws -> [TrendingTopic] {
        let url = URL(string: "https://weibo.com/ajax/side/hotSearch")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://weibo.com/", forHTTPHeaderField: "Referer")
        request.setValue("application/json,text/plain,*/*", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
        return try WeiboHotSearchParser.parse(data: data, limit: 20)
    }
}

