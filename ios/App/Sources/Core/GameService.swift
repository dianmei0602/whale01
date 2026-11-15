import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FoundationXML)
import FoundationXML
#endif

enum GameService {
    static func load() async -> GameDigest {
        async let news = loadNews()
        async let steam = loadSteam()
        async let free = loadAppStore(
            url: "https://itunes.apple.com/cn/rss/topfreeapplications/limit=100/genre=6014/json",
            source: "App Store 免费榜",
            idPrefix: "ios-free"
        )
        async let grossing = loadAppStore(
            url: "https://itunes.apple.com/cn/rss/topgrossingapplications/limit=100/genre=6014/json",
            source: "App Store 畅销榜",
            idPrefix: "ios-grossing"
        )

        let newsResult = await news
        let steamResult = await steam
        let freeResult = await free
        let grossingResult = await grossing
        var failures: [GameSection: String] = [:]
        if let error = newsResult.error { failures[.news] = error }
        if let error = steamResult.error { failures[.steam] = error; failures[.coming] = error }
        if let error = freeResult.error { failures[.free] = error }
        if let error = grossingResult.error { failures[.grossing] = error }

        return GameDigest(
            news: newsResult.items,
            steamTop: steamResult.top,
            steamComing: steamResult.coming,
            iosFree: freeResult.items,
            iosGrossing: grossingResult.items,
            failures: failures,
            fetchedAt: Date()
        )
    }

    private static func loadNews() async -> (items: [NewsArticle], error: String?) {
        guard let url = URL(string: "https://www.yystv.cn/rss/feed") else {
            return ([], "游戏新闻源不可用")
        }
        do {
            let data = try await fetch(url, referer: nil, timeout: 12)
            let parser = GameNewsParser()
            let xml = XMLParser(data: data)
            xml.delegate = parser
            guard xml.parse() else { throw GameDataError.invalidPayload }
            return (Array(parser.articles.prefix(12)), nil)
        } catch {
            return ([], "游戏新闻暂时不可用")
        }
    }

    private static func loadSteam() async -> (top: [GameRankItem], coming: [GameRankItem], error: String?) {
        guard let url = URL(string: "https://store.steampowered.com/api/featuredcategories?cc=cn&l=zh") else {
            return ([], [], "Steam 接口不可用")
        }
        do {
            let data = try await fetch(url, referer: "https://store.steampowered.com/", timeout: 7)
            let parsed = try SteamGameParser.parse(data: data)
            return (parsed.top, parsed.coming, nil)
        } catch {
            return ([], [], "Steam 在当前网络暂时不可达")
        }
    }

    private static func loadAppStore(
        url: String,
        source: String,
        idPrefix: String
    ) async -> (items: [GameRankItem], error: String?) {
        guard let url = URL(string: url) else { return ([], "App Store 榜单不可用") }
        do {
            let data = try await fetch(url, referer: nil, timeout: 15)
            return (Array(try AppStoreGameParser.parse(data: data, source: source, idPrefix: idPrefix).prefix(20)), nil)
        } catch {
            return ([], "\(source)暂时不可用")
        }
    }

    private static func fetch(_ url: URL, referer: String?, timeout: TimeInterval) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Nomi/1.2 iOS", forHTTPHeaderField: "User-Agent")
        if let referer { request.setValue(referer, forHTTPHeaderField: "Referer") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else {
            throw GameDataError.invalidPayload
        }
        return data
    }
}

