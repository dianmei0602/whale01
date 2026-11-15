import Foundation

/// A complete, pinned-source classical quotation used by Nomi's daily quote.
struct ClassicalQuote: Identifiable, Codable, Hashable {
    let id: String
    let numericId: Int
    let text: String
    let hanziCount: Int
    let book: String
    let chapter: String
    let dynasty: String
    let category: String
    let verified: Bool
    let verificationLevel: String
    let punctuationNormalized: Bool
    let sourcePath: String
    let sourceUrl: String

    var citation: String {
        "《\(book)·\(chapter)》"
    }

    var sourceLink: URL? {
        URL(string: sourceUrl)
    }
}

enum ClassicalQuoteRepository {
    static let expectedCount = 365

    static func load(from url: URL) throws -> [ClassicalQuote] {
        let data = try Data(contentsOf: url)
        let quotes = try JSONDecoder().decode([ClassicalQuote].self, from: data)
        return try validated(quotes)
    }

    static func bundled() -> [ClassicalQuote] {
        guard let url = Bundle.main.url(forResource: "classical_quotes", withExtension: "json"),
              let quotes = try? load(from: url),
              !quotes.isEmpty
        else {
            return []
        }
        return quotes
    }

    static func validated(_ quotes: [ClassicalQuote]) throws -> [ClassicalQuote] {
        guard quotes.count == expectedCount else {
            throw ValidationError.unexpectedCount(quotes.count)
        }
        guard Set(quotes.map(\.id)).count == quotes.count else {
            throw ValidationError.duplicateIDs
        }
        guard Set(quotes.map(hanziOnly)).count == quotes.count else {
            throw ValidationError.duplicateText
        }
        guard quotes.allSatisfy({ (15...30).contains($0.hanziCount) }) else {
            throw ValidationError.invalidLength
        }
        guard quotes.allSatisfy({
            $0.verified &&
            !$0.sourcePath.isEmpty &&
            $0.sourceLink != nil
        }) else {
            throw ValidationError.missingSource
        }
        return quotes
    }

    private static func hanziOnly(_ quote: ClassicalQuote) -> String {
        quote.text.unicodeScalars
            .filter { scalar in
                (0x3400...0x4DBF).contains(scalar.value) ||
                (0x4E00...0x9FFF).contains(scalar.value)
            }
            .map(String.init)
            .joined()
    }

    enum ValidationError: LocalizedError {
        case unexpectedCount(Int)
        case duplicateIDs
        case duplicateText
        case invalidLength
        case missingSource

        var errorDescription: String? {
            switch self {
            case .unexpectedCount(let count): return "古籍数量应为 365，实际为 \(count)"
            case .duplicateIDs: return "古籍数据存在重复 ID"
            case .duplicateText: return "古籍数据存在重复原文"
            case .invalidLength: return "古籍原文超出 15–30 个汉字"
            case .missingSource: return "古籍原文缺少可核验来源"
            }
        }
    }
}

struct DailyEncouragement: Identifiable, Equatable {
    let id: String
    let text: String
    let hanziCount: Int
    let book: String
    let chapter: String
    let dynasty: String
    let category: String
    let sourceUrl: String
    let verificationLevel: String

    init(quote: ClassicalQuote) {
        id = quote.id
        text = quote.text
        hanziCount = quote.hanziCount
        book = quote.book
        chapter = quote.chapter
        dynasty = quote.dynasty
        category = quote.category
        sourceUrl = quote.sourceUrl
        verificationLevel = quote.verificationLevel
    }

    var citation: String {
        "《\(book)·\(chapter)》"
    }

    var sourceLink: URL? {
        URL(string: sourceUrl)
    }

    static let fallback = DailyEncouragement(
        quote: ClassicalQuote(
            id: "fallback-lunyu-xueer",
            numericId: 0,
            text: "道千乘之国，敬事而信，节用而爱人，使民以时。",
            hanziCount: 18,
            book: "论语",
            chapter: "学而篇",
            dynasty: "春秋",
            category: "治国",
            verified: true,
            verificationLevel: "curated-source-match",
            punctuationNormalized: true,
            sourcePath: "双语数据/论语/学而篇/source.txt",
            sourceUrl: "https://github.com/NiuTrans/Classical-Modern"
        )
    )

    static let phrases: [DailyEncouragement] = {
        ClassicalQuoteRepository.bundled().map(DailyEncouragement.init(quote:))
    }()

    private struct HistoryEntry: Codable {
        let day: String
        let quoteID: String
    }

    private static let historyKey = "nomi.dailyEncouragement.history.v2"

    static func today(
        now: Date = Date(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard,
        quotes: [DailyEncouragement]? = nil
    ) -> DailyEncouragement {
        let pool = resolvedQuotes(quotes)
        let start = calendar.startOfDay(for: now)
        let todayKey = dayKey(for: start, calendar: calendar)

        var history = loadHistory(defaults)
        if let existing = history.first(where: { $0.day == todayKey }),
           let quote = pool.first(where: { $0.id == existing.quoteID }) {
            return quote
        }

        let cutoff = calendar.date(byAdding: .day, value: -29, to: start) ?? start
        let cutoffKey = dayKey(for: cutoff, calendar: calendar)
        history = history.filter { $0.day >= cutoffKey }

        let used = Set(history.map(\.quoteID))
        let available = pool.filter { !used.contains($0.id) }
        let selected = (available.isEmpty ? pool : available).randomElement() ?? fallback

        history.append(HistoryEntry(day: todayKey, quoteID: selected.id))
        history = Array(history.suffix(30))
        saveHistory(history, defaults)
        return selected
    }

    static func alternative(
        to currentID: String,
        defaults: UserDefaults = .standard,
        quotes: [DailyEncouragement]? = nil
    ) -> DailyEncouragement {
        let pool = resolvedQuotes(quotes)
        let history = loadHistory(defaults)
        let used = Set(history.map(\.quoteID))
        let fresh = pool.filter { $0.id != currentID && !used.contains($0.id) }
        let candidates = fresh.isEmpty ? pool.filter { $0.id != currentID } : fresh
        return candidates.randomElement() ?? fallback
    }

    static func recordChoice(
        _ quote: DailyEncouragement,
        now: Date = Date(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) {
        let start = calendar.startOfDay(for: now)
        let todayKey = dayKey(for: start, calendar: calendar)
        let cutoff = calendar.date(byAdding: .day, value: -29, to: start) ?? start
        let cutoffKey = dayKey(for: cutoff, calendar: calendar)

        var history = loadHistory(defaults).filter { $0.day >= cutoffKey && $0.day != todayKey }
        history.append(HistoryEntry(day: todayKey, quoteID: quote.id))
        saveHistory(Array(history.suffix(30)), defaults)
    }

    static func loadBundledQuotes() -> [DailyEncouragement] {
        let loaded = ClassicalQuoteRepository.bundled().map(DailyEncouragement.init(quote:))
        return loaded.isEmpty ? [fallback] : loaded
    }

    private static func resolvedQuotes(_ quotes: [DailyEncouragement]?) -> [DailyEncouragement] {
        if let quotes, !quotes.isEmpty {
            return quotes
        }
        return phrases.isEmpty ? [fallback] : phrases
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func loadHistory(_ defaults: UserDefaults) -> [HistoryEntry] {
        guard let data = defaults.data(forKey: historyKey),
              let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return [] }
        return entries
    }

    private static func saveHistory(_ history: [HistoryEntry], _ defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: historyKey)
    }
}
