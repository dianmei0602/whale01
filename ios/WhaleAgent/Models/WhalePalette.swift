import SwiftUI
import UIKit

enum WhalePaletteStyle: String, CaseIterable, Identifiable {
    case seaSalt
    case nightSea
    case gilded

    static let storageKey = "whale.palette"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seaSalt: return "海盐"
        case .nightSea: return "夜海"
        case .gilded: return "鎏金"
        }
    }

    var subtitle: String {
        switch self {
        case .seaSalt: return "蓝 · 暖棕"
        case .nightSea: return "夜海 · 沙漠红"
        case .gilded: return "亮金 · 碧城"
        }
    }

    var previewColors: [Color] {
        switch self {
        case .seaSalt:
            return [
                Color(hex: 0x246F95),
                Color(hex: 0xDCEFF6),
                Color(hex: 0xA75F36),
                Color(hex: 0xF3F7F9)
            ]
        case .nightSea:
            return [
                Color(hex: 0x0E4258),
                Color(hex: 0x992E34),
                Color(hex: 0xF9F6E5),
                Color(hex: 0x17100F)
            ]
        case .gilded:
            return [
                Color(hex: 0xFBDC92),
                Color(hex: 0x944523),
                Color(hex: 0x0D4D76),
                Color(hex: 0x0A0907)
            ]
        }
    }

    static var current: WhalePaletteStyle {
        WhalePaletteStyle(
            rawValue: UserDefaults.standard.string(forKey: storageKey) ?? ""
        ) ?? .seaSalt
    }
}

private struct WhalePaletteEnvironmentKey: EnvironmentKey {
    static let defaultValue = WhalePaletteStyle.seaSalt
}

extension EnvironmentValues {
    var whalePaletteStyle: WhalePaletteStyle {
        get { self[WhalePaletteEnvironmentKey.self] }
        set { self[WhalePaletteEnvironmentKey.self] = newValue }
    }
}

enum WhalePaletteToken: CaseIterable {
    case accent
    case accentDeep
    case accentSoft
    case moon
    case coral
    case ink
    case muted
    case background
    case card
    case cardSolid
    case soft
    case line
    case field
    case chrome
    case onAccent
    case buttonInk
    case glassStroke
    case warm
    case success
    case danger
    case categoryBlue
    case categorySteel
    case categorySand
    case categoryRose
    case categoryMist
    case categoryStraw
    case categoryBlueInk
    case categorySteelInk
    case categorySandInk
    case categoryRoseInk
    case categoryMistInk
    case categoryStrawInk
}

enum WhalePaletteResolver {
    static func color(_ token: WhalePaletteToken) -> Color {
        Color(uiColor: UIColor { traits in
            let style = WhalePaletteStyle.current
            let values = traits.userInterfaceStyle == .dark
                ? darkValues(style)
                : lightValues(style)
            return UIColor(hex: values[token] ?? fallbackValues[token] ?? 0x000000)
        })
    }

    static func lightValues(_ style: WhalePaletteStyle) -> [WhalePaletteToken: UInt32] {
        switch style {
        case .seaSalt: return seaSaltLight
        case .nightSea: return nightSeaLight
        case .gilded: return gildedLight
        }
    }

    static func darkValues(_ style: WhalePaletteStyle) -> [WhalePaletteToken: UInt32] {
        switch style {
        case .seaSalt: return seaSaltDark
        case .nightSea: return nightSeaDark
        case .gilded: return gildedDark
        }
    }

    private static let fallbackValues: [WhalePaletteToken: UInt32] = seaSaltLight

    private static let seaSaltLight: [WhalePaletteToken: UInt32] = [
        .accent: 0x246F95, .accentDeep: 0x1C5C7B, .accentSoft: 0xDCEFF6,
        .moon: 0x5F83A1, .coral: 0xA75F36, .ink: 0x17262E,
        .muted: 0x596C76, .background: 0xF3F7F9, .card: 0xFFFFFF,
        .cardSolid: 0xE8F0F5, .soft: 0xE8F0F5, .line: 0xD6E2E8,
        .field: 0xF8FAFB, .chrome: 0xFBFCFD, .onAccent: 0xF7FCFD,
        .buttonInk: 0xF7FCFD, .glassStroke: 0xD6E2E8, .warm: 0x96602C,
        .success: 0x247B50, .danger: 0xB8444C,
        .categoryBlue: 0xE1F0F6, .categorySteel: 0xE4EBF3,
        .categorySand: 0xF4EADB, .categoryRose: 0xF4E6EA,
        .categoryMist: 0xE7EEF1, .categoryStraw: 0xF1ECE1,
        .categoryBlueInk: 0x145B74, .categorySteelInk: 0x365A76,
        .categorySandInk: 0x80531F, .categoryRoseInk: 0x814959,
        .categoryMistInk: 0x3F5D6A, .categoryStrawInk: 0x725C2D
    ]

    private static let seaSaltDark: [WhalePaletteToken: UInt32] = [
        .accent: 0x72BBDA, .accentDeep: 0x5EA6C6, .accentSoft: 0x203A47,
        .moon: 0x9BB9CA, .coral: 0xE0A471, .ink: 0xF1F6F8,
        .muted: 0xB4C1C7, .background: 0x101619, .card: 0x182126,
        .cardSolid: 0x202D33, .soft: 0x202D33, .line: 0x34464D,
        .field: 0x182126, .chrome: 0x141D21, .onAccent: 0x10232C,
        .buttonInk: 0x10232C, .glassStroke: 0x34464D, .warm: 0xE0AC6C,
        .success: 0x63C99B, .danger: 0xEF858C,
        .categoryBlue: 0x17343F, .categorySteel: 0x1C2D3B,
        .categorySand: 0x352A1D, .categoryRose: 0x35232A,
        .categoryMist: 0x223138, .categoryStraw: 0x302B20,
        .categoryBlueInk: 0xA5D9E9, .categorySteelInk: 0xADD0E4,
        .categorySandInk: 0xE5BE83, .categoryRoseInk: 0xE3A9BA,
        .categoryMistInk: 0xBAD2DC, .categoryStrawInk: 0xD9C88F
    ]

    private static let nightSeaLight: [WhalePaletteToken: UInt32] = [
        .accent: 0x0E4258, .accentDeep: 0x992E34, .accentSoft: 0xEEE4D5,
        .moon: 0x61747B, .coral: 0x992E34, .ink: 0x111A1F,
        .muted: 0x586267, .background: 0xF9F6E5, .card: 0xFFFCF5,
        .cardSolid: 0xEDE5D7, .soft: 0xEDE5D7, .line: 0xD8CEBE,
        .field: 0xFFFAF0, .chrome: 0xF3EDE0, .onAccent: 0xF9F6E5,
        .buttonInk: 0xF9F6E5, .glassStroke: 0xD8CEBE, .warm: 0x7E552A,
        .success: 0x2D6947, .danger: 0x992E34,
        .categoryBlue: 0xE3EDF0, .categorySteel: 0xE6E9E5,
        .categorySand: 0xF1E3CF, .categoryRose: 0xF0DEDC,
        .categoryMist: 0xE8E8E0, .categoryStraw: 0xEDE5D2,
        .categoryBlueInk: 0x0E4258, .categorySteelInk: 0x445C65,
        .categorySandInk: 0x794C25, .categoryRoseInk: 0x8B3035,
        .categoryMistInk: 0x465B61, .categoryStrawInk: 0x66552F
    ]

    private static let nightSeaDark: [WhalePaletteToken: UInt32] = [
        .accent: 0x7CB7C9, .accentDeep: 0xE49391, .accentSoft: 0x26363B,
        .moon: 0xA2B5B8, .coral: 0xE38B8D, .ink: 0xF9F6E5,
        .muted: 0xC1C7C2, .background: 0x090C0E, .card: 0x111719,
        .cardSolid: 0x192126, .soft: 0x192126, .line: 0x303A3D,
        .field: 0x111719, .chrome: 0x0D1113, .onAccent: 0x0A2029,
        .buttonInk: 0x0A2029, .glassStroke: 0x303A3D, .warm: 0xE6B468,
        .success: 0x65C698, .danger: 0xEF858C,
        .categoryBlue: 0x132D37, .categorySteel: 0x19272C,
        .categorySand: 0x2E281F, .categoryRose: 0x332123,
        .categoryMist: 0x202B2E, .categoryStraw: 0x2B271E,
        .categoryBlueInk: 0xA7D2DE, .categorySteelInk: 0xB8CDD0,
        .categorySandInk: 0xE8C894, .categoryRoseInk: 0xE9A9AA,
        .categoryMistInk: 0xC7D6D6, .categoryStrawInk: 0xDCCB9A
    ]

    private static let gildedLight: [WhalePaletteToken: UInt32] = [
        .accent: 0x0D4D76, .accentDeep: 0x944523, .accentSoft: 0xFBDC92,
        .moon: 0x506C79, .coral: 0x944523, .ink: 0x1A1712,
        .muted: 0x625E54, .background: 0xF8F3E7, .card: 0xFFFBF2,
        .cardSolid: 0xF3E7CF, .soft: 0xF3E7CF, .line: 0xD9C9AB,
        .field: 0xFFF8EA, .chrome: 0xF5EDDB, .onAccent: 0xFFF3D4,
        .buttonInk: 0xFFF3D4, .glassStroke: 0xD9C9AB, .warm: 0x944523,
        .success: 0x2D6A4F, .danger: 0x944523,
        .categoryBlue: 0xE5EFF2, .categorySteel: 0xE8E9E3,
        .categorySand: 0xFAE8B9, .categoryRose: 0xF2DDD2,
        .categoryMist: 0xECE8DB, .categoryStraw: 0xF1E1BB,
        .categoryBlueInk: 0x0D4D76, .categorySteelInk: 0x465E67,
        .categorySandInk: 0x77521E, .categoryRoseInk: 0x944523,
        .categoryMistInk: 0x4D625F, .categoryStrawInk: 0x6E5626
    ]

    private static let gildedDark: [WhalePaletteToken: UInt32] = [
        .accent: 0xFBDC92, .accentDeep: 0x4F91B8, .accentSoft: 0x3A2F1A,
        .moon: 0x83A9B9, .coral: 0xD16E57, .ink: 0xFBDC92,
        .muted: 0xCFC7B6, .background: 0x090807, .card: 0x15120D,
        .cardSolid: 0x201B13, .soft: 0x201B13, .line: 0x423827,
        .field: 0x15120D, .chrome: 0x0D0C09, .onAccent: 0x1B1305,
        .buttonInk: 0x1B1305, .glassStroke: 0x423827, .warm: 0xE6B05B,
        .success: 0x71C99B, .danger: 0xE07E6A,
        .categoryBlue: 0x112D3D, .categorySteel: 0x1D292D,
        .categorySand: 0x332916, .categoryRose: 0x35221C,
        .categoryMist: 0x282820, .categoryStraw: 0x302712,
        .categoryBlueInk: 0x8FC9E6, .categorySteelInk: 0xB5D1DA,
        .categorySandInk: 0xFBDC92, .categoryRoseInk: 0xE6A18D,
        .categoryMistInk: 0xD2D7C5, .categoryStrawInk: 0xEFD58C
    ]
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
