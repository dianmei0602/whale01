import Foundation

enum NewsCategory: String, Equatable {
    case domestic = "国内"
    case international = "国际"
    case economy = "经济"
    case automotive = "汽车"
    case technology = "科技"
    case aiTechnology = "AI 科技"
    case gaming = "游戏"
}

struct NewsArticle: Identifiable, Hashable {
    let id: String
    let title: String
    let link: URL
    let source: String
    let category: NewsCategory
    let publishedAt: Date?
}

struct NewsDigest {
    let international: [NewsArticle]
    let aiTechnology: [NewsArticle]
    let fetchedAt: Date

    var isEmpty: Bool {
        international.isEmpty && aiTechnology.isEmpty
    }
}

