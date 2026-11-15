import Foundation

enum StockWatchlistStore {
    private static let key = "nomi.stock.watchlist.v1"
    static let limit = 8

    static func load(defaults: UserDefaults = .standard) -> [StockSymbol] {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode([StockSymbol].self, from: data)
        else { return [] }

        var seen = Set<String>()
        return value.filter { seen.insert($0.quoteID).inserted }
    }

    @discardableResult
    static func add(_ symbol: StockSymbol, defaults: UserDefaults = .standard) -> Bool {
        var items = load(defaults: defaults)
        guard items.count < limit,
              !items.contains(where: { $0.quoteID == symbol.quoteID })
        else { return false }
        items.append(symbol)
        save(items, defaults: defaults)
        return true
    }

    static func remove(quoteID: String, defaults: UserDefaults = .standard) {
        let items = load(defaults: defaults).filter { $0.quoteID != quoteID }
        save(items, defaults: defaults)
    }

    private static func save(_ items: [StockSymbol], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }
}

enum MarketQueryParser {
    private static let prefixes = ["帮我看看", "帮我看一下", "查一下", "看看", "请问", "今天", "现在"]
    private static let suffixes = [
        "的股价", "的股票", "股票", "现在多少钱", "现在多少",
        "股价是多少", "股价", "行情怎么样", "行情",
        "涨了吗", "跌了吗", "走势怎么样", "走势", "怎么样"
    ]
    private static let broadTerms = ["大盘", "股市", "A股", "港股", "美股", "市场"]

    static func term(from text: String) -> String? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in prefixes where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
        }
        for suffix in suffixes {
            if let range = value.range(of: suffix) {
                value = String(value[..<range.lowerBound])
            }
        }
        value = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        if broadTerms.contains(where: { value.contains($0) }) { return nil }
        guard value.count >= 2, value.count <= 12 else { return nil }
        return value
    }
}

