import SwiftUI
import UIKit

/// 鲸鱼 UI v9「深海极光」的语义色。
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

    /// 夜墨主文字 #0A2630 / 极光白 #EFFBFA
    static let ink = dynamic(rgb(10, 38, 48), rgb(239, 251, 250))

    /// 次级文字 #5D777C / #95ADB1
    static let subtle = dynamic(rgb(93, 119, 124), rgb(149, 173, 177))

    /// 弱提示 #81969A / #607D82
    static let faint = dynamic(rgb(129, 150, 154), rgb(96, 125, 130))

    // MARK: - 页面与表面

    /// 晨雾页面 / 深海页面
    static let screen = dynamic(rgb(239, 248, 246), rgb(7, 19, 26))

    /// 更深的页面层次
    static let screenDeep = dynamic(rgb(223, 238, 239), rgb(4, 11, 16))

    /// 标准玻璃卡
    static let surface = dynamic(
        rgba(255, 255, 255, 0.82),
        rgba(12, 33, 41, 0.72)
    )

    /// 需要更强阅读对比的卡
    static let surfaceStrong = dynamic(
        rgba(255, 255, 255, 0.96),
        rgba(15, 40, 49, 0.94)
    )

    /// 实色面，供 Sheet 和输入栏使用
    static let solid = dynamic(rgb(255, 255, 255), rgb(11, 34, 42))

    /// 卡片内抬起的次级块
    static let raised = dynamic(
        rgba(240, 249, 247, 0.94),
        rgba(19, 49, 58, 0.78)
    )

    // MARK: - 强调

    /// 极光青绿 #087F78 / #62EAD6
    static let accent = dynamic(rgb(8, 127, 120), rgb(98, 234, 214))

    /// 月光蓝 #2F75D0 / #78B9FF
    static let accent2 = dynamic(rgb(47, 117, 208), rgb(120, 185, 255))

    /// 兼容旧调用。深海 UI 里主强调就是极光青绿。
    static let navy = accent

    /// 强调填充上的文字
    static let navyInk = dynamic(rgb(255, 255, 255), rgb(5, 39, 32))

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
    static let success = dynamic(rgb(22, 130, 92), rgb(103, 229, 171))

    /// 用户气泡
    static let bubbleMine = dynamic(rgb(8, 127, 120), rgb(18, 68, 77))

    // MARK: - 分隔与高光

    static let line = dynamic(
        rgba(8, 92, 96, 0.10),
        rgba(155, 238, 229, 0.12)
    )

    static let lineStrong = dynamic(
        rgba(8, 92, 96, 0.18),
        rgba(155, 238, 229, 0.22)
    )

    static let highlight = dynamic(
        rgba(255, 255, 255, 0.88),
        rgba(255, 255, 255, 0.08)
    )

    static let chrome = dynamic(
        rgba(241, 249, 248, 0.96),
        rgba(5, 14, 19, 0.96)
    )

    static let composer = dynamic(
        rgba(255, 255, 255, 0.92),
        rgba(10, 29, 36, 0.92)
    )

    static let tabbar = dynamic(
        rgba(244, 251, 250, 0.94),
        rgba(7, 22, 28, 0.92)
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
