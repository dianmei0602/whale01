import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 用户关注的其它城市。存的名字要能直接拼进问题里（「北京天气」）。
struct WatchedCity: Codable, Equatable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let latitude: Double
    let longitude: Double
}

/// 城市名 → 经纬度。用 Open-Meteo 的免费地理编码接口，不需要 key。
enum GeocodingService {

    struct Response: Decodable {
        struct Result: Decodable {
            let name: String
            let latitude: Double
            let longitude: Double
            let country: String?
            let admin1: String?
        }
        let results: [Result]?
    }

    /// 查不到返回 nil
    static func search(_ name: String) async -> WatchedCity? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "zh"),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            guard let first = decoded.results?.first else { return nil }

            return WatchedCity(name: first.name,
                               latitude: first.latitude,
                               longitude: first.longitude)
        } catch {
            return nil
        }
    }
}
