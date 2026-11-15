import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum StockService {
    static let indexes = [
        StockSymbol(quoteID: "1.000001", code: "000001", name: "上证指数"),
        StockSymbol(quoteID: "0.399001", code: "399001", name: "深证成指"),
        StockSymbol(quoteID: "100.HSI", code: "HSI", name: "恒生指数"),
        StockSymbol(quoteID: "100.NDX", code: "NDX", name: "纳斯达克")
    ]

    static func loadQuotes(watchlist: [StockSymbol] = StockWatchlistStore.load()) async throws -> [StockQuote] {
        let symbols = indexes + watchlist
        return try await fetchQuotes(symbols)
    }

    static func fetchQuotes(_ symbols: [StockSymbol]) async throws -> [StockQuote] {
        guard !symbols.isEmpty else { return [] }
        var quotes: [StockQuote] = []
        var failure: Error?

        do {
            quotes = try await fetchEastmoneyQuotes(symbols)
        } catch {
            failure = error
        }

        if quotes.count < symbols.count {
            let found = Set(quotes.map(\.id))
            let missing = symbols.filter { !found.contains($0.id) }
            if let backup = try? await fetchTencentQuotes(missing) {
                quotes.append(contentsOf: backup)
            }
        }

        guard !quotes.isEmpty else {
            throw failure ?? StockDataError.invalidPayload
        }
        let byID = Dictionary(uniqueKeysWithValues: quotes.map { ($0.id, $0) })
        return symbols.compactMap { byID[$0.quoteID] }
    }

    private static func fetchEastmoneyQuotes(_ symbols: [StockSymbol]) async throws -> [StockQuote] {
        var components = URLComponents(string: "https://push2.eastmoney.com/api/qt/ulist.np/get")
        components?.queryItems = [
            URLQueryItem(name: "fltt", value: "2"),
            URLQueryItem(name: "secids", value: symbols.map(\.quoteID).joined(separator: ",")),
            URLQueryItem(name: "fields", value: "f12,f13,f14,f2,f3,f4")
        ]
        guard let url = components?.url else { throw StockDataError.invalidPayload }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Nomi/1.1 iOS", forHTTPHeaderField: "User-Agent")
        request.setValue("https://quote.eastmoney.com/", forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
        return try StockDataParser.parseQuotes(data: data, symbols: symbols)
    }

    static func search(_ term: String) async throws -> [StockSymbol] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let results = try? await searchEastmoney(trimmed), !results.isEmpty {
            return Array(results.prefix(8))
        }
        return Array(try await searchTencent(trimmed).prefix(8))
    }

    private static func searchEastmoney(_ term: String) async throws -> [StockSymbol] {
        var components = URLComponents(string: "https://searchapi.eastmoney.com/api/suggest/get")
        components?.queryItems = [
            URLQueryItem(name: "input", value: term),
            URLQueryItem(name: "type", value: "14"),
            URLQueryItem(name: "count", value: "12")
        ]
        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Nomi/1.1 iOS", forHTTPHeaderField: "User-Agent")
        request.setValue("https://quote.eastmoney.com/", forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
        return try StockDataParser.parseSearch(data: data)
    }

    static func findQuote(matching term: String) async throws -> StockQuote? {
        guard let symbol = try await search(term).first else { return nil }
        return try await fetchQuotes([symbol]).first
    }

    private static func fetchTencentQuotes(_ symbols: [StockSymbol]) async throws -> [StockQuote] {
        let mapped = symbols.compactMap { symbol in
            TencentStockParser.requestCode(for: symbol).map { (symbol, $0) }
        }
        guard !mapped.isEmpty else { return [] }

        let codes = mapped.map { "s_\($0.1)" }.joined(separator: ",")
        guard let url = URL(string: "https://qt.gtimg.cn/q=\(codes)") else {
            throw StockDataError.invalidPayload
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let text = TencentStockParser.decode(data)
        else {
            throw StockDataError.invalidPayload
        }
        return try TencentStockParser.parseQuotes(text: text, symbols: symbols)
    }

    private static func searchTencent(_ term: String) async throws -> [StockSymbol] {
        var components = URLComponents(string: "https://smartbox.gtimg.cn/s3/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: term),
            URLQueryItem(name: "t", value: "all")
        ]
        guard let url = components?.url else { throw StockDataError.invalidPayload }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let text = String(data: data, encoding: .utf8)
        else {
            throw StockDataError.invalidPayload
        }
        return try TencentStockParser.parseSearch(text: text)
    }
}

