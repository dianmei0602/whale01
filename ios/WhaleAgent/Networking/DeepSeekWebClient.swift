import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// DeepSeek's server-side Search and Fetch APIs. Unlike scraping a search
/// results page, these endpoints return model-readable summaries, source
/// metadata and Markdown page content with the same bearer authentication as
/// the conversation endpoint.
struct DeepSeekWebClient: @unchecked Sendable {
    private let session: URLSession

    private static let searchEndpoint = URL(string: "https://api.deepseek.com/v1/tools/search")!
    private static let fetchEndpoint = URL(string: "https://api.deepseek.com/v1/tools/fetch")!

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 18
        configuration.timeoutIntervalForResource = 25
        session = URLSession(configuration: configuration)
    }

    func search(
        query: String,
        originalQuestion: String? = nil,
        limit: Int = 6,
        includeContent: Bool = true
    ) async throws -> JSONValue {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ToolExecutionError(code: "empty_query", message: "搜索关键词不能为空")
        }
        let request = SearchRequest(
            query: String(trimmed.prefix(128)),
            count: min(max(limit, 1), 10),
            ori_question: originalQuestion.map { String($0.prefix(128)) },
            need_content: includeContent
        )
        let data = try await post(Self.searchEndpoint, body: request)
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        guard !decoded.results.isEmpty else {
            throw ToolExecutionError(
                code: "empty_search",
                message: "DeepSeek 搜索没有找到结果"
            )
        }
        return .object([
            "query": .string(trimmed),
            "results": .array(decoded.results.enumerated().map { index, item in
                searchResultJSON(item, rank: index + 1, includeContent: includeContent)
            }),
            "count": .number(Double(decoded.results.count)),
            "source": .string("deepseek_search"),
            "fetchedAt": .string(ToolDate.iso(Date())),
            "note": .string("summary 和 content 来自 DeepSeek 搜索服务，可用于综合回答；对精确数字、价格或时效性强的结论，优先再读取对应原文并核对发布日期。")
        ])
    }

    func research(
        queries rawQueries: [String],
        originalQuestion: String,
        limit: Int = 6
    ) async throws -> JSONValue {
        guard LocalAgentConfig.isConfigured else { throw LocalAgentError.missingKey }
        var seenQueries = Set<String>()
        let queries = rawQueries.compactMap { raw -> String? in
            let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty, seenQueries.insert(query.lowercased()).inserted else { return nil }
            return String(query.prefix(128))
        }.prefix(3)
        guard !queries.isEmpty else {
            throw ToolExecutionError(code: "empty_query", message: "至少需要一个搜索角度")
        }

        let client = self
        let payloads = try await withThrowingTaskGroup(of: (Int, JSONValue).self) { group in
            for (index, query) in queries.enumerated() {
                group.addTask {
                    let payload = try await client.search(
                        query: query,
                        originalQuestion: originalQuestion,
                        limit: 5,
                        includeContent: true
                    )
                    return (index, payload)
                }
            }
            var values: [(Int, JSONValue)] = []
            for try await value in group { values.append(value) }
            return values.sorted { $0.0 < $1.0 }
        }

        var seenURLs = Set<String>()
        var merged: [([String: JSONValue], Double)] = []
        for (queryIndex, payload) in payloads {
            guard let object = payload.objectValue,
                  let rows = object["results"]?.arrayValue else { continue }
            let matchedQuery = queryIndex < queries.count ? queries[queryIndex] : ""
            for row in rows {
                guard var item = row.objectValue,
                      let rawURL = item.optionalString("url") else { continue }
                let key = Self.canonicalURL(rawURL)
                guard seenURLs.insert(key).inserted else { continue }
                item["matchedQuery"] = .string(matchedQuery)
                if let summary = item["summary"]?.stringValue {
                    item["summary"] = .string(String(summary.prefix(700)))
                }
                if let content = item["content"]?.stringValue {
                    item["content"] = .string(String(content.prefix(1200)))
                    item["contentTruncated"] = .bool(content.count > 1200)
                }
                let relevance = item["relevance"]?.doubleValue ?? 0
                let authority = item["authority"]?.doubleValue ?? 0
                merged.append((item, relevance + authority / 10))
            }
        }
        guard !merged.isEmpty else {
            throw ToolExecutionError(code: "empty_search", message: "DeepSeek 多角度搜索没有找到结果")
        }
        let ranked = merged.sorted { $0.1 > $1.1 }.prefix(min(max(limit, 3), 8))
        return .object([
            "originalQuestion": .string(originalQuestion),
            "queries": .array(queries.map(JSONValue.string)),
            "results": .array(ranked.map { .object($0.0) }),
            "count": .number(Double(ranked.count)),
            "source": .string("deepseek_multi_search"),
            "fetchedAt": .string(ToolDate.iso(Date())),
            "note": .string("这些结果来自多个互补搜索角度，已按 URL 去重并按相关度与来源权威度排序。优先对照不同来源的发布日期和差异；精确数字或强时效结论再读取原文。")
        ])
    }

    func fetch(urlString: String, maxChars: Int = 6000) async throws -> JSONValue {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            throw ToolExecutionError(code: "invalid_url", message: "只支持 http/https 链接")
        }
        let data = try await post(Self.fetchEndpoint, body: FetchRequest(url: trimmed))
        let decoded = try JSONDecoder().decode(FetchResponse.self, from: data)
        let limit = max(1000, min(maxChars, 12000))
        let content = decoded.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw ToolExecutionError(code: "empty_content", message: "网页没有可提取的正文")
        }
        let text = String(content.prefix(limit))
        return .object([
            "url": .string(trimmed),
            "finalURL": .string(trimmed),
            "title": .string(decoded.title.isEmpty ? "未命名网页" : decoded.title),
            "text": .string(text),
            "charCount": .number(Double(text.count)),
            "truncated": .bool(content.count > text.count),
            "source": .string("deepseek_fetch"),
            "fetchedAt": .string(ToolDate.iso(Date()))
        ])
    }

    private func searchResultJSON(
        _ item: SearchResult,
        rank: Int,
        includeContent: Bool
    ) -> JSONValue {
        var object: [String: JSONValue] = [
            "rank": .number(Double(rank)),
            "title": .string(item.title),
            "url": .string(item.url),
            "snippet": .string(String(item.snippet.prefix(600))),
            "summary": .string(String(item.summary.prefix(1400)))
        ]
        if let siteName = item.site_name, !siteName.isEmpty {
            object["siteName"] = .string(siteName)
        }
        if let date = item.date, !date.isEmpty {
            object["publishedAt"] = .string(date)
        }
        if let score = item.rerank_score {
            object["relevance"] = .number(score)
        }
        if let authority = item.authority {
            object["authority"] = .number(Double(authority))
        }
        if includeContent {
            let content = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                object["content"] = .string(String(content.prefix(2400)))
                object["contentTruncated"] = .bool(content.count > 2400)
            }
        }
        return .object(object)
    }

    private func post<Body: Encodable>(_ url: URL, body: Body) async throws -> Data {
        guard LocalAgentConfig.isConfigured else { throw LocalAgentError.missingKey }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 18
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(LocalAgentConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        var lastError: Error?
        for attempt in 0..<2 {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw ToolExecutionError(code: "invalid_response", message: "搜索服务返回了无法识别的响应")
                }
                guard (200..<300).contains(http.statusCode) else {
                    let serverMessage = Self.errorMessage(from: data)
                    let detail = serverMessage ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                    let error = ToolExecutionError(
                        code: "deepseek_web_http_\(http.statusCode)",
                        message: "DeepSeek 网页服务 HTTP \(http.statusCode)：\(detail)"
                    )
                    if [408, 429, 500, 502, 503, 504].contains(http.statusCode), attempt == 0 {
                        lastError = error
                        try await Task.sleep(nanoseconds: 500_000_000)
                        continue
                    }
                    throw error
                }
                return data
            }
        }
        throw lastError ?? ToolExecutionError(code: "deepseek_web_failed", message: "DeepSeek 网页服务请求失败")
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) else { return nil }
        return String(envelope.error.message.prefix(240))
    }

    private static func canonicalURL(_ raw: String) -> String {
        guard var components = URLComponents(string: raw) else { return raw }
        components.fragment = nil
        let trackingKeys: Set<String> = [
            "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
            "spm", "from", "ref", "ref_src"
        ]
        if let items = components.queryItems {
            let retained = items.filter { !trackingKeys.contains($0.name.lowercased()) }
            components.queryItems = retained.isEmpty ? nil : retained
        }
        if components.path.count > 1, components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        return components.string ?? raw
    }

    private struct SearchRequest: Encodable {
        let query: String
        let count: Int
        let ori_question: String?
        let need_content: Bool
    }

    private struct FetchRequest: Encodable {
        let url: String
    }

    private struct SearchResponse: Decodable {
        let results: [SearchResult]
    }

    private struct SearchResult: Decodable {
        let rerank_score: Double?
        let title: String
        let url: String
        let snippet: String
        let summary: String
        let content: String
        let site_name: String?
        let date: String?
        let authority: Int?
    }

    private struct FetchResponse: Decodable {
        let title: String
        let content: String
    }

    private struct ErrorEnvelope: Decodable {
        struct APIError: Decodable {
            let message: String
        }
        let error: APIError
    }
}
