import Foundation

enum SteamGameParser {
    static func parse(data: Data) throws -> (top: [GameRankItem], coming: [GameRankItem]) {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GameDataError.invalidPayload
        }
        return (
            parseItems(root["top_sellers"], rankPrefix: "steam-top", source: "Steam 畅销榜", comingSoon: false),
            parseItems(root["coming_soon"], rankPrefix: "steam-coming", source: "Steam 期待榜", comingSoon: true)
        )
    }

    private static func parseItems(
        _ value: Any?,
        rankPrefix: String,
        source: String,
        comingSoon: Bool
    ) -> [GameRankItem] {
        guard let container = value as? [String: Any],
              let rows = container["items"] as? [[String: Any]]
        else { return [] }

        return rows.enumerated().compactMap { index, row in
            guard let appID = number(row["id"]).map(Int.init),
                  let name = row["name"] as? String,
                  !name.isEmpty
            else { return nil }
            let finalPrice = number(row["final_price"])
            let currency = row["currency"] as? String ?? "CNY"
            let price = finalPrice.map { value -> String in
                if value <= 0 { return "免费" }
                return "\(currency) \(String(format: "%.2f", value / 100))"
            } ?? "价格未知"
            let priceText = comingSoon && (finalPrice ?? 0) <= 0 ? "价格待定" : price
            let image = row["header_image"] as? String ?? row["large_capsule_image"] as? String
            return GameRankItem(
                id: "\(rankPrefix)-\(appID)",
                rank: index + 1,
                name: name,
                source: source,
                subtitle: source,
                priceText: priceText,
                artworkURL: image.flatMap(URL.init(string:)),
                storeURL: URL(string: "https://store.steampowered.com/app/\(appID)"),
                platform: "Steam",
                storeID: String(appID)
            )
        }
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }
}

