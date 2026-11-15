import Foundation

// MARK: - 九档表情（纯色版）
//
// 全部数值来自设计稿 flat-motion.html：一块实色，没有渐变/高光/瞳孔。
// 情绪只由四个几何量表达：眼宽、眼高、间距、眼皮。
// 这里没有 UI，可以被单独编译和验证。

enum EyeShape: Equatable {
    case circle
    case arcUp      // ∩ 开心
    case arcDown    // ∪ 困
}

struct EyeSpec: Equatable {
    var width: Double
    var height: Double
    var lid: Double = 0          // 0…1，上眼睑压下来的比例
    var shape: EyeShape = .circle
    var offsetY: Double = 0
    var tilt: Double = 0
}

struct PetMood: Equatable {
    let id: String
    let left: EyeSpec
    let right: EyeSpec
    let gap: Double

    static func circle(_ w: Double, _ h: Double, lid: Double = 0) -> EyeSpec {
        EyeSpec(width: w, height: h, lid: lid)
    }

    // MARK: 九档

    static let calm = PetMood(
        id: "calm",
        left: circle(9.0, 9.0),
        right: circle(9.0, 9.0),
        gap: 7.6
    )

    static let happy = PetMood(
        id: "happy",
        left: EyeSpec(width: 10.6, height: 8.4, shape: .arcUp),
        right: EyeSpec(width: 10.6, height: 8.4, shape: .arcUp),
        gap: 6.6
    )

    static let excited = PetMood(
        id: "excited",
        left: circle(10.8, 10.8),
        right: circle(10.8, 10.8),
        gap: 9.6
    )

    static let curious = PetMood(
        id: "curious",
        left: circle(9.8, 9.8, lid: 0.06),
        right: EyeSpec(width: 8.4, height: 8.4, lid: 0.06, offsetY: -1.8),
        gap: 7.4
    )

    static let focus = PetMood(
        id: "focus",
        left: circle(8.4, 7.2, lid: 0.26),
        right: circle(8.4, 7.2, lid: 0.26),
        gap: 6.2
    )

    static let sideeye = PetMood(
        id: "sideeye",
        left: circle(8.6, 7.8, lid: 0.26),
        right: circle(9.4, 9.0),
        gap: 8.0
    )

    static let tired = PetMood(
        id: "tired",
        left: EyeSpec(width: 10.4, height: 8.6, shape: .arcDown),
        right: EyeSpec(width: 10.4, height: 8.6, shape: .arcDown),
        gap: 6.6
    )

    static let sleep = PetMood(
        id: "sleep",
        left: circle(9.8, 8.8, lid: 0.78),
        right: circle(9.8, 8.8, lid: 0.78),
        gap: 7.4
    )

    static let talk = PetMood(
        id: "talk",
        left: circle(8.6, 8.6, lid: 0.04),
        right: circle(8.6, 8.6, lid: 0.04),
        gap: 7.4
    )

    static let all: [PetMood] = [calm, happy, excited, curious, focus, sideeye, tired, sleep, talk]

    /// 按 id 取表情（Widget 用）
    static func mood(id: String) -> PetMood {
        return all.first { $0.id == id } ?? .calm
    }

    // MARK: 规则 → 表情

    static func mood(forCardID cardID: String?) -> PetMood {
        guard let cardID = cardID else { return .sleep }
        switch cardID {
        case "rain", "air", "warm": return .curious
        case "todo":                return .sideeye
        case "meet":                return .focus
        case "sport":               return .excited
        case "sleep":               return .tired
        default:                    return .calm
        }
    }
}