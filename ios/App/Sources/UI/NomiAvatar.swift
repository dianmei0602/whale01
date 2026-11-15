import SwiftUI

/// Nomi 的小头像。
///
/// 只用于顶栏、输入栏、聊天气泡和设置页这类小尺寸场景：
/// 黑色大圆角底，中间两只发光眼睛。
/// 首页和对话里的完整钛合金角色仍由 `PetCharacterView` 绘制。
struct NomiAvatar: View {
    var size: CGFloat = 32
    var expression: PetExpression = .calm

    private var radius: CGFloat { size * 0.28 }
    private var eyeWidth: CGFloat { max(2, size * 0.105) }
    private var eyeHeight: CGFloat { max(2.5, size * 0.32 * expression.eyeOpen) }
    private var gap: CGFloat { size * 0.115 }
    private let eyeColor = EyePalette.default

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color(red: 0.012, green: 0.018, blue: 0.024))
            .frame(width: size, height: size)
            .overlay(
                GeometryReader { proxy in
                    HStack(spacing: gap) {
                        Capsule()
                            .fill(eyeColor)
                            .frame(width: eyeWidth, height: eyeHeight)
                            .shadow(color: eyeColor.opacity(0.58), radius: size * 0.075)
                        Capsule()
                            .fill(eyeColor)
                            .frame(width: eyeWidth, height: eyeHeight)
                            .shadow(color: eyeColor.opacity(0.58), radius: size * 0.075)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .accessibilityHidden(true)
    }
}
