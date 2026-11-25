import SwiftUI

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }
}

/// 语义 Token 门面。所有视图只认这里，不关心当前是哪套样式。
/// 每个属性都是计算属性：样式切换后全树重建时自动取到新值；
/// 颜色本身由 Color(light:dark:) 生成，系统深浅切换时自动更新。
enum WhaleTheme {
    private static var palette: WhalePalette { ThemeManager.shared.palette }

    static var accent: Color { palette.color(\.accent) }
    static var accentDeep: Color { palette.color(\.accentDeep) }
    static var accentSoft: Color { palette.color(\.accentSoft) }
    static var moon: Color { palette.color(\.moon) }
    static var coral: Color { palette.color(\.coral) }
    static var ink: Color { palette.color(\.ink) }
    static var muted: Color { palette.color(\.muted) }
    static var background: Color { palette.color(\.background) }
    static var card: Color { palette.color(\.card) }
    static var cardSolid: Color { palette.color(\.cardSolid) }
    static var soft: Color { palette.color(\.soft) }
    static var line: Color { palette.color(\.line) }
    static var field: Color { palette.color(\.field) }
    static var chrome: Color { palette.color(\.chrome) }
    static var onAccent: Color { palette.color(\.onAccent) }
    static var buttonInk: Color { palette.color(\.buttonInk) }
    static var warm: Color { palette.color(\.warm) }
    static var success: Color { palette.color(\.success) }
    static var danger: Color { palette.color(\.danger) }
    static var rose: Color { palette.color(\.rose) }
    static var blueSoft: Color { palette.color(\.blueSoft) }
    static var amberSoft: Color { palette.color(\.amberSoft) }
    static var roseSoft: Color { palette.color(\.roseSoft) }
    static var bubble: Color { palette.color(\.bubble) }
    static var glassStroke: Color { palette.glassStroke }

    static var cardRadius: CGFloat { palette.radiusCard }
    static var controlRadius: CGFloat { palette.radiusControl }
    static var pagePadding: CGFloat { palette.pagePadding }

    /// 扁平风格为 0，因此不会出现阴影；有质感风格加深阴影。
    static var shadowOpacity: Double { palette.shadowOpacity }
    static var accentShadowOpacity: Double { palette.accentShadowOpacity }
    static var shadowDarkMultiplier: Double { palette.shadowDarkMultiplier }
    /// 扁平风格用实心色块，其余风格保留系统材质。
    static var usesMaterial: Bool { palette.usesMaterial }
    /// 有质感风格标题/金句走衬线，其余走系统默认。
    static var displayDesign: Font.Design { palette.displayDesign }
    static var quoteWeight: Font.Weight { palette.quoteWeight }

    static var pageGradient: LinearGradient { palette.gradient(.page) }
    static var heroGradient: LinearGradient { palette.gradient(.hero) }
    static var auroraGradient: LinearGradient {
        switch ThemeManager.shared.style {
        case .abyss:
            return LinearGradient(colors: [accent, moon], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .flat:
            return palette.gradient(.composer)
        case .premium:
            return palette.gradient(.hero)
        }
    }
    static var gameGradient: LinearGradient { palette.gradient(.game) }
    static var musicGradient: LinearGradient { palette.gradient(.music) }
    static var headlineGradient: LinearGradient { palette.gradient(.headline) }
    static var weiboGradient: LinearGradient { palette.gradient(.weibo) }
    static var composerSendGradient: LinearGradient { palette.gradient(.composer) }
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

extension DiscoverChannel {
    var entryGradient: LinearGradient {
        ThemeManager.shared.palette.channelGradient(self)
    }
    var entryInk: Color {
        ThemeManager.shared.palette.channelInk(self)
    }
}

private struct ChannelLabelStyle: ViewModifier {
    let channel: DiscoverChannel
    let selected: Bool
    func body(content: Content) -> some View {
        content.foregroundStyle(selected ? Color.white : channel.entryInk)
            .padding(.horizontal, 10).frame(minHeight: 44)
            .fixedSize(horizontal: true, vertical: false)
            .background {
                let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                if selected {
                    shape.fill(channel.entryGradient)
                    if WhaleTheme.usesMaterial { shape.fill(.black.opacity(0.30)) }
                } else {
                    shape.fill(WhaleTheme.cardSolid).overlay(shape.fill(channel.entryInk.opacity(0.10)))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.8))
            .whaleSoftElevation(selected: selected)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SoftElevation: ViewModifier {
    let selected: Bool
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let k = scheme == .dark ? WhaleTheme.shadowDarkMultiplier : 1
        content
            .shadow(color: .black.opacity(WhaleTheme.shadowOpacity * k),
                    radius: selected ? 10 : 8, x: 0, y: 4)
            .shadow(color: WhaleTheme.accent.opacity(WhaleTheme.accentShadowOpacity * k * (selected ? 2.2 : 1)),
                    radius: selected ? 16 : 12, x: 0, y: 7)
    }
}

private struct RaisedPillStyle: ViewModifier {
    let selected: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        content.foregroundStyle(selected ? WhaleTheme.onAccent : WhaleTheme.ink)
            .padding(.horizontal, 10).frame(minHeight: 44).fixedSize(horizontal: true, vertical: false)
            .background {
                if selected { Capsule().fill(WhaleTheme.composerSendGradient) }
                else if reduceTransparency || !WhaleTheme.usesMaterial { Capsule().fill(WhaleTheme.cardSolid) }
                else {
                    Capsule().fill(.ultraThinMaterial)
                        .overlay(Capsule().fill(WhaleTheme.card.opacity(0.6)))
                }
            }
            .overlay(Capsule().strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.8))
            .whaleSoftElevation(selected: selected)
            .contentShape(Capsule())
    }
}

struct GlassCardStyle: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = WhaleTheme.cardRadius
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                if reduceTransparency || !WhaleTheme.usesMaterial {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(WhaleTheme.card)
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(WhaleTheme.card.opacity(0.62)))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.8)
            }
            .whaleSoftElevation()
    }
}

/// Full-page atmosphere. The aurora stays behind content, so every card keeps
/// a dark-to-mint edge and the header/footer can use opaque chrome.
struct WhaleBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            WhaleTheme.pageGradient
            if ThemeManager.shared.style == .abyss {
                Circle().fill(WhaleTheme.accent.opacity(colorScheme == .dark ? 0.18 : 0.20))
                    .frame(width: 360, height: 360).blur(radius: 82).offset(x: -150, y: -300)
                Circle().fill(WhaleTheme.moon.opacity(colorScheme == .dark ? 0.13 : 0.12))
                    .frame(width: 320, height: 320).blur(radius: 92).offset(x: 168, y: -150)
                Ellipse().fill(WhaleTheme.accentDeep.opacity(colorScheme == .dark ? 0.13 : 0.08))
                    .frame(width: 420, height: 240).blur(radius: 110).offset(x: 80, y: 360)
            }
        }
        .drawingGroup(opaque: false, colorMode: .nonLinear)
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
                    Circle().fill(WhaleTheme.usesMaterial ? WhaleTheme.auroraGradient : WhaleTheme.composerSendGradient)
                    Image(systemName: "fish.fill")
                        .font(.system(size: size * 0.44, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.8)
        }
        .shadow(
            color: WhaleTheme.accent.opacity(WhaleTheme.accentShadowOpacity),
            radius: 10,
            y: 4
        )
        .accessibilityHidden(true)
    }
}

struct WhaleChromeBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if !reduceTransparency && WhaleTheme.usesMaterial { Rectangle().fill(.ultraThinMaterial) }
            Rectangle().fill(WhaleTheme.chrome.opacity(reduceTransparency || !WhaleTheme.usesMaterial ? 1 : 0.82))
        }
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
                .whaleFont(size: 17, weight: .semibold, design: WhaleTheme.displayDesign)
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                if reduceTransparency || !WhaleTheme.usesMaterial {
                    Capsule().fill(WhaleTheme.cardSolid)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .overlay {
                Capsule().strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.8)
            }
            .whaleSoftElevation()
    }
}

private struct GlassCircleStyle: ViewModifier {
    let size: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .background {
                if reduceTransparency || !WhaleTheme.usesMaterial {
                    Circle().fill(WhaleTheme.cardSolid)
                } else {
                    Circle().fill(.ultraThinMaterial)
                }
            }
            .overlay {
                Circle().strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.8)
            }
            .whaleSoftElevation()
    }
}

extension View {
    func whaleChip() -> some View {
        modifier(GlassChipStyle())
    }

    func whaleGlassCircle(size: CGFloat = 44) -> some View {
        modifier(GlassCircleStyle(size: size))
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
