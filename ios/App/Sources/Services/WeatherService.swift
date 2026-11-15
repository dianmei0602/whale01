import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct WeatherService {
    var latitude: Double = 31.23
    var longitude: Double = 121.47

    private struct Response: Decodable {
        struct Current: Decodable {
            let time: String
            let temperature_2m: Double
            let relative_humidity_2m: Double?
            let apparent_temperature: Double?
            let weather_code: Int?
            let wind_speed_10m: Double?
            let wind_direction_10m: Double?
        }
        struct Hourly: Decodable {
            let time: [String]
            let temperature_2m: [Double]
            let precipitation_probability: [Double?]
        }
        struct Daily: Decodable {
            let time: [String]
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let weather_code: [Int]?
        }
        let timezone: String
        let current: Current
        let hourly: Hourly
        let daily: Daily
    }

    func load() async throws -> Weather {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "4"),
            URLQueryItem(name: "past_days", value: "1")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(Response.self, from: data)
        return Self.map(response)
    }

    private static func map(_ response: Response) -> Weather {
        let timeZone = TimeZone(identifier: response.timezone) ?? .current

        let stampFormatter = DateFormatter()
        stampFormatter.locale = Locale(identifier: "en_US_POSIX")
        stampFormatter.timeZone = timeZone
        stampFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = timeZone
        dayFormatter.dateFormat = "yyyy-MM-dd"

        let hours: [Weather.Hour] = zip(response.hourly.time,
                                        zip(response.hourly.temperature_2m,
                                            response.hourly.precipitation_probability))
            .compactMap { entry in
                let (stamp, values) = entry
                guard let date = stampFormatter.date(from: stamp) else { return nil }
                return Weather.Hour(time: date,
                                    temperature: values.0,
                                    precipitationProbability: values.1 ?? 0)
            }

        let currentTime = stampFormatter.date(from: response.current.time) ?? Date()
        let todayString = dayFormatter.string(from: currentTime)

        var index = 0
        if let found = response.daily.time.firstIndex(of: todayString) {
            index = found
        }

        let todayMax = index < response.daily.temperature_2m_max.count
            ? response.daily.temperature_2m_max[index] : 20
        let todayMin = index < response.daily.temperature_2m_min.count
            ? response.daily.temperature_2m_min[index] : 10
        let yesterdayMax = index > 0 ? response.daily.temperature_2m_max[index - 1] : nil

        // 未来几天（从今天开始）
        var days: [WeatherDay] = []
        for offset in 0..<(4 - index) {
            let i = index + offset
            guard i < response.daily.time.count,
                  i < response.daily.temperature_2m_max.count,
                  i < response.daily.temperature_2m_min.count,
                  let date = dayFormatter.date(from: response.daily.time[i])
            else { continue }

            let code = (response.daily.weather_code?.indices.contains(i) ?? false)
                ? (response.daily.weather_code?[i] ?? 2)
                : 2

            days.append(WeatherDay(date: date,
                                   code: code,
                                   max: response.daily.temperature_2m_max[i],
                                   min: response.daily.temperature_2m_min[i]))
        }

        return Weather(currentTime: currentTime,
                       currentTemperature: response.current.temperature_2m,
                       feelsLike: response.current.apparent_temperature ?? response.current.temperature_2m,
                       humidity: response.current.relative_humidity_2m ?? 0,
                       windSpeed: response.current.wind_speed_10m ?? 0,
                       windDirection: response.current.wind_direction_10m ?? 0,
                       weatherCode: response.current.weather_code ?? 2,
                       hours: hours,
                       todayMax: todayMax,
                       todayMin: todayMin,
                       yesterdayMax: yesterdayMax,
                       days: days)
    }
}

struct AirService {
    var latitude: Double = 31.23
    var longitude: Double = 121.47

    private struct Response: Decodable {
        struct Current: Decodable {
            let pm2_5: Double?
        }
        let current: Current
    }

    func load() async throws -> Double? {
        var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "pm2_5"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.current.pm2_5
    }
}
