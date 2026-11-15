import SwiftUI
import UIKit

/// Nomi 1.7 语义色：亮色沿用「晨雾」，暗色为「暖炭黑」。
///
/// 演进：深海绿（泛绿，用户不满意）→ 石墨蓝（A）→ **暖炭黑（B，当前）**。
/// 暖炭黑是纸与木头的色温，配钛合金本体的金属冷光更有对比，
/// 也不像纯黑那样把眼睛吸干。
///
/// 所有页面只读取这些角色，不再在局部写死颜色。深浅色通过 UIKit
/// 动态色切换，因此按压、动画和系统设置变化都会在同一帧完成。
enum CardPalette {

    private static func dynamic(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
    }

    private static func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> UIColor {
        UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }

    // MARK: - 文字

    /// 夜墨主文字 #0A2630 / 暖白 #F4EDE6
    static let ink = dynamic(rgb(10, 38, 48), rgb(244, 237, 230))

    /// 次级文字 #5D777C / #B6A79A
    static let subtle = dynamic(rgb(93, 119, 124), rgb(182, 167, 154))

    /// 弱提示 #81969A / #8C7F72
    static let faint = dynamic(rgb(129, 150, 154), rgb(140, 127, 114))

    // MARK: - 页面与表面

    /// 晨雾页面 / 暖炭页面 #0C0A09
    static let screen = dynamic(rgb(239, 248, 246), rgb(12, 10, 9))

    /// 更深的页面层次
    static let screenDeep = dynamic(rgb(223, 238, 239), rgb(5, 4, 3))

    /// 标准玻璃卡
    static let surface = dynamic(
        rgba(255, 255, 255, 0.82),
        rgba(26, 22, 19, 0.78)
    )

    /// 需要更强阅读对比的卡
    static let surfaceStrong = dynamic(
        rgba(255, 255, 255, 0.96),
        rgba(32, 27, 23, 0.95)
    )

    /// 实色面，供 Sheet 和输入栏使用
    static let solid = dynamic(rgb(255, 255, 255), rgb(23, 20, 18))

    /// 卡片内抬起的次级块
    static let raised = dynamic(
        rgba(240, 249, 247, 0.94),
        rgba(36, 31, 26, 0.80)
    )

    // MARK: - 强调

    /// 青碧 #087F78 / 暖橙 #F0B26B
    static let accent = dynamic(rgb(8, 127, 120), rgb(240, 178, 107))

    /// 月光蓝 #2F75D0 / 陶土橘 #D98E6A
    static let accent2 = dynamic(rgb(47, 117, 208), rgb(217, 142, 106))

    /// 兼容旧调用。主强调色。
    static let navy = accent

    /// 强调填充上的文字
    static let navyInk = dynamic(rgb(255, 255, 255), rgb(34, 22, 6))

    /// 珊瑚橙 #B26E15 / #FFC273
    static let amber = dynamic(rgb(178, 110, 21), rgb(255, 194, 115))

    /// 提醒块
    static let amberSoft = dynamic(
        rgba(255, 244, 226, 0.94),
        rgba(255, 194, 115, 0.14)
    )

    /// 提醒文字
    static let amberInk = dynamic(rgb(137, 84, 13), rgb(255, 211, 151))

    /// 粉珊瑚
    static let rose = dynamic(rgb(195, 79, 101), rgb(255, 156, 172))

    /// 成功
    static let success = dynamic(rgb(22, 130, 92), rgb(126, 206, 150))

    /// 用户气泡
    static let bubbleMine = dynamic(rgb(8, 127, 120), rgb(58, 44, 32))

    // MARK: - 分隔与高光

    static let line = dynamic(
        rgba(8, 92, 96, 0.10),
        rgba(255, 235, 215, 0.10)
    )

    static let lineStrong = dynamic(
        rgba(8, 92, 96, 0.18),
        rgba(255, 235, 215, 0.18)
    )

    static let highlight = dynamic(
        rgba(255, 255, 255, 0.88),
        rgba(255, 255, 255, 0.08)
    )

    static let chrome = dynamic(
        rgba(241, 249, 248, 0.96),
        rgba(6, 4, 3, 0.96)
    )

    static let composer = dynamic(
        rgba(255, 255, 255, 0.92),
        rgba(20, 16, 13, 0.92)
    )

    static let tabbar = dynamic(
        rgba(244, 251, 250, 0.94),
        rgba(10, 8, 6, 0.92)
    )
}

extension CardTint {
    var color: Color {
        switch self {
        case .blue:
            return CardPalette.dynamicForTint(
                UIColor(red: 47 / 255, green: 117 / 255, blue: 208 / 255, alpha: 1),
                UIColor(red: 120 / 255, green: 185 / 255, blue: 255 / 255, alpha: 1)
            )
        case .orange:
            return CardPalette.amber
        case .green, .teal:
            return CardPalette.accent
        case .purple:
            return CardPalette.rose
        }
    }

    var background: Color { color.opacity(0.14) }
    var border: Color { color.opacity(0.25) }
}

extension CardPalette {
    fileprivate static func dynamicForTint(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
