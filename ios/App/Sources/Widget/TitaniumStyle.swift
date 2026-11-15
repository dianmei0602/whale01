import SwiftUI

/// 钛合金外壳 · 强对比版。
///
/// 金属的关键不是"灰调子好看"，是**明暗差**：
/// 暗部要接近全黑，高光要打到纯白。
/// 灰蒙蒙的渐变读起来是塑料，只有白到黑的硬落差才读成金属。
enum Titanium {

    /// ① 主体：从纯白一路压到近黑，底部再弹一道反光
    static var shell: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.white, location: 0.000),
                .init(color: Color(red: 0.72, green: 0.73, blue: 0.75), location: 0.035),
                .init(color: Color(red: 0.50, green: 0.51, blue: 0.53), location: 0.140),
                .init(color: Color(red: 0.37, green: 0.38, blue: 0.40), location: 0.400),
                .init(color: Color(red: 0.20, green: 0.21, blue: 0.23), location: 0.700),
                .init(color: Color(red: 0.07, green: 0.075, blue: 0.085), location: 0.900),
                .init(color: Color(red: 0.04, green: 0.045, blue: 0.05), location: 0.965),
                .init(color: Color(red: 0.34, green: 0.35, blue: 0.37), location: 0.988),
                .init(color: Color(red: 0.55, green: 0.56, blue: 0.58), location: 1.000)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// ② 主镜面高光：纯白、窄、两边硬切
    static var specular: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.00), location: 0.24),
                .init(color: .white.opacity(0.55), location: 0.300),
                .init(color: Color.white, location: 0.318),
                .init(color: .white.opacity(0.72), location: 0.334),
                .init(color: .white.opacity(0.00), location: 0.366),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// ③ 第二道细高光：右上角来的一小条，像第二个光源
    static var specular2: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.00), location: 0.52),
                .init(color: .white.opacity(0.55), location: 0.615),
                .init(color: .white.opacity(0.85), location: 0.628),
                .init(color: .white.opacity(0.00), location: 0.652),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }

    /// ④ 左上热点
    static var hotspot: RadialGradient {
        RadialGradient(
            colors: [
                .white.opacity(0.95),
                .white.opacity(0.35),
                .white.opacity(0.00)
            ],
            center: UnitPoint(x: 0.22, y: 0.12),
            startRadius: 0,
            endRadius: 70
        )
    }

    /// ⑤ 横向拉丝
    static var brushed: LinearGradient {
        LinearGradient(
            stops: (0...18).map { index in
                Gradient.Stop(
                    color: .white.opacity(index % 2 == 0 ? 0.030 : 0.0),
                    location: Double(index) / 18.0
                )
            },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// ⑥ 边缘收光：顶上一条纯白、底下一道全黑
    static var rim: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.white, location: 0.00),
                .init(color: Color.white.opacity(0.35), location: 0.10),
                .init(color: Color.white.opacity(0.04), location: 0.45),
                .init(color: Color.black.opacity(0.55), location: 0.80),
                .init(color: Color.black.opacity(0.90), location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 腿脚用的钛：**和头部同一套高对比**（纯白 → 近黑），
    /// 只是不带那道斜高光——短板上的斜带会读成抛光铬珠。
    /// 换成一条横向的窄亮带，像金属顶面接住光。
    static var shellLimb: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.white, location: 0.000),
                .init(color: Color(red: 0.70, green: 0.71, blue: 0.73), location: 0.050),
                .init(color: Color(red: 0.46, green: 0.47, blue: 0.49), location: 0.180),
                .init(color: Color(red: 0.30, green: 0.31, blue: 0.33), location: 0.450),
                .init(color: Color(red: 0.12, green: 0.125, blue: 0.14), location: 0.750),
                .init(color: Color(red: 0.04, green: 0.045, blue: 0.05), location: 0.940),
                .init(color: Color(red: 0.42, green: 0.43, blue: 0.45), location: 1.000)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 腿脚的高光：一条横向窄亮带（竖向渐变里切出来的），硬边
    static var specularSoft: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.00), location: 0.06),
                .init(color: .white.opacity(0.70), location: 0.11),
                .init(color: .white.opacity(0.92), location: 0.145),
                .init(color: .white.opacity(0.00), location: 0.20),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 小零件用暗一点的钛
    static var shellDark: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.92, green: 0.93, blue: 0.94), location: 0.00),
                .init(color: Color(red: 0.46, green: 0.47, blue: 0.49), location: 0.30),
                .init(color: Color(red: 0.10, green: 0.11, blue: 0.12), location: 0.85),
                .init(color: Color(red: 0.42, green: 0.43, blue: 0.45), location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// 一块钛合金板：六层叠出来的金属
struct TitaniumPlate: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var dark: Bool = false
    /// 强镜面（大头用）还是哑光（脖子、脚这种小零件用）。
    /// 小零件上打满高光会像抛光铬珠，跟头部不是同一种材料。
    var gloss: Bool = true

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return shape
            .fill(gloss ? (dark ? Titanium.shellDark : Titanium.shell)
                        : Titanium.shellLimb)
            .frame(width: width, height: height)
            .overlay(shape.fill(gloss ? Titanium.specular : Titanium.specularSoft))
            .overlay(shape.fill(Titanium.specular2).opacity(gloss ? 1 : 0))
            .overlay(shape.fill(Titanium.hotspot).opacity(gloss ? 1 : 0))
            .overlay(shape.fill(Titanium.brushed))
            .overlay(
                shape.strokeBorder(Titanium.rim,
                                   lineWidth: max(0.8, min(2.4, height * 0.018)))
            )
    }
}
