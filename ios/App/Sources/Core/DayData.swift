import Foundation

/// 一个日程。纯数据，不依赖 EventKit，方便规则引擎和测试直接使用。
struct MeetingItem: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date?
    let isAllDay: Bool
    let location: String?
}


/// 一次定位结果。纯数据，AppState 不需要知道 CoreLocation 的存在。
struct LocationFix: Sendable {
    let latitude: Double
    let longitude: Double
    let cityName: String?
    let district: String?
    let street: String?
    let number: String?
    let placeName: String?
    let horizontalAccuracy: Double

    /// 「杭州市西湖区文三路 478 号」这种完整地址
    var fullAddress: String {
        var parts: [String] = []
        if let city = cityName, !city.isEmpty { parts.append(city) }
        if let district = district, !district.isEmpty, district != cityName {
            parts.append(district)
        }
        if let street = street, !street.isEmpty {
            parts.append(street + (number ?? ""))
        }
        return parts.isEmpty ? "当前位置" : parts.joined()
    }

    var coordinateText: String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }
}