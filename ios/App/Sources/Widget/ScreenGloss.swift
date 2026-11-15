import SwiftUI

/// 屏幕：黑色玻璃，**不做顶部高光**。
///
/// 只留两处极淡的反光，让黑屏有玻璃厚度、不发死：
/// · 左侧一条竖向反光
/// · 右下角一块冷反光
/// 顶部完全干净——眼睛是唯一的主角。
struct ScreenGloss: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            // 左侧一条竖向反光，拉开玻璃厚度
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.00)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width * 0.07, height: height * 0.62)
                .blur(radius: width * 0.03)
                .offset(x: -width * 0.40, y: -height * 0.02)

            // 右下角冷反光，让黑色不发死
            Ellipse()
                .fill(Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.07))
                .frame(width: width * 0.58, height: height * 0.32)
                .blur(radius: height * 0.09)
                .offset(x: width * 0.26, y: height * 0.34)
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}
