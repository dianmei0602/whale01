import Foundation

struct StockFundFlowPoint: Identifiable, Hashable {
    let date: String
    let mainNet: Double
    let smallNet: Double
    let mediumNet: Double
    let largeNet: Double
    let superLargeNet: Double

    var id: String { date }
}

struct StockProfileSnapshot: Hashable {
    let totalMarketCap: Double
    let floatMarketCap: Double
    let pe: Double
    let pb: Double
    let totalShares: Double
    let floatShares: Double
}

struct StockSectorSnapshot: Identifiable, Hashable {
    let code: String
    let name: String
    let changePercent: Double
    let mainNetInflow: Double
    let mainNetRatio: Double

    var id: String { code }
}

struct StockFinanceSnapshot: Hashable {
    let reportName: String
    let revenue: Double
    let parentNetProfit: Double
    let roe: Double
    let grossMargin: Double
    let netMargin: Double
}

struct StockCapitalSnapshot: Hashable {
    let totalShares: Double
    let unlimitedShares: Double
    let limitedShares: Double
}

struct StockShareholder: Identifiable, Hashable {
    let rank: Int
    let name: String
    let ratio: Double
    let shares: Double
    let change: String

    var id: Int { rank }
}

struct StockDetailSnapshot {
    let quote: StockQuote
    var profile: StockProfileSnapshot?
    var fundFlow: [StockFundFlowPoint] = []
    var sectors: [StockSectorSnapshot] = []
    var finance: StockFinanceSnapshot?
    var capital: StockCapitalSnapshot?
    var shareholders: [StockShareholder] = []
    var failures: [String: String] = [:]
    var fetchedAt: Date = Date()
}

enum StockNumber {
    static func compact(_ value: Double) -> String {
        let absolute = abs(value)
        if absolute >= 100_000_000 {
            return String(format: "%+.2f亿", value / 100_000_000)
        }
        if absolute >= 10_000 {
            return String(format: "%+.2f万", value / 10_000)
        }
        return String(format: "%+.2f", value)
    }

    static func whole(_ value: Double) -> String {
        let absolute = abs(value)
        if absolute >= 100_000_000 {
            return String(format: "%.2f亿", value / 100_000_000)
        }
        if absolute >= 10_000 {
            return String(format: "%.2f万", value / 10_000)
        }
        return String(format: "%.0f", value)
    }
}

