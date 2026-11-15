import Foundation

enum GameDetailParser {
    static func parseSteam(data: Data, appID: String) throws -> GameDetailRecord {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let app = root[appID] as? [String: Any],
              app["success"] as? Bool == true,
              let payload = app["data"] as? [String: Any]
        else {
            throw GameDataError.invalidPayload
        }

        let description = clean(
            payload["detailed_description"] as? String
                ?? payload["about_the_game"] as? String
                ?? payload["short_description"] as? String
                ?? ""
        )
        let screenshots = (payload["screenshots"] as? [[String: Any]] ?? []).compactMap { row in
            (row["path_full"] as? String).flatMap(URL.init(string:))
        }
        let developer = (payload["developers"] as? [String] ?? []).joined(separator: "、")
        let publisher = (payload["publishers"] as? [String] ?? []).joined(separator: "、")
        let release = (payload["release_date"] as? [String: Any])?["date"] as? String ?? ""
        let genres = (payload["genres"] as? [[String: Any]] ?? []).compactMap { $0["description"] as? String }
        let price = ((payload["price_overview"] as? [String: Any])?["final_formatted"] as? String) ?? "价格未知"

        return GameDetailRecord(
            description: description,
            developer: developer,
            publisher: publisher,
            releaseDate: release,
            genres: genres,
            screenshots: screenshots,
            rating: nil,
            ratingCount: nil,
            version: "",
            priceText: price
        )
    }

    static func parseAppStore(data: Data) throws -> GameDetailRecord {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let row = (root["results"] as? [[String: Any]])?.first
        else {
            throw GameDataError.invalidPayload
        }

        let description = row["description"] as? String ?? ""
        let screenshots = (row["screenshotUrls"] as? [String] ?? []).compactMap(URL.init(string:))
        return GameDetailRecord(
            description: description,
            developer: row["sellerName"] as? String ?? row["artistName"] as? String ?? "",
            publisher: row["artistName"] as? String ?? "",
            releaseDate: row["releaseDate"] as? String ?? "",
            genres: row["genres"] as? [String] ?? [],
            screenshots: screenshots,
            rating: number(row["averageUserRating"]),
            ratingCount: number(row["userRatingCount"]).map(Int.init),
            version: row["version"] as? String ?? "",
            priceText: row["formattedPrice"] as? String ?? "价格未知"
        )
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

