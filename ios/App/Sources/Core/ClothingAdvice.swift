import Foundation

/// 穿衣建议：纯计算，不联网、不碰 UI。
///
/// 输入是天气里的几个数，输出一句人话（尽量短，能塞进卡片一行）。
enum ClothingAdvice {

    /// 返回一句建议，比如「短袖就行；晚上降到 15°，带件外套」。
    /// - Parameters:
    ///   - maxTemp: 今天最高温
    ///   - minTemp: 今天最低温
    ///   - weatherCode: WMO 代码
    ///   - rainChance: 未来几小时的最大降水概率（0…100）
    ///   - windKmh: 风速
    static func advice(maxTemp: Double,
                       minTemp: Double,
                       weatherCode: Int,
                       rainChance: Double,
                       windKmh: Double) -> String {

        var parts: [String] = []

        // ① 主体：按最高温决定穿什么
        parts.append(mainLayer(maxTemp))

        // ② 温差：超过 8 度就提醒带外套
        let gap = maxTemp - minTemp
        if gap >= 8 {
            parts.append("早晚差 \(Int(gap.rounded()))°，多带一件")
        }

        // ③ 雨 / 雪
        if isSnowy(code: weatherCode) {
            parts.append("路滑慢点")
        } else if isRainy(code: weatherCode) || rainChance >= 50 {
            parts.append("带伞")
        }

        // ④ 风大
        if windKmh >= 30 {
            parts.append("风大")
        }

        return parts.joined(separator: "；")
    }

    // MARK: - 主体

    private static func mainLayer(_ temp: Double) -> String {
        switch temp {
        case 30...:   return "短袖，注意防晒"
        case 25..<30: return "短袖就行"
        case 20..<25: return "长袖或薄外套"
        case 15..<20: return "外套加长裤"
        case 10..<15: return "厚外套，早晚凉"
        case 5..<10:  return "外套加毛衣"
        default:      return "羽绒服别嫌厚"
        }
    }

    private static func isSnowy(code: Int) -> Bool {
        switch code {
        case 71, 73, 75, 77, 85, 86:
            return true
        default:
            return false
        }
    }

    private static func isRainy(code: Int) -> Bool {
        switch code {
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67,
             80, 81, 82, 95, 96, 99:
            return true
        default:
            return false
        }
    }
}
