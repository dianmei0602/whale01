import SwiftUI
import Foundation

/// 全屏的 Nomi：整个小人放大到满屏，倾斜手机时分层错动。
///
/// 视差分配（越靠前的层跑得越快）：
///   头部外壳 0.6 · 屏幕 0.85 · 眼睛 1.0 · 眼内层 1.45 · 高光 1.9
/// 层与层之间的速度差，就是"嵌进去"的深度感。
struct ImmersiveFaceView: View {
    var eyeOpen: Double = 1
    var eyeScale: Double = 1
    var isListening: Bool = false
    var eyeTint: Color = EyePalette.default

    var onTap: () -> Void
    var onClose: () -> Void

    @State private var tilt = MotionTilt()
    @State private var blink = false
    @State private var dragY: CGFloat = 0
    @State private var breathe = false

    private let cream = Color(red: 0.914, green: 0.898, blue: 0.859)
    private let creamDark = Color(red: 0.812, green: 0.792, blue: 0.741)
    private let screenColor = Color(red: 0.039, green: 0.055, blue: 0.078)
    private let cyan = Color(red: 0.36, green: 0.86, blue: 1.00)
    private let deep = Color(red: 0.22, green: 0.52, blue: 0.96)

    /// 实际睁开的程度（眨眼优先）
    private var openFactor: Double {
        blink ? 0.05 : max(0.05, eyeOpen)
    }

    var body: some View {
        ZStack {
            background
            character
            hint
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragY = max(0, value.translation.height)
                }
                .onEnded { value in
                    if value.translation.height > 110 {
                        onClose()
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) { dragY = 0 }
                    }
                }
        )
        .onAppear {
            tilt.start()
            breathe = true
        }
        .onDisappear {
            tilt.stop()
        }
        .task {
            await blinkLoop()
        }
    }

    // MARK: - 背景

    private var background: some View {
        ZStack {
            Color(red: 0.016, green: 0.024, blue: 0.035)

            RadialGradient(
                colors: [cyan.opacity(0.18), .clear],
                center: UnitPoint(x: 0.5 + tilt.x * 0.10,
                                  y: 0.46 + tilt.y * 0.10),
                startRadius: 30,
                endRadius: 470
            )

            GridLines()
                .stroke(cyan.opacity(0.05), lineWidth: 1)
                .offset(x: CGFloat(tilt.x) * -10, y: CGFloat(tilt.y) * -8)
        }
        .ignoresSafeArea()
    }

    // MARK: - 整个小人

    private var character: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // 一套单位：横向占到约 74%，同时不超过高度的 78%
            let unit = min(w * 0.0062, h * 0.0028)

            let eyeW = 15 * unit * eyeScale
            let eyeH = 56 * unit * eyeScale * openFactor

            ZStack {
                // 地面投影
                Ellipse()
                    .fill(cyan.opacity(0.10))
                    .frame(width: 84 * unit, height: 14 * unit)
                    .offset(x: CGFloat(tilt.x) * 6,
                            y: 90 * unit + CGFloat(tilt.y) * 4)

                // 脖子 + 脚（跟着头一起，慢一点）
                limbs(unit: unit)

                // 头部外壳：钛合金
                TitaniumPlate(width: 120 * unit,
                              height: 94 * unit,
                              cornerRadius: 27 * unit)
                    .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 18)
                    .shadow(color: cyan.opacity(0.20), radius: 40)
                    .offset(parallax(factor: 0.6, amount: 18))
                    .offset(y: -23 * unit)

                // 屏幕（黑玻璃 + 反光）
                RoundedRectangle(cornerRadius: 24 * unit, style: .continuous)
                    .fill(screenColor)
                    .frame(width: 104 * unit, height: 78 * unit)
                    .overlay(
                        ScreenGloss(width: 104 * unit,
                                    height: 78 * unit,
                                    cornerRadius: 24 * unit)
                    )
                    .offset(parallax(factor: 0.85, amount: 22))
                    .offset(y: -23 * unit)

                // 两只眼
                HStack(spacing: 36 * unit) {
                    eye(width: eyeW, height: eyeH, unit: unit)
                    eye(width: eyeW, height: eyeH, unit: unit)
                }
                .offset(parallax(factor: 1.0, amount: 26))
                .offset(y: -20 * unit)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: dragY * 0.4)
        }
    }

    /// 视差位移
    private func parallax(factor: Double, amount: Double) -> CGSize {
        CGSize(width: tilt.x * amount * factor,
               height: tilt.y * amount * factor * 0.8)
    }

    // MARK: - 一只眼（三层）

    private func eye(width: CGFloat, height: CGFloat, unit: CGFloat) -> some View {
        EyeGlow(width: width, height: height, tint: eyeTint)
            // 视差：整只眼比眼体再快一档
            .offset(x: tilt.x * 18, y: tilt.y * 14)
            .frame(width: width * 1.3, height: height * 1.3)
            .scaleEffect(breathe ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true), value: breathe)
    }

    // MARK: - 脖子和脚

    private func limbs(unit: CGFloat) -> some View {
        VStack(spacing: 0) {
            TitaniumPlate(width: 48 * unit,
                          height: 10 * unit,
                          cornerRadius: 5 * unit,
                          dark: true,
                          gloss: false)

            HStack(spacing: 32 * unit) {
                TitaniumPlate(width: 16 * unit,
                              height: 26 * unit,
                              cornerRadius: 8 * unit,
                              gloss: false)
                TitaniumPlate(width: 16 * unit,
                              height: 26 * unit,
                              cornerRadius: 8 * unit,
                              gloss: false)
            }
            .padding(.top, 4 * unit)
        }
        .offset(parallax(factor: 0.5, amount: 14))
        .offset(y: 57 * unit)
    }

    // MARK: - 底部提示

    private var hint: some View {
        VStack {
            Spacer()
            Text(isListening ? "说完点一下 · 下滑返回" : "点一下说话 · 下滑返回")
                .font(.nomiScaled(size: 14))
                .foregroundColor(.white.opacity(0.35))
                .padding(.bottom, 46)

            Capsule()
                .fill(
                    LinearGradient(colors: [cyan.opacity(0.7), deep.opacity(0.7)],
                                   startPoint: .leading,
                                   endPoint: .trailing)
                )
                .frame(width: 120, height: 4)
                .padding(.bottom, 12)
        }
    }

    // MARK: - 眨眼

    @MainActor
    private func blinkLoop() async {
        while !Task.isCancelled {
            let wait = UInt64(Double.random(in: 2.4...5.2) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: wait)
            if Task.isCancelled { return }

            withAnimation(.easeOut(duration: 0.07)) { blink = true }
            try? await Task.sleep(nanoseconds: 90_000_000)
            if Task.isCancelled { return }
            withAnimation(.easeIn(duration: 0.12)) { blink = false }
        }
    }
}

/// 背景网格
struct GridLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 44

        var x: CGFloat = 0
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += step
        }

        var y: CGFloat = 0
        while y < rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += step
        }
        return path
    }
}
