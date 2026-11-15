import Foundation
#if canImport(CoreFoundation)
import CoreFoundation
#endif

enum TencentStockParser {
    private static let gb18030: String.Encoding = {
#if canImport(CoreFoundation)
        let encoding = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
        return String.Encoding(rawValue: encoding)
#else
        return String.Encoding(rawValue: 0x80000632)
#endif
    }()

    static func decode(_ data: Data) -> String? {
        String(data: data, encoding: gb18030)
            ?? String(data: data, encoding: .utf8)
    }

    static func requestCode(for symbol: StockSymbol) -> String? {
        switch symbol.quoteID {
        case "1.000001": return "sh000001"
        case "0.399001": return "sz399001"
        case "100.HSI": return "hkHSI"
        case "100.NDX": return "usNDX"
        default:
            let parts = symbol.quoteID.split(separator: ".", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            switch parts[0] {
            case "1": return "sh\(parts[1])"
            case "0": return "sz\(parts[1])"
            case "116": return "hk\(parts[1])"
            case "105", "106", "107": return "us\(parts[1].uppercased())"
            default: return nil
            }
        }
    }

    static func parseQuotes(
        text: String,
        symbols: [StockSymbol],
        fetchedAt: Date = Date()
    ) throws -> [StockQuote] {
        let lookup = Dictionary(
            uniqueKeysWithValues: symbols.compactMap { symbol in
                requestCode(for: symbol).map { ($0.lowercased(), symbol) }
            }
        )
        let pattern = #"v_s_([^=]+)="([^"]*)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var quotes: [String: StockQuote] = [:]

        for match in regex.matches(in: text, range: range) {
            guard let keyRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 2), in: text)
            else { continue }

            let key = String(text[keyRange]).lowercased()
            guard let symbol = lookup[key] else { continue }
            let fields = String(text[valueRange]).components(separatedBy: "~")
            guard fields.count >= 6,
                  let price = Double(fields[3]),
                  let change = Double(fields[4]),
                  let percent = Double(fields[5])
            else { continue }

            let name = fields[1].isEmpty ? symbol.name : fields[1]
            quotes[symbol.quoteID] = StockQuote(
                id: symbol.quoteID,
                code: symbol.code,
                name: name,
                price: price,
                change: change,
                changePercent: percent,
                fetchedAt: fetchedAt
            )
        }

        guard !quotes.isEmpty else { throw StockDataError.invalidPayload }
        return symbols.compactMap { quotes[$0.quoteID] }
    }

    static func parseSearch(text: String) throws -> [StockSymbol] {
        guard let firstQuote = text.firstIndex(of: "\""),
              let lastQuote = text.lastIndex(of: "\""),
              firstQuote < lastQuote
        else {
            throw StockDataError.invalidPayload
        }

        let payload = String(text[text.index(after: firstQuote)..<lastQuote])
        var seen = Set<String>()
        return payload.components(separatedBy: "^").compactMap { item in
            let fields = item.components(separatedBy: "~")
            guard fields.count >= 5,
                  fields[4].hasPrefix("GP")
            else { return nil }

            let market = fields[0].lowercased()
            let code = fields[1]
            let name = decodeUnicode(fields[2])
            let quoteID: String
            switch market {
            case "sh": quoteID = "1.\(code)"
            case "sz": quoteID = "0.\(code)"
            case "hk": quoteID = "116.\(code)"
            case "us":
                let baseCode = code.split(separator: ".").first.map(String.init) ?? code
                quoteID = "106.\(baseCode.uppercased())"
            default: return nil
            }
            guard !name.isEmpty, seen.insert(quoteID).inserted else { return nil }
            return StockSymbol(quoteID: quoteID, code: code, name: name)
        }
    }

    private static func decodeUnicode(_ value: String) -> String {
        let wrapped = "\"\(value)\""
        guard let data = wrapped.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(
                with: data,
                options: .fragmentsAllowed
              ) as? String
        else { return value }
        return decoded
    }
}

