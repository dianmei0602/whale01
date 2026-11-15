import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum StockDetailService {
    static func load(_ quote: StockQuote) async -> StockDetailSnapshot {
        async let fundFlow = loadFundFlow(quote.id)
        async let sectors = loadSectors()
        async let profile = loadProfile(quote.id)

        var snapshot = StockDetailSnapshot(quote: quote)
        let flow = await fundFlow
        let sector = await sectors
        let profileResult = await profile
        snapshot.profile = profileResult.item
        snapshot.fundFlow = flow.items
        snapshot.sectors = sector.items
        if let error = profileResult.error { snapshot.failures["概览"] = error }
        if let error = flow.error { snapshot.failures["资金"] = error }
        if let error = sector.error { snapshot.failures["板块"] = error }

        if let code = f10Code(quote) {
            async let finance = loadFinance(code)
            async let capital = loadCapital(code)
            async let holders = loadShareholders(code)
            let financeResult = await finance
            let capitalResult = await capital
            let holderResult = await holders
            snapshot.finance = financeResult.item
            snapshot.capital = capitalResult.item
            snapshot.shareholders = holderResult.items
            if let error = financeResult.error { snapshot.failures["财报"] = error }
            if let error = capitalResult.error { snapshot.failures["股权"] = error }
            if let error = holderResult.error { snapshot.failures["股东"] = error }
        } else {
            snapshot.failures["财报"] = "当前仅支持 A 股财报与 F10 数据"
            snapshot.failures["股权"] = "当前仅支持 A 股财报与 F10 数据"
        }

        snapshot.fetchedAt = Date()
        return snapshot
    }

    private static func f10Code(_ quote: StockQuote) -> String? {
        let parts = quote.id.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "1": return "SH\(parts[1])"
        case "0": return "SZ\(parts[1])"
        default: return nil
        }
    }

    private static func loadFundFlow(_ secid: String) async -> (items: [StockFundFlowPoint], error: String?) {
        var components = URLComponents(string: "https://push2.eastmoney.com/api/qt/stock/fflow/kline/get")
        components?.queryItems = [
            URLQueryItem(name: "lmt", value: "5"),
            URLQueryItem(name: "klt", value: "101"),
            URLQueryItem(name: "secid", value: secid),
            URLQueryItem(name: "fields1", value: "f1,f2,f3,f7"),
            URLQueryItem(name: "fields2", value: "f51,f52,f53,f54,f55,f56")
        ]
        do {
            let data = try await fetch(components?.url, referer: "https://quote.eastmoney.com/")
            return (try StockDetailParser.parseFundFlow(data: data), nil)
        } catch {
            return ([], "资金流向暂时没有拿到")
        }
    }

    private static func loadProfile(_ secid: String) async -> (item: StockProfileSnapshot?, error: String?) {
        var components = URLComponents(string: "https://push2.eastmoney.com/api/qt/stock/get")
        components?.queryItems = [
            URLQueryItem(name: "fltt", value: "2"),
            URLQueryItem(name: "secid", value: secid),
            URLQueryItem(name: "fields", value: "f57,f58,f84,f85,f116,f117,f162,f167")
        ]
        do {
            let data = try await fetch(components?.url, referer: "https://quote.eastmoney.com/")
            return (try StockDetailParser.parseProfile(data: data), nil)
        } catch {
            return (nil, "个股概览暂时没有拿到")
        }
    }

    private static func loadSectors() async -> (items: [StockSectorSnapshot], error: String?) {
        var components = URLComponents(string: "https://push2.eastmoney.com/api/qt/clist/get")
        components?.queryItems = [
            URLQueryItem(name: "pn", value: "1"),
            URLQueryItem(name: "pz", value: "8"),
            URLQueryItem(name: "po", value: "1"),
            URLQueryItem(name: "np", value: "1"),
            URLQueryItem(name: "fltt", value: "2"),
            URLQueryItem(name: "invt", value: "2"),
            URLQueryItem(name: "fid", value: "f3"),
            URLQueryItem(name: "fs", value: "m:90+t:2"),
            URLQueryItem(name: "fields", value: "f12,f14,f2,f3,f62,f184")
        ]
        do {
            let data = try await fetch(components?.url, referer: "https://quote.eastmoney.com/")
            return (try StockDetailParser.parseSectors(data: data), nil)
        } catch {
            return ([], "板块数据暂时没有拿到")
        }
    }

    private static func loadFinance(_ code: String) async -> (item: StockFinanceSnapshot?, error: String?) {
        var components = URLComponents(string: "https://emweb.securities.eastmoney.com/PC_HSF10/NewFinanceAnalysis/ZYZBAjaxNew")
        components?.queryItems = [
            URLQueryItem(name: "type", value: "0"),
            URLQueryItem(name: "code", value: code)
        ]
        do {
            let data = try await fetch(components?.url, referer: "https://emweb.securities.eastmoney.com/")
            return (try StockDetailParser.parseFinance(data: data), nil)
        } catch {
            return (nil, "财报数据暂时没有拿到")
        }
    }

    private static func loadCapital(_ code: String) async -> (item: StockCapitalSnapshot?, error: String?) {
        var components = URLComponents(string: "https://emweb.securities.eastmoney.com/PC_HSF10/CapitalStockStructure/PageAjax")
        components?.queryItems = [URLQueryItem(name: "code", value: code)]
        do {
            let data = try await fetch(components?.url, referer: "https://emweb.securities.eastmoney.com/")
            return (try StockDetailParser.parseCapital(data: data), nil)
        } catch {
            return (nil, "股权结构暂时没有拿到")
        }
    }

    private static func loadShareholders(_ code: String) async -> (items: [StockShareholder], error: String?) {
        var components = URLComponents(string: "https://emweb.securities.eastmoney.com/PC_HSF10/ShareholderResearch/PageAjax")
        components?.queryItems = [URLQueryItem(name: "code", value: code)]
        do {
            let data = try await fetch(components?.url, referer: "https://emweb.securities.eastmoney.com/")
            return (try StockDetailParser.parseShareholders(data: data), nil)
        } catch {
            return ([], "股东数据暂时没有拿到")
        }
    }

    private static func fetch(_ url: URL?, referer: String) async throws -> Data {
        guard let url else { throw StockDataError.invalidPayload }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Nomi/1.2 iOS", forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else {
            throw StockDataError.invalidPayload
        }
        return data
    }
}

