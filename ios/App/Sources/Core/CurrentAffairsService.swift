import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FoundationXML)
import FoundationXML
#endif

enum CurrentAffairsService {
    private static let feeds: [(String, String, NewsCategory)] = [
        ("中国新闻网", "https://www.chinanews.com.cn/rss/scroll-news.xml", .domestic),
        ("中国新闻网·中国", "https://www.chinanews.com.cn/rss/china.xml", .domestic),
        ("中国新闻网·财经", "https://www.chinanews.com.cn/rss/finance.xml", .economy),
        ("中国新闻网·汽车", "https://www.chinanews.com.cn/rss/auto.xml", .automotive),
        ("中国新闻网·国际", "https://www.chinanews.com.cn/rss/world.xml", .international),
        ("36氪", "https://www.36kr.com/feed", .technology)
    ]

    static func load() async -> [NewsArticle] {
        await withTaskGroup(of: [NewsArticle].self) { group in
            for feed in feeds {
                group.addTask {
                    await fetchFeed(source: feed.0, urlString: feed.1, category: feed.2)
                }
            }

            var all: [NewsArticle] = []
            for await articles in group {
                all.append(contentsOf: articles)
            }

            var seenLinks = Set<String>()
            var seenTitles = Set<String>()
            return all
                .filter {
                    seenLinks.insert($0.link.absoluteString).inserted
                        && seenTitles.insert($0.title).inserted
                }
                .sorted {
                    ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
                }
                .prefix(30)
                .map { $0 }
        }
    }

    private static func fetchFeed(
        source: String,
        urlString: String,
        category: NewsCategory
    ) async -> [NewsArticle] {
        guard let url = URL(string: urlString) else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Nomi/1.2 iOS", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { return [] }

        let parser = CurrentAffairsParser(source: source, category: category)
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else { return [] }
        return Array(parser.articles.prefix(10))
    }
}

private final class CurrentAffairsParser: NSObject, XMLParserDelegate {
    private let source: String
    private let category: NewsCategory
    private(set) var articles: [NewsArticle] = []
    private var title = ""
    private var link = ""
    private var dateText = ""
    private var buffer = ""
    private var insideItem = false

    init(source: String, category: NewsCategory) {
        self.source = source
        self.category = category
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        buffer = ""
        if elementName.lowercased() == "item" {
            insideItem = true
            title = ""
            link = ""
            dateText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { buffer += string }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let value = String(data: CDATABlock, encoding: .utf8) { buffer += value }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = elementName.lowercased()
        if insideItem {
            switch name {
            case "title": title = clean(buffer)
            case "link": link = clean(buffer)
            case "pubdate": dateText = clean(buffer)
            case "item":
                append()
                insideItem = false
            default: break
            }
        }
        buffer = ""
    }

    private func append() {
        guard !title.isEmpty,
              title.unicodeScalars.contains(where: {
                  (0x4E00...0x9FFF).contains($0.value)
              }),
              let url = URL(string: link),
              url.scheme?.hasPrefix("http") == true
        else { return }
        articles.append(
            NewsArticle(
                id: link,
                title: title,
                link: url,
                source: source,
                category: category,
                publishedAt: parseDate(dateText)
            )
        )
    }

    private func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: value)
    }
}

