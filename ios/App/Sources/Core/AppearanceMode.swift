import Foundation

/// 浅色 / 深色 / 跟随系统。
/// 这里只放纯数据，和 SwiftUI 的映射放到 AppTheme.swift。
enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "浅色"
        case .dark:   return "深色"
        }
    }
}
