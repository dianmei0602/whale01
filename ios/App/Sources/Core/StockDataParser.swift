import Foundation

enum StockDataParser {

    static func parseQuotes(
        data: Data,
        symbols: [StockSymbol],
        fetchedAt: Date = Date()
    ) throws -> [StockQuote] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any],
              let rows = payload["diff"] as? [[String: Any]]
        else {
            throw StockDataError.invalidPayload
        }

        var parsed: [String: StockQuote] = [:]
        for row in rows {
            guard let code = row["f12"] as? String,
                  let market = number(row["f13"]),
                  let name = row["f14"] as? String,
                  let price = number(row["f2"]),
                  let change = number(row["f4"]),
                  let percent = number(row["f3"])
            else { continue }

            let quoteID = "\(Int(market)).\(code)"
            parsed[quoteID] = StockQuote(
                id: quoteID,
                code: code,
                name: name,
                price: price,
                change: change,
                changePercent: percent,
                fetchedAt: fetchedAt
            )
        }

        return symbols.compactMap { parsed[$0.quoteID] }
    }

    static func parseSearch(data: Data) throws -> [StockSymbol] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let table = root["QuotationCodeTable"] as? [String: Any],
              let rows = table["Data"] as? [[String: Any]]
        else {
            throw StockDataError.invalidPayload
        }

        var seen = Set<String>()
        return rows.compactMap { row in
            guard let quoteID = row["QuoteID"] as? String,
                  let code = row["Code"] as? String,
                  let name = row["Name"] as? String,
                  !quoteID.isEmpty,
                  !name.isEmpty,
                  seen.insert(quoteID).inserted
            else { return nil }

            let classify = row["Classify"] as? String ?? ""
            let allowed = classify == "AStock"
                || classify == "HK"
                || classify == "USStock"
            guard allowed else { return nil }
            let excluded = ["购", "沽", "牛", "熊", "轮证", "ETF", "做空", "做多", "二倍", "三倍", "期权"]
            guard !excluded.contains(where: { name.contains($0) }) else { return nil }

            return StockSymbol(quoteID: quoteID, code: code, name: name)
        }
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }
}

enum StockDataError: LocalizedError {
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "行情数据格式暂时无法识别"
        }
    }
}

