import Foundation

/// Injectable boundary for market I/O. UI generations and watchlist snapshots
/// can be verified without a live quotation provider or model credentials.
protocol MarketDataProvider: AnyObject {
    func indexes(force: Bool) async throws -> MarketQuoteResponse
    func quotes(symbols: [String], force: Bool) async throws -> MarketQuoteResponse
    func search(_ query: String) async throws -> MarketSearchResponse
    func todayFundFlows(symbols: [String]) async -> [String: FundFlowPoint]
    func sectorBoard(force: Bool) async throws -> SectorBoardResponse
    func marketNews(limit: Int, force: Bool) async throws -> MarketNewsResponse
}

extension MarketDataProvider {
    func sectorBoard(force: Bool) async throws -> SectorBoardResponse {
        SectorBoardResponse(updatedAt: ToolDate.iso(Date()), source: "未配置板块源", topGainers: [], topInflows: [])
    }

    func marketNews(limit: Int, force: Bool) async throws -> MarketNewsResponse {
        MarketNewsResponse(updatedAt: ToolDate.iso(Date()), source: "未配置新闻源", items: [])
    }
}

extension DiscoverClient: MarketDataProvider {}
