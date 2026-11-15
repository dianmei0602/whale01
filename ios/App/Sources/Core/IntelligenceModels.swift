import Foundation

enum IntelligenceModule: String, CaseIterable, Identifiable, Hashable {
    case news = "时事"
    case ai = "AI"
    case market = "行情"
    case weibo = "微博"
    case zhihu = "知乎"
    case game = "游戏"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .news: return "globe.asia.australia"
        case .market: return "chart.line.uptrend.xyaxis"
        case .weibo: return "flame"
        case .zhihu: return "questionmark.bubble"
        case .game: return "gamecontroller"
        case .ai: return "cpu"
        }
    }

    var subtitle: String {
        switch self {
        case .news: return "世界正在发生"
        case .market: return "指数与自选"
        case .weibo: return "实时热搜"
        case .zhihu: return "热门讨论"
        case .game: return "新闻与榜单"
        case .ai: return "模型与产品"
        }
    }

    var homepageTitle: String {
        rawValue
    }

    var pageTitle: String {
        switch self {
        case .news: return "今日时事"
        case .ai: return "AI 前沿"
        case .market: return "股票行情"
        case .weibo: return "微博热搜"
        case .zhihu: return "知乎热榜"
        case .game: return "游戏雷达"
        }
    }
}

struct StockSymbol: Codable, Identifiable, Hashable {
    let quoteID: String
    let code: String
    let name: String

    var id: String { quoteID }
}

struct StockQuote: Identifiable, Hashable {
    let id: String
    let code: String
    let name: String
    let price: Double
    let change: Double
    let changePercent: Double
    let fetchedAt: Date

    var isRise: Bool { change > 0 }
    var isFall: Bool { change < 0 }
    var percentText: String { String(format: "%+.2f%%", changePercent) }
}

struct TrendingTopic: Identifiable, Hashable {
    let id: String
    let rank: Int
    let title: String
    let heatText: String
    let label: String
    let link: URL
}

struct IntelligenceDigest {
    var news: [NewsArticle]
    var market: [StockQuote]
    var trends: [TrendingTopic]
    var zhihu: [TrendingTopic]
    var game: GameDigest
    var ai: [NewsArticle]
    let fetchedAt: Date
    var failures: [IntelligenceModule: String]
    var moduleUpdatedAt: [IntelligenceModule: Date] = [:]

    func hasContent(_ module: IntelligenceModule) -> Bool {
        switch module {
        case .news: return !news.isEmpty
        case .ai: return !ai.isEmpty
        case .market: return !market.isEmpty
        case .weibo: return !trends.isEmpty
        case .zhihu: return !zhihu.isEmpty
        case .game: return !game.isEmpty
        }
    }

    func lastSuccess(for module: IntelligenceModule) -> Date? {
        moduleUpdatedAt[module] ?? (hasContent(module) ? fetchedAt : nil)
    }

    /// Merge only the requested module, never another request's old snapshot.
    mutating func merge(_ incoming: IntelligenceDigest, module: IntelligenceModule) {
        switch module {
        case .news: news = incoming.news
        case .ai: ai = incoming.ai
        case .market: market = incoming.market
        case .weibo: trends = incoming.trends
        case .zhihu: zhihu = incoming.zhihu
        case .game: game = incoming.game
        }
        failures[module] = incoming.failures[module]
        moduleUpdatedAt[module] = incoming.lastSuccess(for: module)
    }

    var isEmpty: Bool {
        news.isEmpty && market.isEmpty && trends.isEmpty && zhihu.isEmpty
            && game.isEmpty && ai.isEmpty
    }

    static func empty(failures: [IntelligenceModule: String] = [:]) -> IntelligenceDigest {
        IntelligenceDigest(
            news: [],
            market: [],
            trends: [],
            zhihu: [],
            game: .empty(),
            ai: [],
            fetchedAt: .distantPast,
            failures: failures
        )
    }
}

enum StockDisplay {
    static func priceText(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.2f", value)
        }
        if value >= 100 {
            return String(format: "%.2f", value)
        }
        return String(format: "%.2f", value)
    }

    static func changeText(_ value: Double) -> String {
        String(format: "%+.2f", value)
    }
}

