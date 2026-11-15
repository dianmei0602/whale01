import Foundation
import CoreMotion
import Observation

/// 手机倾斜 → 归一化到 -1…1。
/// 拿来做裸眼 3D 的视差：倾斜多少，眼睛的每一层就错动多少。
///
/// 用的是 deviceMotion（陀螺仪 + 加速度计），**不需要任何权限**，
/// 和计步器那个 CMPedometer 不是一回事。
@Observable
@MainActor
final class MotionTilt {

    /// 左右倾斜：-1 左，+1 右
    var x: Double = 0
    /// 前后倾斜：-1 上仰，+1 下俯
    var y: Double = 0

    /// 有没有真的收到数据（模拟器上会是 false）
    var isActive = false

    private let manager = CMMotionManager()
    private var basePitch: Double?
    private var smoothing: Double = 0.18

    func start() {
        guard manager.isDeviceMotionAvailable else {
            isActive = false
            return
        }
        guard !manager.isDeviceMotionActive else { return }

        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        basePitch = nil

        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }

            let roll = motion.attitude.roll
            let pitch = motion.attitude.pitch

            if self.basePitch == nil {
                self.basePitch = pitch
            }
            let base = self.basePitch ?? pitch

            let targetX = max(-1, min(1, roll / 0.55))
            let targetY = max(-1, min(1, (pitch - base) / 0.55))

            // 低通，避免抖动
            self.x = self.x * (1 - self.smoothing) + targetX * self.smoothing
            self.y = self.y * (1 - self.smoothing) + targetY * self.smoothing

            if !self.isActive {
                self.isActive = true
            }
        }
    }

    func stop() {
        if manager.isDeviceMotionActive {
            manager.stopDeviceMotionUpdates()
        }
        x = 0
        y = 0
        isActive = false
    }
}
