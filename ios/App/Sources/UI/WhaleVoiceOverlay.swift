import SwiftUI

enum NomiVoiceStage: Equatable {
    case listening
    case thinking
    case speaking

    var title: String {
        switch self {
        case .listening: return "我在听"
        case .thinking: return "正在思考"
        case .speaking: return "正在播报"
        }
    }

    var headline: String {
        switch self {
        case .listening: return "你说，我在。"
        case .thinking: return "让我想一下。"
        case .speaking: return "找到了，念给你听。"
        }
    }
}

/// 语音不是另一个聊天页，而是一段有开始和结束的临时状态。
struct WhaleVoiceOverlay: View {
    let stage: NomiVoiceStage
    let caption: String
    let onClose: () -> Void
    let onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateRings = false
    @State private var animateWave = false

    private let bars: [CGFloat] = [
        0.22, 0.52, 0.76, 0.36, 0.88, 0.58, 0.82, 0.44, 0.68,
        0.94, 0.54, 0.30, 0.72, 0.46, 0.84, 0.26, 0.62, 0.40
    ]

    private let accent = Color(red: 0.38, green: 0.92, blue: 0.84)
    private let accent2 = Color(red: 0.47, green: 0.73, blue: 1.00)
    private let ink = Color(red: 0.94, green: 0.99, blue: 0.98)
    private let muted = Color(red: 0.58, green: 0.68, blue: 0.70)
    private let faint = Color(red: 0.38, green: 0.50, blue: 0.52)
    private let surface = Color.white.opacity(0.075)
    private let line = Color(red: 0.38, green: 0.92, blue: 0.84).opacity(0.16)

    var body: some View {
        ZStack {
            background
            content
        }
        .ignoresSafeArea()
        .transition(.opacity.combined(with: .scale(scale: 1.025)))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 3.4).repeatForever(autoreverses: false)) {
                animateRings = true
            }
            withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) {
                animateWave = true
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var background: some View {
        ZStack {
            Color(red: 0.018, green: 0.047, blue: 0.063)

            RadialGradient(
                colors: [accent.opacity(0.24), Color.clear],
                center: UnitPoint(x: 0.50, y: 0.26),
                startRadius: 20,
                endRadius: 390
            )

            RadialGradient(
                colors: [accent2.opacity(0.16), Color.clear],
                center: UnitPoint(x: 0.52, y: 1.02),
                startRadius: 20,
                endRadius: 330
            )

            AuroraVeil()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.12), accent2.opacity(0.05), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 22)
                .rotationEffect(.degrees(-8))
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            topBar

            Spacer(minLength: 16)

            voiceStage

            Text(stage.headline)
                .font(.nomiScaled(size: 30, weight: .bold))
                .tracking(-1.1)
                .foregroundStyle(ink)
                .padding(.top, 4)

            Text(caption.isEmpty ? defaultHint : caption)
                .font(.nomiScaled(size: 13))
                .foregroundStyle(muted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 34)
                .padding(.top, 8)

            waveform
                .padding(.top, 18)

            Spacer(minLength: 18)

            actionBar

            Text("音频只用于这次对话 · 不会在后台持续录音")
                .font(.nomiScaled(size: 9.5))
                .foregroundStyle(faint)
                .padding(.top, 13)
                .padding(.bottom, 22)
        }
        .padding(.horizontal, 20)
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.nomiScaled(size: 14, weight: .semibold))
                    .foregroundStyle(ink)
                    .frame(width: 34, height: 34)
                    .background(surface)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(line, lineWidth: 1)
                    }
            }
            .buttonStyle(WhalePressStyle())
            .accessibilityLabel("关闭语音")

            Spacer()

            Text("语音助手")
                .font(.nomiScaled(size: 12, weight: .semibold))
                .foregroundStyle(ink)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.nomiScaled(size: 8))
                Text("仅本次使用")
                    .font(.nomiScaled(size: 9.5, weight: .medium))
            }
            .foregroundStyle(faint)
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.top, 10)
    }

    private var voiceStage: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(accent.opacity(0.16), lineWidth: 1)
                    .frame(
                        width: 150 + CGFloat(index) * 34,
                        height: 150 + CGFloat(index) * 34
                    )
                    .scaleEffect(animateRings ? 1.18 : 0.74)
                    .opacity(animateRings ? 0 : 0.72)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeOut(duration: 3.4)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.82),
                        value: animateRings
                    )
            }

            Circle()
                .fill(accent.opacity(0.20))
                .frame(width: 174, height: 174)
                .blur(radius: 34)

            PetCharacterView(
                action: stage == .thinking ? .nod : .idle,
                followFace: 0,
                size: 112,
                eyeOpen: 1,
                eyeScale: 1,
                eyeTint: EyePalette.default,
                showShadow: false,
                headTilt: stage == .thinking ? 4 : 0,
                blinkSpeed: 1,
                expression: stage == .thinking ? .think : (stage == .speaking ? .happy : .curious)
            )

            VStack {
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(stage == .listening ? accent : Color(red: 1.00, green: 0.76, blue: 0.45))
                        .frame(width: 5, height: 5)
                    Text(stage.title)
                        .font(.nomiScaled(size: 10, weight: .semibold))
                }
                .foregroundStyle(ink)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.30))
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(accent.opacity(0.20), lineWidth: 1)
                }
                .offset(y: 11)
            }
        }
        .frame(height: 230)
    }

    private var waveform: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(bars.enumerated()), id: \.offset) { index, height in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent, accent2],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: 7 + height * 30)
                    .scaleEffect(
                        y: animateWave
                            ? (index.isMultiple(of: 2) ? 0.72 : 1)
                            : (index.isMultiple(of: 3) ? 0.60 : 0.92),
                        anchor: .center
                    )
                    .opacity(0.82)
            }
        }
        .frame(height: 38)
    }

    private var actionBar: some View {
        HStack(spacing: 9) {
            Button(action: onClose) {
                Text("取消")
                    .font(.nomiScaled(size: 13, weight: .semibold))
                    .foregroundStyle(muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(line, lineWidth: 1)
                    }
            }
            .buttonStyle(WhalePressStyle())

            Button(action: onConfirm) {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark")
                        .font(.nomiScaled(size: 11, weight: .bold))
                    Text(stage == .listening ? "说完了" : "关闭")
                        .font(.nomiScaled(size: 14, weight: .bold))
                }
                .foregroundStyle(Color(red: 0.02, green: 0.16, blue: 0.13))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [accent, accent2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(WhalePressStyle(scale: 0.96))
        }
    }

    private var defaultHint: String {
        switch stage {
        case .listening:
            return "试着说：“帮我看看今天还有什么安排。”"
        case .thinking:
            return "正在结合日程、位置和你的偏好。"
        case .speaking:
            return "回答会同时显示在对话里。"
        }
    }
}

private struct AuroraVeil: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: -rect.width * 0.05, y: rect.height * 0.22))
        path.addCurve(
            to: CGPoint(x: rect.width * 1.05, y: rect.height * 0.08),
            control1: CGPoint(x: rect.width * 0.28, y: -rect.height * 0.02),
            control2: CGPoint(x: rect.width * 0.70, y: rect.height * 0.32)
        )
        path.addLine(to: CGPoint(x: rect.width * 1.05, y: rect.height * 0.38))
        path.addCurve(
            to: CGPoint(x: -rect.width * 0.05, y: rect.height * 0.52),
            control1: CGPoint(x: rect.width * 0.72, y: rect.height * 0.20),
            control2: CGPoint(x: rect.width * 0.34, y: rect.height * 0.74)
        )
        path.closeSubpath()
        return path
    }
}
