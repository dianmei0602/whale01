import Foundation

enum AppStoreGameParser {
    static func parse(data: Data, source: String, idPrefix: String) throws -> [GameRankItem] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let feed = root["feed"] as? [String: Any],
              let entries = feed["entry"] as? [[String: Any]]
        else {
            throw GameDataError.invalidPayload
        }

        let games = entries.filter { entry in
            guard let category = entry["category"] as? [String: Any],
                  let attributes = category["attributes"] as? [String: Any]
            else { return false }
            return attributes["im:id"] as? String == "6014"
                || attributes["term"] as? String == "Games"
                || attributes["label"] as? String == "游戏"
        }

        return games.enumerated().compactMap { index, entry in
            guard let name = label(entry["im:name"]),
                  let id = ((entry["id"] as? [String: Any])?["attributes"] as? [String: Any])?["im:id"] as? String
            else { return nil }

            let images = entry["im:image"] as? [[String: Any]] ?? []
            let image = images.last.flatMap { label($0) }
            let links = entry["link"] as? [[String: Any]] ?? []
            let href = links.first?["attributes"].flatMap { $0 as? [String: Any] }?["href"] as? String
            let artist = label(entry["im:artist"]) ?? ""
            let summary = label(entry["summary"]) ?? ""
            let price = label(entry["im:price"]) ?? "价格未知"
            return GameRankItem(
                id: "\(idPrefix)-\(id)",
                rank: index + 1,
                name: name,
                source: source,
                subtitle: artist.isEmpty ? summary : "\(artist) · \(summary)",
                priceText: price,
                artworkURL: image.flatMap(URL.init(string:)),
                storeURL: href.flatMap(URL.init(string:)),
                platform: "iPhone",
                storeID: id
            )
        }
    }

    private static func label(_ value: Any?) -> String? {
        (value as? [String: Any])?["label"] as? String
    }
}

enum GameDataError: LocalizedError {
    case invalidPayload

    var errorDescription: String? {
        "游戏榜单格式暂时无法识别"
    }
}

