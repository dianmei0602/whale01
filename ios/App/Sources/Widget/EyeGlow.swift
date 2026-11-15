import SwiftUI

/// 眼睛：细长条，平涂。
///
/// 颜色由情绪决定（App 里传 expression.eyeTint）：
/// 平时中性青，高兴偏暖绿，低落偏冷蓝，生气变红。
struct EyeGlow: View {
    let width: CGFloat
    let height: CGFloat
    var tint: Color = EyePalette.default

    var body: some View {
        Capsule(style: .continuous)
            .fill(tint)
            .frame(width: width, height: height)
            .shadow(color: tint.opacity(0.55), radius: max(1, width * 0.40))
    }
}
