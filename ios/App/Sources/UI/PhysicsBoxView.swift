import SwiftUI
import Combine

/// 物理盒子：一个和锁屏那个磨砂框一样的圆角盒子，
/// 倾斜手机 Nomi 就往下掉，撞墙反弹、贴地滚动、落地压扁。
///
/// 为什么不做在锁屏上：Live Activity 是系统渲染的静态快照，
/// 不能读陀螺仪，也不会跟着倾斜变化。盒子只能放在 App 里。
struct PhysicsBoxView: View {

    @Environment(\.dismiss) private var dismiss

    @StateObject private var tilt = TiltProvider()

    @State private var boxed = BoxBody()
    @State private var lastTick = Date()
    @State private var face: PetExpression = .curious
    @State private var faceUntil = Date.distantPast
    @State private var tossCount = 0

    /// 放 @State 里只建一次；放 let 的话每帧都会重建、反复重订阅
    @State private var ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    let boxW = side
                    let boxH = side * 0.92

                    ZStack {
                        // 磨砂盒子
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(CardPalette.line, lineWidth: 1)
                            )
                            .frame(width: boxW, height: boxH)

                        // 新圆形头部 Nomi
                        Image(face.animationState.posterName)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: side * 0.27, height: side * 0.27)
                            .rotationEffect(.degrees(boxed.angle))
                            .scaleEffect(x: 1 / boxed.squash, y: boxed.squash)
                            .position(x: boxed.x * boxW,
                                      y: boxed.y * boxH)
                            .animation(.easeOut(duration: 0.08), value: boxed.angle)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        PhysicsBox.toss(&boxed)
                        tossCount += 1
                        face = .startle
                        faceUntil = Date().addingTimeInterval(0.45)
                    }
                }
                .frame(maxHeight: 420)

                VStack(spacing: 6) {
                    Text(tilt.available ? "倾斜手机，它会跟着掉" : "这台设备读不到陀螺仪")
                        .font(.nomiScaled(size: 14, weight: .medium))
                        .foregroundColor(CardPalette.ink)

                    Text(tilt.isFlat
                         ? "手机平放着，重力垂直于屏幕——立起来才有方向"
                         : "点一下盒子，可以把它抛起来")
                        .font(.nomiScaled(size: 12.5))
                        .foregroundColor(CardPalette.subtle)
                        .multilineTextAlignment(.center)

                    if tossCount > 0 {
                        Text("已经抛了 \(tossCount) 次")
                            .font(.nomiScaled(size: 11.5))
                            .foregroundColor(CardPalette.subtle)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(18)
            .background(CardPalette.screen)
            .navigationTitle("物理盒子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("扶正") {
                        boxed = BoxBody()
                    }
                }
            }
        }
        .onAppear {
            tilt.start()
            lastTick = Date()
        }
        .onDisappear {
            tilt.stop()
        }
        .onReceive(ticker) { _ in
            advance()
        }
    }

    // MARK: - 每帧

    private func advance() {
        let now = Date()
        let dt = min(0.05, now.timeIntervalSince(lastTick))
        lastTick = now
        guard dt > 0 else { return }

        PhysicsBox.step(&boxed, dt: dt, gravityX: tilt.gx, gravityY: tilt.gy)

        // 砸得重 → 惊一下
        if boxed.lastImpact > 0.9, now >= faceUntil {
            face = .startle
            faceUntil = now.addingTimeInterval(0.28)
        } else if now >= faceUntil, face != .curious {
            face = .curious
        }
    }

}
