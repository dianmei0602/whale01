import SwiftUI

/// 一张脸。纯色胶囊 + 眼皮遮罩；开心/困用弧线。
/// 这个文件同时编进 App 和 Widget 两个 target。
struct PetFaceView: View {
    let mood: PetMood
    var glow: Double = 0.6
    var scale: Double = 1.0
    var blinking: Bool = false

    private let cyan = Color(red: 0.30, green: 0.89, blue: 1.00)

    var body: some View {
        HStack(alignment: .center, spacing: mood.gap * scale) {
            eye(mood.left)
            eye(mood.right)
        }
        .shadow(color: cyan.opacity(min(1, glow)), radius: 3)
    }

    @ViewBuilder
    private func eye(_ spec: EyeSpec) -> some View {
        let width = spec.width * scale
        let height = spec.height * scale
        let lid = blinking ? 0.95 : spec.lid

        switch spec.shape {
        case .circle:
            Capsule()
                .fill(cyan)
                .frame(width: width, height: height)
                .mask(alignment: .bottom) {
                    Rectangle().frame(height: max(0, height * (1 - lid)))
                }
                .offset(y: spec.offsetY * scale)
                .rotationEffect(.degrees(spec.tilt))

        case .arcUp:
            ArcEye(up: true)
                .stroke(cyan, style: StrokeStyle(lineWidth: max(1.5, height * 0.32), lineCap: .round))
                .frame(width: width, height: height)

        case .arcDown:
            ArcEye(up: false)
                .stroke(cyan, style: StrokeStyle(lineWidth: max(1.5, height * 0.32), lineCap: .round))
                .frame(width: width, height: height)
        }
    }
}

/// 单只眼，给 compact 用（岛的两侧各一只，中间的摄像头当鼻梁）
struct PetEyeOnly: View {
    let spec: EyeSpec
    var glow: Double = 0.6
    var scale: Double = 1.0
    var blinking: Bool = false

    private let cyan = Color(red: 0.30, green: 0.89, blue: 1.00)

    var body: some View {
        let width = spec.width * scale
        let height = spec.height * scale

        Group {
            switch spec.shape {
            case .circle:
                Capsule()
                    .fill(cyan)
                    .frame(width: width, height: height)
                    .mask(alignment: .bottom) {
                        Rectangle().frame(height: max(0, height * (1 - spec.lid)))
                    }
                    .rotationEffect(.degrees(spec.tilt))
            case .arcUp:
                ArcEye(up: true)
                    .stroke(cyan, style: StrokeStyle(lineWidth: max(1.5, height * 0.32), lineCap: .round))
                    .frame(width: width, height: height)
            case .arcDown:
                ArcEye(up: false)
                    .stroke(cyan, style: StrokeStyle(lineWidth: max(1.5, height * 0.32), lineCap: .round))
                    .frame(width: width, height: height)
            }
        }
        .shadow(color: cyan.opacity(min(1, glow)), radius: 2)
    }
}

/// 一道弧。开心是 ∩，困是 ∪。
struct ArcEye: Shape {
    let up: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if up {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.55)
            )
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.55)
            )
        }
        return path
    }
}