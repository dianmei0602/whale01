import Foundation

enum IntelligenceService {
    static func load(force: Bool = false) async -> IntelligenceDigest {
        await withTaskGroup(of: (IntelligenceModule, IntelligenceDigest).self) { group in
            for module in IntelligenceModule.allCases {
                group.addTask {
                    (module, await load(module: module, into: .empty(), force: force))
                }
            }
            var result = IntelligenceDigest.empty()
            for await (module, value) in group { result.merge(value, module: module) }
            return result
        }
    }

    static func cached() async -> IntelligenceDigest? {
        await IntelligenceCache.shared.current()
    }

    static func load(
        module: IntelligenceModule,
        into base: IntelligenceDigest,
        force: Bool = false
    ) async -> IntelligenceDigest {
        await IntelligenceCache.shared.load(module: module, seed: base, force: force)
    }

    fileprivate static func fetch(module: IntelligenceModule, base: IntelligenceDigest) async -> IntelligenceDigest {
        var digest = base

        switch module {
        case .news:
            async let internationalNews = NewsService.loadInternational(limit: 12)
            async let currentAffairs = CurrentAffairsService.load()
            let news = await internationalNews
            let affairs = await currentAffairs
            let merged = (news + affairs)
                .reduce(into: [String: NewsArticle]()) { result, article in
                    result[article.link.absoluteString] = article
                }
                .values
                .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }

            if !merged.isEmpty {
                digest.news = Array(merged.prefix(30))
                digest.failures[.news] = nil
            } else {
                digest.failures[.news] = digest.news.isEmpty
                    ? "国际新闻源暂时没有返回内容"
                    : "刷新失败，正在显示上次的新闻。"
            }

        case .ai:
            let news = await NewsService.loadAI(limit: 20)
            let focused = AIModelFocus.filter(news)
            let ai = focused.isEmpty ? news : focused
            if !ai.isEmpty {
                digest.ai = ai
                digest.failures[.ai] = nil
            } else {
                digest.failures[.ai] = digest.ai.isEmpty
                    ? "AI 科技新闻源暂时没有返回内容"
                    : "刷新失败，正在显示上次的 AI 动态。"
            }

        case .market:
            let market = await loadMarket()
            if !market.items.isEmpty {
                digest.market = market.items
                digest.failures[.market] = nil
            } else {
                digest.failures[.market] = digest.market.isEmpty
                    ? market.error
                    : "刷新失败，正在显示上次的行情。"
            }

        case .weibo:
            let trends = await loadTrends()
            if !trends.items.isEmpty {
                digest.trends = trends.items
                digest.failures[.weibo] = nil
            } else {
                digest.failures[.weibo] = digest.trends.isEmpty
                    ? trends.error
                    : "刷新失败，正在显示上次的热搜。"
            }

        case .zhihu:
            let zhihu = await loadZhihu()
            if !zhihu.items.isEmpty {
                digest.zhihu = zhihu.items
                digest.failures[.zhihu] = nil
            } else {
                digest.failures[.zhihu] = digest.zhihu.isEmpty
                    ? zhihu.error
                    : "刷新失败，正在显示上次的热榜。"
            }

        case .game:
            let game = await GameService.load()
            if !game.isEmpty {
                digest.game = game
                digest.failures[.game] = nil
            } else {
                digest.failures[.game] = digest.game.isEmpty
                    ? "游戏动态暂时没有可用数据"
                    : "刷新失败，正在显示上次的游戏内容。"
            }
        }

        if digest.failures[module] == nil, digest.hasContent(module) {
            digest.moduleUpdatedAt[module] = Date()
        }
        return digest
    }

    fileprivate static func fetch() async -> IntelligenceDigest {
        async let newsResult = NewsService.load(limit: 6)
        async let currentAffairsResult = CurrentAffairsService.load()
        async let marketResult = loadMarket()
        async let trendResult = loadTrends()
        async let zhihuResult = loadZhihu()
        async let gameResult = GameService.load()

        let news = await newsResult
        let currentAffairs = await currentAffairsResult
        let market = await marketResult
        let trends = await trendResult
        let zhihu = await zhihuResult
        let game = await gameResult

        var failures: [IntelligenceModule: String] = [:]
        let mergedNews = (news.international + currentAffairs)
            .reduce(into: [String: NewsArticle]()) { result, article in
                result[article.link.absoluteString] = article
            }
            .values
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        if mergedNews.isEmpty {
            failures[.news] = "国际新闻源暂时没有返回内容"
        }
        let focusedAI = AIModelFocus.filter(news.aiTechnology)
        let aiArticles = focusedAI.isEmpty ? news.aiTechnology : focusedAI
        if aiArticles.isEmpty {
            failures[.ai] = "AI 科技新闻源暂时没有返回内容"
        }
        if let error = market.error {
            failures[.market] = error
        }
        if let error = trends.error {
            failures[.weibo] = error
        }
        if let error = zhihu.error {
            failures[.zhihu] = error
        }
        if game.isEmpty {
            failures[.game] = "游戏动态暂时没有可用数据"
        }

        return IntelligenceDigest(
            news: Array(mergedNews.prefix(30)),
            market: market.items,
            trends: trends.items,
            zhihu: zhihu.items,
            game: game,
            ai: aiArticles,
            fetchedAt: Date(),
            failures: failures
        )
    }

    private static func loadMarket() async -> (items: [StockQuote], error: String?) {
        do {
            return (try await StockService.loadQuotes(), nil)
        } catch {
            return ([], "股票行情暂时不可用，请稍后刷新。")
        }
    }

    private static func loadTrends() async -> (items: [TrendingTopic], error: String?) {
        do {
            return (try await WeiboHotSearchService.load(), nil)
        } catch {
            return ([], "微博热搜暂时不可用，其他信息不受影响。")
        }
    }

    private static func loadZhihu() async -> (items: [TrendingTopic], error: String?) {
        do {
            return (try await ZhihuHotService.load(), nil)
        } catch {
            return ([], "知乎热榜暂时不可用，其他信息不受影响。")
        }
    }
}

private actor IntelligenceCache {
    static let shared = IntelligenceCache()

    private var digest = IntelligenceDigest.empty()
    private var inFlight: [IntelligenceModule: Task<IntelligenceDigest, Never>] = [:]
    private var lastAttempt: [IntelligenceModule: Date] = [:]
    private let lifetime: TimeInterval = 120

    func current() -> IntelligenceDigest? {
        digest
    }

    func load(module: IntelligenceModule, seed: IntelligenceDigest, force: Bool) async -> IntelligenceDigest {
        if let task = inFlight[module] { return await task.value }
        if let seedDate = seed.lastSuccess(for: module),
           seedDate > (digest.lastSuccess(for: module) ?? .distantPast) {
            digest.merge(seed, module: module)
        }
        let now = Date()
        if !force, let date = digest.lastSuccess(for: module), now.timeIntervalSince(date) < lifetime {
            return digest
        }
        if !force, let attempt = lastAttempt[module], now.timeIntervalSince(attempt) < 15 {
            return digest
        }
        let base = digest
        let task = Task { await IntelligenceService.fetch(module: module, base: base) }
        inFlight[module] = task
        let fresh = await task.value
        digest.merge(fresh, module: module)
        lastAttempt[module] = Date()
        inFlight[module] = nil
        return digest
    }
}

