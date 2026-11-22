import SwiftUI
import UIKit

@MainActor
enum WhaleSystemChrome {
    static func apply(_ palette: WhalePaletteStyle) {
        let chrome = UIColor(WhalePaletteResolver.color(.chrome, style: palette))
        let line = UIColor(WhalePaletteResolver.color(.line, style: palette))
        let ink = UIColor(WhalePaletteResolver.color(.ink, style: palette))

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = chrome
        tab.shadowColor = line
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = chrome
        navigation.shadowColor = line
        navigation.titleTextAttributes = [.foregroundColor: ink]
        navigation.largeTitleTextAttributes = [.foregroundColor: ink]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
    }
}

enum WhaleTheme {
    static var accent: Color { WhalePaletteResolver.color(.accent) }
    static var accentDeep: Color { WhalePaletteResolver.color(.accentDeep) }
    static var accentSoft: Color { WhalePaletteResolver.color(.accentSoft) }
    static var moon: Color { WhalePaletteResolver.color(.moon) }
    static var coral: Color { WhalePaletteResolver.color(.coral) }
    static var ink: Color { WhalePaletteResolver.color(.ink) }
    static var muted: Color { WhalePaletteResolver.color(.muted) }
    static var background: Color { WhalePaletteResolver.color(.background) }
    static var card: Color { WhalePaletteResolver.color(.card) }
    static var cardSolid: Color { WhalePaletteResolver.color(.cardSolid) }
    static var soft: Color { WhalePaletteResolver.color(.soft) }
    static var line: Color { WhalePaletteResolver.color(.line) }
    static var field: Color { WhalePaletteResolver.color(.field) }
    static var chrome: Color { WhalePaletteResolver.color(.chrome) }
    static var onAccent: Color { WhalePaletteResolver.color(.onAccent) }
    static var buttonInk: Color { WhalePaletteResolver.color(.buttonInk) }
    static var glassStroke: Color { WhalePaletteResolver.color(.glassStroke) }
    static var warm: Color { WhalePaletteResolver.color(.warm) }
    static var success: Color { WhalePaletteResolver.color(.success) }
    static var danger: Color { WhalePaletteResolver.color(.danger) }

    static var categoryBlue: Color { WhalePaletteResolver.color(.categoryBlue) }
    static var categorySteel: Color { WhalePaletteResolver.color(.categorySteel) }
    static var categorySand: Color { WhalePaletteResolver.color(.categorySand) }
    static var categoryRose: Color { WhalePaletteResolver.color(.categoryRose) }
    static var categoryMist: Color { WhalePaletteResolver.color(.categoryMist) }
    static var categoryStraw: Color { WhalePaletteResolver.color(.categoryStraw) }
    static var categoryBlueInk: Color { WhalePaletteResolver.color(.categoryBlueInk) }
    static var categorySteelInk: Color { WhalePaletteResolver.color(.categorySteelInk) }
    static var categorySandInk: Color { WhalePaletteResolver.color(.categorySandInk) }
    static var categoryRoseInk: Color { WhalePaletteResolver.color(.categoryRoseInk) }
    static var categoryMistInk: Color { WhalePaletteResolver.color(.categoryMistInk) }
    static var categoryStrawInk: Color { WhalePaletteResolver.color(.categoryStrawInk) }

    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12
    static let pagePadding: CGFloat = 16

    static var pageGradient: LinearGradient {
        LinearGradient(colors: [background, background, background], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [accent, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var auroraGradient: LinearGradient {
        LinearGradient(colors: [accent, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var gameGradient: LinearGradient {
        LinearGradient(colors: [categorySandInk, categorySandInk], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var musicGradient: LinearGradient {
        LinearGradient(colors: [categoryRoseInk, categoryRoseInk], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var headlineGradient: LinearGradient {
        LinearGradient(colors: [categoryMistInk, categoryMistInk], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var weiboGradient: LinearGradient {
        LinearGradient(colors: [categoryRoseInk, categoryRoseInk], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var composerSendGradient: LinearGradient {
        LinearGradient(colors: [accent, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var rose: Color { categoryRoseInk }
    static var blueSoft: Color { accentSoft }
    static var amberSoft: Color { categorySand }
    static var roseSoft: Color { categoryRose }
    static var bubble: Color { card }
}

extension View {
    func whaleChannelLabel(_ channel: DiscoverChannel, selected: Bool) -> some View {
        modifier(ChannelLabelStyle(channel: channel, selected: selected))
    }
    func whaleCard(padding: CGFloat = 16) -> some View {
        self
            .modifier(GlassCardStyle(padding: padding))
    }

    func whalePrimaryButton() -> some View {
        self
            .font(.headline)
            .foregroundStyle(WhaleTheme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(
                WhaleTheme.composerSendGradient,
                in: RoundedRectangle(cornerRadius: WhaleTheme.controlRadius, style: .continuous)
            )
            .whaleSoftElevation()
    }

    func whaleSoftElevation(selected: Bool = false) -> some View {
        modifier(SoftElevation(selected: selected))
    }

    func whaleRaisedPill(selected: Bool) -> some View {
        modifier(RaisedPillStyle(selected: selected))
    }
}

struct WhalePressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.945 : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? 1.2 : 0)
            .brightness(configuration.isPressed ? -0.035 : 0)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.20, dampingFraction: 0.70),
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == WhalePressButtonStyle {
    static var whalePress: WhalePressButtonStyle { WhalePressButtonStyle() }
}

extension DiscoverChannel {
    var entryGradient: LinearGradient {
        switch self {
        case .ai: return WhaleTheme.heroGradient
        case .market: return LinearGradient(colors: [WhaleTheme.categorySteelInk, WhaleTheme.categorySteelInk], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .game: return WhaleTheme.gameGradient
        case .music: return WhaleTheme.musicGradient
        case .headline: return WhaleTheme.headlineGradient
        case .weibo: return WhaleTheme.weiboGradient
        }
    }
    var entryInk: Color {
        switch self {
        case .ai: return WhaleTheme.categoryBlueInk
        case .market: return WhaleTheme.categorySteelInk
        case .game: return WhaleTheme.categorySandInk
        case .music: return WhaleTheme.categoryRoseInk
        case .headline: return WhaleTheme.categoryMistInk
        case .weibo: return WhaleTheme.categoryRoseInk
        }
    }
    var homeCardBackground: Color {
        switch self {
        case .ai: return WhaleTheme.categoryBlue
        case .market: return WhaleTheme.categorySteel
        case .game: return WhaleTheme.categorySand
        case .music: return WhaleTheme.categoryRose
        case .headline: return WhaleTheme.categoryMist
        case .weibo: return WhaleTheme.categoryStraw
        }
    }
}

private struct ChannelLabelStyle: ViewModifier {
    let channel: DiscoverChannel
    let selected: Bool
    func body(content: Content) -> some View {
        content.foregroundStyle(selected ? WhaleTheme.onAccent : channel.entryInk)
            .padding(.horizontal, 10).frame(minHeight: 44)
            .fixedSize(horizontal: true, vertical: false)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? WhaleTheme.accent : channel.homeCardBackground)
            }
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WhaleTheme.line, lineWidth: 0.65))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SoftElevation: ViewModifier {
    let selected: Bool
    func body(content: Content) -> some View {
        content
    }
}

private struct RaisedPillStyle: ViewModifier {
    let selected: Bool
    func body(content: Content) -> some View {
        content.foregroundStyle(selected ? WhaleTheme.onAccent : WhaleTheme.ink)
            .padding(.horizontal, 10).frame(minHeight: 44).fixedSize(horizontal: true, vertical: false)
            .background {
                Capsule().fill(selected ? WhaleTheme.accent : WhaleTheme.cardSolid)
            }
            .overlay(Capsule().strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.8))
            .contentShape(Capsule())
    }
}

struct GlassCardStyle: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = WhaleTheme.cardRadius
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(WhaleTheme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(WhaleTheme.line, lineWidth: 0.65)
            }
    }
}

struct WhaleBackdrop: View {
    var body: some View {
        WhaleTheme.background
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct WhaleMarkView: View {
    var size: CGFloat = 38

    private static let logoImage: UIImage? = {
        if let image = UIImage(named: "WhaleLogo") { return image }
        if let url = Bundle.main.url(forResource: "WhaleLogo", withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        return nil
    }()

    var body: some View {
        Group {
            if let logo = Self.logoImage {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(WhaleTheme.auroraGradient)
                    Image(systemName: "fish.fill")
                        .font(.system(size: size * 0.44, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.8)
        }
        .accessibilityHidden(true)
    }
}

struct WhaleChromeBackground: View {
    var body: some View {
        Rectangle().fill(WhaleTheme.chrome)
    }
}

// GLASS 是设计方向（层次、半透明、hairline），不是 CSS blur 的像素级复刻。
// 原生统一走系统 Material；Liquid Glass 是 iOS 26 SDK 的新 API，本工程
// 以 iOS 17 为基线且 CI 使用旧 SDK，不能假装已接入。

struct WhaleStatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color)
    }
}

struct WhaleSectionTitle: View {
    let title: String
    var action: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .whaleFont(size: 17, weight: .semibold)
                .foregroundStyle(WhaleTheme.ink)
            Spacer()
            if let action, let onAction {
                Button(action, action: onAction)
                    .font(.subheadline.weight(.medium))
                    .tint(WhaleTheme.accent)
            }
        }
    }
}

struct WhaleIconTile: View {
    let systemName: String
    var size: CGFloat = 44
    var tint: Color = WhaleTheme.accent

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

struct GlassChipStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(WhaleTheme.cardSolid, in: Capsule())
            .overlay {
                Capsule().strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.8)
            }
    }
}

extension View {
    func whaleChip() -> some View {
        modifier(GlassChipStyle())
    }

    func whaleGlassCircle(size: CGFloat = 44) -> some View {
        self
            .frame(width: size, height: size)
            .background(WhaleTheme.cardSolid, in: Circle())
            .overlay {
                Circle().strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.8)
            }
    }
}

/// Wraps chips onto as many lines as needed without a horizontal scroll view,
/// so the root pager keeps exclusive ownership of horizontal drags.
struct WhaleFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                widest = max(widest, x - spacing)
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        widest = max(widest, max(0, x - spacing))
        return CGSize(width: proposal.width ?? widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
