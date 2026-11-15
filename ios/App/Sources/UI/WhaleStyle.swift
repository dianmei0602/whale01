import SwiftUI
import UIKit

extension Font {
    /// Nomi uses compact product typography, but every text size still follows
    /// the user's Dynamic Type setting. Small captions are floored at 11.5pt.
    static func nomiScaled(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        let baseSize = max(11.5, size)
        let base = UIFont.systemFont(ofSize: baseSize, weight: weight.uiFontWeight)

        let resolved: UIFont
        if let descriptor = base.fontDescriptor.withDesign(design.uiFontDesign) {
            resolved = UIFont(descriptor: descriptor, size: baseSize)
        } else {
            resolved = base
        }

        let scaled = UIFontMetrics(forTextStyle: .body).scaledFont(for: resolved)
        // Keep large accessibility sizes usable inside dense app rows without
        // letting every icon and caption turn into display typography.
        let cap = max(18, baseSize * 1.65)
        if scaled.pointSize > cap {
            return Font(UIFont(descriptor: scaled.fontDescriptor, size: cap))
        }
        return Font(scaled)
    }
}

private extension Font.Weight {
    var uiFontWeight: UIFont.Weight {
        if self == .ultraLight { return .ultraLight }
        if self == .thin { return .thin }
        if self == .light { return .light }
        if self == .medium { return .medium }
        if self == .semibold { return .semibold }
        if self == .bold { return .bold }
        if self == .heavy { return .heavy }
        if self == .black { return .black }
        return .regular
    }
}

private extension Font.Design {
    var uiFontDesign: UIFontDescriptor.SystemDesign {
        if self == .serif { return .serif }
        if self == .rounded { return .rounded }
        if self == .monospaced { return .monospaced }
        return .default
    }
}

private struct NomiEdgeDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @GestureState private var dragOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: dragOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .global)
                    .updating($dragOffset) { value, state, _ in
                        guard value.startLocation.x <= 28,
                              value.translation.width > 0,
                              abs(value.translation.width) > abs(value.translation.height) * 1.25
                        else { return }
                        state = min(value.translation.width * 0.72, 150)
                    }
                    .onEnded { value in
                        guard value.startLocation.x <= 28,
                              value.translation.width > 92,
                              abs(value.translation.width) > abs(value.translation.height) * 1.35
                        else { return }
                        dismiss()
                    }
            )
    }
}

extension View {
    /// A single edge-back rule for full-screen Nomi detail pages.
    func nomiEdgeDismiss() -> some View {
        modifier(NomiEdgeDismissModifier())
    }
}

/// 深海极光的通用表面。参考稿里的卡片不是一块纯灰底，而是
/// 深色玻璃、顶部高光和极光染色的组合。
struct WhaleGlassCard<Content: View>: View {
    var radius: CGFloat = 22
    var padding: CGFloat = 16
    var tint: Color = CardPalette.accent
    let content: Content

    init(
        radius: CGFloat = 22,
        padding: CGFloat = 16,
        tint: Color = CardPalette.accent,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.padding = padding
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(CardPalette.surface)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(tint.opacity(0.035))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            }
    }
}

struct WhalePressStyle: ButtonStyle {
    var scale: CGFloat = 0.975

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.78),
                       value: configuration.isPressed)
    }
}

struct WhaleBrandLockup: View {
    var compact = false
    var onAvatarTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 9) {
            if let onAvatarTap {
                Button(action: onAvatarTap) {
                    Group {
                        if UIImage(named: "NomiHeaderBust") != nil {
                            Image("NomiHeaderBust")
                                .resizable()
                                .scaledToFit()
                        } else {
                            NomiAvatar(size: compact ? 30 : 34)
                        }
                    }
                    .frame(width: compact ? 34 : 40, height: compact ? 34 : 40)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(WhalePressStyle())
                .accessibilityLabel("打开 Nomi 设置")
            } else {
                Group {
                    if UIImage(named: "NomiHeaderBust") != nil {
                        Image("NomiHeaderBust")
                            .resizable()
                            .scaledToFit()
                    } else {
                        NomiAvatar(size: compact ? 30 : 34)
                    }
                }
                .frame(width: compact ? 34 : 40, height: compact ? 34 : 40)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Nomi")
                    .font(.nomiScaled(size: compact ? 18 : 20, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(CardPalette.ink)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct WhaleSectionTitle: View {
    let title: String
    var subtitle: String?
    var trailing: String?

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.nomiScaled(size: 18, weight: .bold))
                    .tracking(-0.35)
                    .foregroundStyle(CardPalette.ink)

                if let subtitle {
                    Text(subtitle)
                        .font(.nomiScaled(size: 11.5))
                        .foregroundStyle(CardPalette.subtle)
                }
            }

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.nomiScaled(size: 11.5, weight: .medium))
                    .foregroundStyle(CardPalette.subtle)
            }
        }
    }
}

struct WhalePill: View {
    let text: String
    var symbol: String?
    var color: Color = CardPalette.accent

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.nomiScaled(size: 9, weight: .bold))
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            }

            Text(text)
                .font(.nomiScaled(size: 10.5, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct WhaleIconTile: View {
    let symbol: String
    var color: Color = CardPalette.accent
    var size: CGFloat = 34

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
            .fill(color.opacity(0.13))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.43, weight: .semibold))
                    .foregroundStyle(color)
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                    .stroke(color.opacity(0.20), lineWidth: 1)
            }
    }
}

struct WhaleRowDivider: View {
    var leading: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(CardPalette.line)
            .frame(height: 0.6)
            .padding(.leading, leading)
    }
}
