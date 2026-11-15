import Foundation

struct WeatherDay: Hashable {
    let date: Date
    let code: Int
    let max: Double
    let min: Double
}

struct Weather {
    struct Hour {
        let time: Date
        let temperature: Double
        let precipitationProbability: Double
    }

    let currentTime: Date
    let currentTemperature: Double
    let feelsLike: Double
    let humidity: Double
    let windSpeed: Double        // km/h
    let windDirection: Double    // 度，0 = 北
    let weatherCode: Int

    let hours: [Hour]

    let todayMax: Double
    let todayMin: Double
    let yesterdayMax: Double?

    /// 未来几天（含今天）
    let days: [WeatherDay]
}

/// WMO 天气代码 → 中文 + 图标 + 风力
enum WeatherCode {

    static func text(_ code: Int) -> String {
        switch code {
        case 0:          return "晴"
        case 1:          return "大部晴朗"
        case 2:          return "多云"
        case 3:          return "阴"
        case 45, 48:     return "有雾"
        case 51, 53, 55: return "毛毛雨"
        case 56, 57:     return "冻雨"
        case 61:         return "小雨"
        case 63:         return "中雨"
        case 65:         return "大雨"
        case 66, 67:     return "冻雨"
        case 71:         return "小雪"
        case 73:         return "中雪"
        case 75:         return "大雪"
        case 77:         return "雪粒"
        case 80, 81:     return "阵雨"
        case 82:         return "强阵雨"
        case 85, 86:     return "阵雪"
        case 95:         return "雷雨"
        case 96, 99:     return "雷雨冰雹"
        default:         return "多云"
        }
    }

    static func symbol(_ code: Int) -> String {
        switch code {
        case 0, 1:        return "sun.max"
        case 2:           return "cloud.sun"
        case 3:           return "cloud"
        case 45, 48:      return "cloud.fog"
        case 51, 53, 55:  return "cloud.drizzle"
        case 56, 57, 66, 67: return "cloud.sleet"
        case 61, 63, 65, 80, 81, 82: return "cloud.rain"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow"
        case 95, 96, 99:  return "cloud.bolt.rain"
        default:          return "cloud.sun"
        }
    }

    static func windDirection(_ degrees: Double) -> String {
        let names = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
        let index = Int(((degrees + 22.5) / 45).rounded()) % 8
        return names[(index + 8) % 8] + "风"
    }

    /// km/h → 蒲福风级
    static func windLevel(_ kmh: Double) -> String {
        let limits: [Double] = [1, 5, 11, 19, 28, 38, 49, 61, 74, 88, 102, 117]
        var level = 12
        for (index, limit) in limits.enumerated() where kmh < limit {
            level = index
            break
        }
        return "\(level) 级"
    }
}
