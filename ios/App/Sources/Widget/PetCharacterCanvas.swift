import SwiftUI

/// 静态绘制：给一组 `MotionValues`，把小人画出来。
///
/// 这个文件同时编进 **App** 和 **Widget Extension**：
/// · App 里由 TimelineView 每帧喂新值 → 会动
/// · 小组件 / 灵动岛喂一个固定值 → 静态，但姿势和 App 里一模一样
struct PetCharacterCanvas: View {
    let values: MotionValues
    let size: CGFloat
    /// 锁屏上是直接浮在壁纸上的，那个青色椭圆影子会像个光斑，所以可以关掉
    var showShadow: Bool = true
    /// 眼睛颜色。默认中性青；App 里会按情绪传不同的色。
    var eyeTint: Color = EyePalette.default

    private var s: CGFloat { size / 200.0 }

    private let cream = Color(red: 0.914, green: 0.898, blue: 0.859)
    private let creamDark = Color(red: 0.812, green: 0.792, blue: 0.741)
    private let screen = Color(red: 0.039, green: 0.055, blue: 0.078)
    private let cyan = Color(red: 0.30, green: 0.89, blue: 1.00)

    var body: some View {
        ZStack {
            if showShadow {
                shadow
            }

            ZStack {
                limbs
                head
            }
            .offset(y: CGFloat(values.bodyY) * s)
            .rotationEffect(.degrees(values.bodyRotate))
            .rotation3DEffect(
                .degrees(values.rotateY),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.55
            )
        }
        .frame(width: size, height: size * 1.25)
    }

    // MARK: 地面投影

    private var shadow: some View {
        let lift = max(0, min(1, -values.bodyY / 60))
        return Ellipse()
            .fill(cyan.opacity(0.14 * (1 - lift * 0.7)))
            .frame(width: 84 * s * (1 - lift * 0.4),
                   height: 14 * s * (1 - lift * 0.4))
            .offset(y: 90 * s)
    }

    // MARK: 头（绝对不缩放）

    private var head: some View {
        ZStack {
            // 钛合金外壳：主渐变 + 镜面 + 拉丝 + 收边
            TitaniumPlate(width: 120 * s,
                          height: 94 * s,
                          cornerRadius: 27 * s)
                .shadow(color: .black.opacity(0.55), radius: 9 * s, x: 0, y: 5 * s)
                .shadow(color: Color.white.opacity(0.10), radius: 1, x: 0, y: -1)

            RoundedRectangle(cornerRadius: 24 * s, style: .continuous)
                .fill(screen)
                .frame(width: 104 * s, height: 78 * s)
                .overlay(
                    ScreenGloss(width: 104 * s,
                                height: 78 * s,
                                cornerRadius: 24 * s)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24 * s, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.9), lineWidth: 1.5 * s)
                )

            HStack(spacing: 26 * s) {
                eye
                eye
            }
        }
        .rotationEffect(.degrees(values.headRotate))
        .offset(y: -23 * s)
    }

    private var eye: some View {
        EyeGlow(width: 8 * s,
                height: 28 * s * max(0.06, values.eyeOpen) * values.eyeScale,
                tint: eyeTint)
            .offset(x: CGFloat(values.eyeShiftX) * s)
    }

    // MARK: 脖子 + 脚（唯一可以压缩的一层）

    private var limbs: some View {
        ZStack {
            TitaniumPlate(width: 48 * s,
                          height: 10 * s,
                          cornerRadius: 5 * s,
                          dark: true,
                          gloss: false)
                .offset(y: 35 * s)

            HStack(spacing: 32 * s) {
                foot(values.footL)
                foot(values.footR)
            }
            .offset(y: 57 * s)
        }
        .scaleEffect(x: values.limbScaleX, y: values.limbScaleY, anchor: .top)
    }

    private func foot(_ angle: Double) -> some View {
        TitaniumPlate(width: 16 * s,
                      height: 26 * s,
                      cornerRadius: 8 * s,
                      gloss: false)
            .shadow(color: .black.opacity(0.4), radius: 3 * s, y: 2 * s)
            .rotationEffect(.degrees(angle), anchor: .top)
    }
}
