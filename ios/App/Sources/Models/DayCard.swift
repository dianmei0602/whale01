import Foundation

/// 一张卡 = 情况 → 判断 → 动作。
/// 动作不是按钮，是手势：左滑划掉，右滑完成。
///
/// 注意：这里不 import SwiftUI。逻辑层不依赖 UI，
/// 颜色只用一个语义标记表示，映射放到 UI 层做。
struct DayCard: Identifiable {
    let id: String
    let time: String
    let icon: String
    let tint: CardTint
    let fact: String
    let advice: String
    let rank: Int
    let canComplete: Bool
}

enum CardTint {
    case blue
    case orange
    case green
    case teal
    case purple
}
