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

enum WhaleTheme {
    // Sea-salt blue: a calm, neutral assistant surface with one blue accent.
    // Semantic green and red remain reserved for real status.
    static let accent = Color(light: 0x246F95, dark: 0x72BBDA)
    static let accentDeep = Color(light: 0x1C5C7B, dark: 0x5EA6C6)
    static let accentSoft = Color(light: 0xDCEFF6, dark: 0x203A47)
    static let moon = Color(light: 0x5F83A1, dark: 0x9BB9CA)
    static let coral = Color(light: 0xA75F36, dark: 0xE0A471)
    static let ink = Color(light: 0x17262E, dark: 0xF1F6F8)
    static let muted = Color(light: 0x596C76, dark: 0xB4C1C7)
    static let background = Color(light: 0xF3F7F9, dark: 0x101619)
    static let card = Color(light: 0xFFFFFF, dark: 0x182126)
    static let cardSolid = Color(light: 0xE8F0F5, dark: 0x202D33)
    static let soft = Color(light: 0xE8F0F5, dark: 0x202D33)
    static let line = Color(light: 0xD6E2E8, dark: 0x34464D)
    static let field = Color(light: 0xF8FAFB, dark: 0x182126)
    static let chrome = Color(light: 0xFBFCFD, dark: 0x141D21)
    static let onAccent = Color(light: 0xF7FCFD, dark: 0x10232C)
    static let buttonInk = Color(light: 0xF7FCFD, dark: 0x10232C)
    static let glassStroke = Color(light: 0xD6E2E8, dark: 0x34464D)
    static let warm = Color(light: 0x96602C, dark: 0xE0AC6C)
    static let success = Color(light: 0x247B50, dark: 0x63C99B)
    static let danger = Color(light: 0xB8444C, dark: 0xEF858C)

    static let categoryBlue = Color(light: 0xE1F0F6, dark: 0x17343F)
    static let categorySteel = Color(light: 0xE4EBF3, dark: 0x1C2D3B)
    static let categorySand = Color(light: 0xF4EADB, dark: 0x352A1D)
    static let categoryRose = Color(light: 0xF4E6EA, dark: 0x35232A)
    static let categoryMist = Color(light: 0xE7EEF1, dark: 0x223138)
    static let categoryStraw = Color(light: 0xF1ECE1, dark: 0x302B20)
    static let categoryBlueInk = Color(light: 0x145B74, dark: 0xA5D9E9)
    static let categorySteelInk = Color(light: 0x365A76, dark: 0xADD0E4)
    static let categorySandInk = Color(light: 0x80531F, dark: 0xE5BE83)
    static let categoryRoseInk = Color(light: 0x814959, dark: 0xE3A9BA)
    static let categoryMistInk = Color(light: 0x3F5D6A, dark: 0xBAD2DC)
    static let categoryStrawInk = Color(light: 0x725C2D, dark: 0xD9C88F)

    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12
    static let pagePadding: CGFloat = 16

    static let pageGradient = LinearGradient(
        colors: [background, background, background],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [accent, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let auroraGradient = LinearGradient(
        colors: [accent, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gameGradient = LinearGradient(
        colors: [categorySandInk, categorySandInk],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let musicGradient = LinearGradient(
        colors: [categoryRoseInk, categoryRoseInk],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let headlineGradient = LinearGradient(
        colors: [categoryMistInk, categoryMistInk],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let weiboGradient = LinearGradient(
        colors: [Color(light: 0x8A5551, dark: 0xA56E69), Color(light: 0x8A5551, dark: 0xA56E69)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let composerSendGradient = LinearGradient(
        colors: [accent, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let rose = categoryRoseInk
    static let blueSoft = accentSoft
    static let amberSoft = categorySand
    static let roseSoft = categoryRose
    static let bubble = card
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
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.78),
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
        case .weibo: return Color(light: 0x7E4B47, dark: 0xE0B0AA)
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
