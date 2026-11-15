import SwiftUI

/// 深海极光背景。
///
/// 极光保持静态构图，让内容成为唯一的视觉焦点，也避免持续动画耗电。
struct AppBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                LinearGradient(
                    colors: [CardPalette.screen, CardPalette.screenDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(CardPalette.accent.opacity(0.18))
                    .frame(width: w * 0.90, height: w * 0.90)
                    .blur(radius: 92)
                    .offset(x: -w * 0.35, y: -h * 0.37)

                Circle()
                    .fill(CardPalette.accent2.opacity(0.13))
                    .frame(width: w * 0.72, height: w * 0.72)
                    .blur(radius: 86)
                    .offset(x: w * 0.31, y: -h * 0.10)

                Ellipse()
                    .fill(CardPalette.amber.opacity(0.07))
                    .frame(width: w * 0.82, height: h * 0.25)
                    .blur(radius: 74)
                    .offset(x: w * 0.22, y: h * 0.43)

                AuroraVeil()
                    .fill(
                        LinearGradient(
                            colors: [
                                CardPalette.accent.opacity(0.00),
                                CardPalette.accent.opacity(0.075),
                                CardPalette.accent2.opacity(0.045),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 18)
                    .rotationEffect(.degrees(-10))

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.045),
                        Color.clear,
                        Color.black.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
    }
}

private struct AuroraVeil: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.02, y: rect.height * 0.24))
        path.addCurve(
            to: CGPoint(x: rect.width * 1.02, y: rect.height * 0.08),
            control1: CGPoint(x: rect.width * 0.28, y: rect.height * 0.02),
            control2: CGPoint(x: rect.width * 0.68, y: rect.height * 0.34)
        )
        path.addLine(to: CGPoint(x: rect.width * 1.02, y: rect.height * 0.38))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.02, y: rect.height * 0.54),
            control1: CGPoint(x: rect.width * 0.70, y: rect.height * 0.22),
            control2: CGPoint(x: rect.width * 0.34, y: rect.height * 0.72)
        )
        path.closeSubpath()
        return path
    }
}
