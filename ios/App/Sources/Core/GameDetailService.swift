import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum GameDetailService {
    static func load(_ item: GameRankItem) async -> Result<GameDetailRecord, Error> {
        do {
            if item.platform == "Steam" {
                let url = URL(string: "https://store.steampowered.com/api/appdetails?appids=\(item.storeID)&cc=cn&l=zh")!
                let data = try await fetch(url)
                return .success(try GameDetailParser.parseSteam(data: data, appID: item.storeID))
            }
            let url = URL(string: "https://itunes.apple.com/lookup?id=\(item.storeID)&country=cn")!
            let data = try await fetch(url)
            return .success(try GameDetailParser.parseAppStore(data: data))
        } catch {
            return .failure(error)
        }
    }

    private static func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else {
            throw GameDataError.invalidPayload
        }
        return data
    }
}

