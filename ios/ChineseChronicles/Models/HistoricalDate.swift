import Foundation

enum HistoricalPrecision: String, Codable, Hashable {
    case exact
    case year
    case approximate
    case disputed

    var label: String {
        switch self {
        case .exact:
            return "确切日期"
        case .year:
            return "通行纪年"
        case .approximate:
            return "约数"
        case .disputed:
            return "存在异说"
        }
    }
}

struct HistoricalDate: Codable, Hashable, Comparable {
    /// Negative values represent BCE. The corpus does not use a year zero.
    let year: Int
    let month: Int?
    let day: Int?
    let display: String
    let precision: HistoricalPrecision

    var sortKey: Int {
        year
    }

    static func < (lhs: HistoricalDate, rhs: HistoricalDate) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        if (lhs.month ?? 0) != (rhs.month ?? 0) {
            return (lhs.month ?? 0) < (rhs.month ?? 0)
        }
        return (lhs.day ?? 0) < (rhs.day ?? 0)
    }
}
