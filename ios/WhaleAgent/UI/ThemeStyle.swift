import SwiftUI
import UIKit

extension Color {
    /// 设置页主题预览用的静态色（不随系统变化，专门展示该样式的浅/深两端）。
    init(hex: UInt32) {
        self.init(uiColor: UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        ))
    }
}

// MARK: - 主题样式（与深浅模式正交）
//
// 样式 = 扁平 / 有质感 / 深海；深浅 = 系统 colorScheme。
// 颜色的 light/dark 值写在同一处，由 Color(light:dark:) 生成动态色，
// 系统切换深浅时自动重绘，不需要重启 App 也不需要手动刷新。

enum WhaleThemeStyle: String, CaseIterable, Identifiable {
    case abyss = "abyss"
    case flat = "flat"
    case premium = "premium"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .abyss: return "深海"
        case .flat: return "扁平"
        case .premium: return "有质感"
        }
    }

    var subtitle: String {
        switch self {
        case .abyss: return "极光玻璃"
        case .flat: return "纯色分区"
        case .premium: return "香槟金"
        }
    }
}

// MARK: - 颜色集合（每个样式各一份浅色 / 深色）
//
// 用 KeyPath 取值，编译期保证 Token 不漏配；新增颜色只需在这里加字段，
// 并在三套 light/dark 初始化中补齐，编译器会直接报错。

struct WhaleColorSet {
    let accent: UInt32
    let accentDeep: UInt32
    let accentSoft: UInt32
    let moon: UInt32
    let coral: UInt32
    let ink: UInt32
    let muted: UInt32
    let background: UInt32
    let card: UInt32
    let cardSolid: UInt32
    let soft: UInt32
    let line: UInt32
    let field: UInt32
    let chrome: UInt32
    let onAccent: UInt32
    let buttonInk: UInt32
    let warm: UInt32
    let success: UInt32
    let danger: UInt32
    let rose: UInt32
    let blueSoft: UInt32
    let amberSoft: UInt32
    let roseSoft: UInt32
    let bubble: UInt32
}

enum WhaleGradientName: String {
    case page, hero, game, music, headline, weibo, composer
    case channelAI, channelMarket, channelGame, channelMusic, channelHeadline, channelWeibo
}

// MARK: - 一套样式的完整 Token

struct WhalePalette {
    let style: WhaleThemeStyle
    let light: WhaleColorSet
    let dark: WhaleColorSet

    let radiusCard: CGFloat
    let radiusControl: CGFloat
    let pagePadding: CGFloat
    let shadowOpacity: Double
    let accentShadowOpacity: Double
    let shadowDarkMultiplier: Double
    let usesMaterial: Bool
    let displayDesign: Font.Design
    let quoteWeight: Font.Weight
    let glassStrokeLightAlpha: Double
    let glassStrokeDarkAlpha: Double

    init(style: WhaleThemeStyle) {
        self.style = style
        switch style {
        case .abyss:
            light = Self.abyssLight
            dark = Self.abyssDark
            radiusCard = 20; radiusControl = 16; pagePadding = 20
            shadowOpacity = 0.075; accentShadowOpacity = 0.045; shadowDarkMultiplier = 3.2
            usesMaterial = true; displayDesign = .default; quoteWeight = .semibold
            glassStrokeLightAlpha = 0.72; glassStrokeDarkAlpha = 0.16
        case .flat:
            light = Self.flatLight
            dark = Self.flatDark
            radiusCard = 10; radiusControl = 10; pagePadding = 16
            shadowOpacity = 0; accentShadowOpacity = 0; shadowDarkMultiplier = 1
            usesMaterial = false; displayDesign = .default; quoteWeight = .bold
            glassStrokeLightAlpha = 1; glassStrokeDarkAlpha = 1
        case .premium:
            light = Self.premiumLight
            dark = Self.premiumDark
            radiusCard = 18; radiusControl = 14; pagePadding = 20
            shadowOpacity = 0.16; accentShadowOpacity = 0.10; shadowDarkMultiplier = 1.5
            usesMaterial = true; displayDesign = .serif; quoteWeight = .semibold
            glassStrokeLightAlpha = 0.9; glassStrokeDarkAlpha = 0.28
        }
    }

    // MARK: 动态色：系统深浅切换时由 UIColor 动态 provider 自动更新

    func color(_ key: KeyPath<WhaleColorSet, UInt32>) -> Color {
        Color(light: light[keyPath: key], dark: dark[keyPath: key])
    }

    var glassStroke: Color {
        if style == .flat { return color(\.line) }
        return Color(uiColor: UIColor { traits in
            let alpha = traits.userInterfaceStyle == .dark
                ? self.glassStrokeDarkAlpha : self.glassStrokeLightAlpha
            let base = traits.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
            return base.withAlphaComponent(alpha)
        })
    }

    // MARK: 渐变（扁平风格用同色双停，视觉上仍是纯色）

    func gradient(_ name: WhaleGradientName) -> LinearGradient {
        let pairs: [(UInt32, UInt32)] = Self.gradientPairs(style: style, name: name)
        return LinearGradient(
            colors: pairs.map { Color(light: $0.0, dark: $0.1) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func channelGradient(_ channel: DiscoverChannel) -> LinearGradient {
        switch channel {
        case .ai: return gradient(.channelAI)
        case .market: return gradient(.channelMarket)
        case .game: return gradient(.channelGame)
        case .music: return gradient(.channelMusic)
        case .headline: return gradient(.channelHeadline)
        case .weibo: return gradient(.channelWeibo)
        }
    }

    func channelInk(_ channel: DiscoverChannel) -> Color {
        switch style {
        case .abyss:
            switch channel {
            case .ai: return Color(light: 0x096D65, dark: 0x82EAD5)
            case .market: return Color(light: 0x225DA0, dark: 0x99C7FF)
            case .game: return Color(light: 0x8D421D, dark: 0xF9C183)
            case .music: return Color(light: 0x82447E, dark: 0xF0B5D8)
            case .headline: return Color(light: 0x216D91, dark: 0x8DD9F4)
            case .weibo: return Color(light: 0xAA3737, dark: 0xFFB1A2)
            }
        case .flat:
            return .white
        case .premium:
            return Color(light: 0x7A5A20, dark: 0xE8D6AE)
        }
    }

    // MARK: - 深海（沿用原工程全部色值，保证默认体验零变化）

    private static let abyssLight = WhaleColorSet(
        accent: 0x087C75, accentDeep: 0x0B756F, accentSoft: 0xDFF6F2,
        moon: 0x2E73C8, coral: 0xD77B3D, ink: 0x102522, muted: 0x53645F,
        background: 0xF2F8F7, card: 0xFFFFFF, cardSolid: 0xE7F1EE, soft: 0xE7F2EF,
        line: 0xD8E6E2, field: 0xEAF3F0, chrome: 0xF7FBFA, onAccent: 0x062521,
        buttonInk: 0x062521, warm: 0xC68136, success: 0x168F68, danger: 0xD34747,
        rose: 0xC0566F, blueSoft: 0xE6EFFC, amberSoft: 0xFBF0DC, roseSoft: 0xFBE8EC,
        bubble: 0xFFFFFF
    )
    private static let abyssDark = WhaleColorSet(
        accent: 0x62EAD6, accentDeep: 0x3CCFC4, accentSoft: 0x123B3D,
        moon: 0x78B9FF, coral: 0xFFB27A, ink: 0xF2F8F7, muted: 0xA6B9B6,
        background: 0x071311, card: 0x0D201E, cardSolid: 0x142C29, soft: 0x132724,
        line: 0x25403C, field: 0x0C1D1B, chrome: 0x091714, onAccent: 0x04211E,
        buttonInk: 0x04211E, warm: 0xF3BC77, success: 0x54DFAF, danger: 0xF07A7A,
        rose: 0xF292A6, blueSoft: 0x14283F, amberSoft: 0x33260E, roseSoft: 0x341A20,
        bubble: 0x102622
    )

    // MARK: - 扁平：纯色分区、零阴影、锐利圆角

    private static let flatLight = WhaleColorSet(
        accent: 0x245FCC, accentDeep: 0x1D4FA8, accentSoft: 0xE8F0FE,
        moon: 0x1F6FC7, coral: 0xC94A24, ink: 0x1B2838, muted: 0x53657B,
        background: 0xF7F9FC, card: 0xFFFFFF, cardSolid: 0xEEF3F9, soft: 0xEDF3FA,
        line: 0xDCE5F0, field: 0xF2F6FB, chrome: 0xFFFFFF, onAccent: 0xFFFFFF,
        buttonInk: 0xFFFFFF, warm: 0xA96515, success: 0x177A58, danger: 0xC03A46,
        rose: 0xA84469, blueSoft: 0xE7F0FD, amberSoft: 0xFDF2DC, roseSoft: 0xFDEBF0,
        bubble: 0xFFFFFF
    )
    private static let flatDark = WhaleColorSet(
        accent: 0x8CB8FF, accentDeep: 0x6FA0FF, accentSoft: 0x1B3052,
        moon: 0x8CC4FF, coral: 0xFF9D72, ink: 0xEAF0F7, muted: 0xA9BACB,
        background: 0x101720, card: 0x1B2532, cardSolid: 0x263245, soft: 0x1C2938,
        line: 0x33445A, field: 0x172130, chrome: 0x131C28, onAccent: 0x0B1A33,
        buttonInk: 0x0B1A33, warm: 0xF0B45E, success: 0x4FD0A0, danger: 0xFF8992,
        rose: 0xFFA8C2, blueSoft: 0x1B3052, amberSoft: 0x3A2E18, roseSoft: 0x3A1F2B,
        bubble: 0x1B2532
    )

    // MARK: - 有质感：深空底 + 香槟金、衬线标题、多层柔和阴影

    private static let premiumLight = WhaleColorSet(
        accent: 0x8A641F, accentDeep: 0x735018, accentSoft: 0xF6EEDC,
        moon: 0x6C5A9E, coral: 0xA85A36, ink: 0x2A211A, muted: 0x6B5A4A,
        background: 0xFAF6EF, card: 0xFFFFFF, cardSolid: 0xF5EEE1, soft: 0xF3ECDF,
        line: 0xE5D9C5, field: 0xF8F3EA, chrome: 0xFCF8F1, onAccent: 0xFFFFFF,
        buttonInk: 0x2A211A, warm: 0x9A6A20, success: 0x2E7D5B, danger: 0xB23A3A,
        rose: 0xA34F68, blueSoft: 0xE9ECF6, amberSoft: 0xF7EBD4, roseSoft: 0xF6E6E8,
        bubble: 0xFFFFFF
    )
    private static let premiumDark = WhaleColorSet(
        accent: 0xD9B778, accentDeep: 0xC9A662, accentSoft: 0x302A1E,
        moon: 0xB9A8E6, coral: 0xE79A72, ink: 0xF5F1E8, muted: 0xBCB5A6,
        background: 0x0C0C0E, card: 0x1A1A1F, cardSolid: 0x232329, soft: 0x221F1A,
        line: 0x3A3429, field: 0x15151A, chrome: 0x101013, onAccent: 0x1A1408,
        buttonInk: 0xF5F1E8, warm: 0xD9B778, success: 0x7FD3A8, danger: 0xE88A8A,
        rose: 0xE5A0B6, blueSoft: 0x20243A, amberSoft: 0x33280F, roseSoft: 0x33202A,
        bubble: 0x1A1A1F
    )

    // MARK: - 渐变配置

    private static func gradientPairs(style: WhaleThemeStyle, name: WhaleGradientName) -> [(UInt32, UInt32)] {
        switch style {
        case .abyss:
            switch name {
            case .page: return [(0xE8F5F2, 0x06110F), (0xEDF7F7, 0x0A1A19), (0xF8FBF7, 0x0B1714)]
            case .hero: return [(0x139C91, 0x0B4647), (0x1D777C, 0x103338), (0x315D74, 0x0B2028)]
            case .game: return [(0xB85C2E, 0x6B2C12), (0xD79A3F, 0x4A3510)]
            case .music: return [(0x8A4B8F, 0x3A1E45), (0xC0566F, 0x5A2436)]
            case .headline: return [(0x1E8A7A, 0x0C4A42), (0x2E73C8, 0x143352)]
            case .weibo: return [(0xD34747, 0x5A1A1A), (0xD77B3D, 0x5B3216)]
            case .composer: return [(0x3FCDBE, 0x2FBFB2), (0x4E9BE8, 0x4E9BE8)]
            case .channelAI: return [(0x139C91, 0x0B4647), (0x1D777C, 0x103338)]
            case .channelMarket: return [(0x2E73C8, 0x326DA6), (0x0B756F, 0x267E74)]
            case .channelGame: return [(0xB85C2E, 0x6B2C12), (0xD79A3F, 0x4A3510)]
            case .channelMusic: return [(0x8A4B8F, 0x3A1E45), (0xC0566F, 0x5A2436)]
            case .channelHeadline: return [(0x1E8A7A, 0x0C4A42), (0x2E73C8, 0x143352)]
            case .channelWeibo: return [(0xD34747, 0x5A1A1A), (0xD77B3D, 0x5B3216)]
            }
        case .flat:
            let page = [(0xF7F9FC, 0x101720), (0xF7F9FC, 0x101720), (0xF0F4FA, 0x0D141C)]
            switch name {
            case .page: return page
            case .hero, .channelAI: return [(0x2D6CDF, 0x4C86FF), (0x2D6CDF, 0x4C86FF)]
            case .channelMarket: return [(0x1F7AE0, 0x6FA8FF), (0x1F7AE0, 0x6FA8FF)]
            case .game, .channelGame: return [(0xE4572E, 0xFF9C72), (0xE4572E, 0xFF9C72)]
            case .music, .channelMusic: return [(0x8B4FC9, 0xB98BFF), (0x8B4FC9, 0xB98BFF)]
            case .headline, .channelHeadline: return [(0x0E9F8A, 0x3FD6BE), (0x0E9F8A, 0x3FD6BE)]
            case .weibo, .channelWeibo: return [(0xD23A4E, 0xFF7F91), (0xD23A4E, 0xFF7F91)]
            case .composer: return [(0x245FCC, 0x8CB8FF), (0x245FCC, 0x8CB8FF)]
            }
        case .premium:
            switch name {
            case .page: return [(0xFAF6EF, 0x0C0C0E), (0xF7F1E8, 0x121215), (0xF2EADC, 0x17171B)]
            case .hero, .channelAI: return [(0x8A641F, 0x5A4A28), (0xB08A3E, 0x816637)]
            case .channelMarket: return [(0x4A4468, 0x35304B), (0x6B6288, 0x4A4460)]
            case .game, .channelGame: return [(0x8C4028, 0x5A2C1C), (0xA9623D, 0x704126)]
            case .music, .channelMusic: return [(0x6C4A63, 0x45303F), (0x926982, 0x5B4053)]
            case .headline, .channelHeadline: return [(0x3F5A4F, 0x283A33), (0x5E7B6A, 0x3A5246)]
            case .weibo, .channelWeibo: return [(0x8A3A3A, 0x5A2424), (0xA65A4A, 0x71352E)]
            case .composer: return [(0x8A641F, 0xC9A662), (0xA88438, 0xD9B778)]
            }
        }
    }
}

// MARK: - 主题状态（持久化 + 通知界面重绘）

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let storeKey = "whale.theme.style.v1"

    @Published var style: WhaleThemeStyle {
        didSet {
            UserDefaults.standard.set(style.rawValue, forKey: Self.storeKey)
            applyTabBarAppearance()
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storeKey) ?? ""
        style = WhaleThemeStyle(rawValue: raw) ?? .abyss
    }

    var palette: WhalePalette { WhalePalette(style: style) }

    /// TabBar 是 UIKit 单例，SwiftUI 重绘不会更新它，样式切换时必须显式刷新。
    func applyTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(WhaleTheme.chrome)
        appearance.shadowColor = UIColor(WhaleTheme.line.opacity(0.7))
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
