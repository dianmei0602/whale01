import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

final class GameNewsParser: NSObject, XMLParserDelegate {
    private(set) var articles: [NewsArticle] = []
    private var title = ""
    private var link = ""
    private var dateText = ""
    private var buffer = ""
    private var insideItem = false

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
              let url = URL(string: link),
              url.scheme?.hasPrefix("http") == true
        else { return }
        articles.append(
            NewsArticle(
                id: link,
                title: title,
                link: url,
                source: "游研社",
                category: .gaming,
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

