import Foundation

enum GameSection: String, CaseIterable, Identifiable, Hashable {
    case news = "新闻"
    case steam = "Steam"
    case coming = "期待榜"
    case free = "手游免费榜"
    case grossing = "手游畅销榜"

    var id: String { rawValue }
}

struct GameRankItem: Identifiable, Hashable {
    let id: String
    let rank: Int
    let name: String
    let source: String
    let subtitle: String
    let priceText: String
    let artworkURL: URL?
    let storeURL: URL?
    let platform: String
    let storeID: String
}

struct GameDetailRecord {
    let description: String
    let developer: String
    let publisher: String
    let releaseDate: String
    let genres: [String]
    let screenshots: [URL]
    let rating: Double?
    let ratingCount: Int?
    let version: String
    let priceText: String
}

struct GameDigest {
    var news: [NewsArticle]
    var steamTop: [GameRankItem]
    var steamComing: [GameRankItem]
    var iosFree: [GameRankItem]
    var iosGrossing: [GameRankItem]
    var failures: [GameSection: String]
    var fetchedAt: Date

    var isEmpty: Bool {
        news.isEmpty && steamTop.isEmpty && steamComing.isEmpty && iosFree.isEmpty && iosGrossing.isEmpty
    }

    static func empty(failures: [GameSection: String] = [:]) -> GameDigest {
        GameDigest(
            news: [],
            steamTop: [],
            steamComing: [],
            iosFree: [],
            iosGrossing: [],
            failures: failures,
            fetchedAt: Date()
        )
    }
}

