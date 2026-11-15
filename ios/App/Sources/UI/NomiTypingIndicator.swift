import SwiftUI

/// Nomi 正在组织回答时的轻量反馈。
///
/// 三个点只表达“它在想”，不模拟聊天机器人常见的整块骨架屏。
struct NomiTypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            NomiAvatar(size: 28, expression: .think)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(CardPalette.accent)
                        .frame(width: 5, height: 5)
                        .scaleEffect(animating ? 1 : 0.55)
                        .opacity(animating ? 1 : 0.42)
                        .animation(
                            reduceMotion
                                ? nil
                                : Animation.easeInOut(duration: 0.52)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.12),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(CardPalette.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(CardPalette.line, lineWidth: 1))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nomi 正在想")
        .onAppear {
            animating = true
        }
    }
}
