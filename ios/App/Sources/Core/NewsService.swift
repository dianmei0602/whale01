import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FoundationXML)
import FoundationXML
#endif

enum NewsService {

    static func load(limit: Int = 6) async -> NewsDigest {
        async let international = loadInternational(limit: limit)
        async let ai = loadAI(limit: limit)
        return await NewsDigest(international: international, aiTechnology: ai, fetchedAt: Date())
    }

    static func loadInternational(limit: Int = 12) async -> [NewsArticle] {
        await fetchAvailable(
            feeds: [
                ("联合国新闻", URL(string: "https://news.un.org/feed/subscribe/zh/news/all/rss.xml")!),
                ("德国之声中文", URL(string: "https://rss.dw.com/rdf/rss-chi-all")!),
                ("BBC 中文", URL(string: "https://feeds.bbci.co.uk/zhongwen/simp/rss.xml")!)
            ],
            category: .international,
            limit: limit
        )

    }

    static func loadAI(limit: Int = 20) async -> [NewsArticle] {
        await fetchAvailable(
            feeds: [
                ("量子位", URL(string: "https://www.qbitai.com/feed")!),
                ("InfoQ 中文", URL(string: "https://www.infoq.cn/feed")!)
            ],
            category: .aiTechnology,
            limit: limit
        )

    }

    private static func fetchAvailable(
        feeds: [(String, URL)],
        category: NewsCategory,
        limit: Int
    ) async -> [NewsArticle] {
        await withTaskGroup(of: [NewsArticle].self) { group in
            for (source, url) in feeds {
                group.addTask {
                    (try? await fetchFeed(source: source, url: url, category: category)) ?? []
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
                        && seenTitles.insert($0.title.lowercased()).inserted
                }
                .sorted {
                    ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
                }
                .prefix(max(0, limit))
                .map { $0 }
        }
    }

    private static func fetchFeed(
        source: String,
        url: URL,
        category: NewsCategory
    ) async throws -> [NewsArticle] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Nomi/1.1 iOS News Reader", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { return [] }

        let parser = FeedParser(source: source, category: category)
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else { return [] }

        var seen = Set<String>()
        return parser.items
            .filter { seen.insert($0.link.absoluteString).inserted }
            .sorted {
                ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
            }
    }
}

private final class FeedParser: NSObject, XMLParserDelegate {
    let source: String
    let category: NewsCategory
    private(set) var items: [NewsArticle] = []

    private var title = ""
    private var link = ""
    private var dateText = ""
    private var currentElement = ""
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
        currentElement = elementName.lowercased()
        buffer = ""

        if currentElement == "item" || currentElement == "entry" {
            insideItem = true
            title = ""
            link = ""
            dateText = ""
        }

        if insideItem, currentElement == "link",
           let href = attributeDict["href"] {
            link = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let value = String(data: CDATABlock, encoding: .utf8) {
            buffer += value
        }
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
            case "title":
                title = clean(buffer)
            case "link":
                if link.isEmpty { link = clean(buffer) }
            case "pubdate", "published", "updated":
                dateText = clean(buffer)
            case "item", "entry":
                appendItem()
                insideItem = false
            default:
                break
            }
        }

        currentElement = ""
        buffer = ""
    }

    private func appendItem() {
        guard !title.isEmpty,
              containsChinese(title),
              let url = URL(string: link),
              url.scheme?.hasPrefix("http") == true
        else { return }

        items.append(NewsArticle(
            id: url.absoluteString,
            title: title,
            link: url,
            source: source,
            category: category,
            publishedAt: parseDate(dateText)
        ))
    }

    private func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsChinese(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value)
        }
    }

    private func parseDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }

        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, d MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}
