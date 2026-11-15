import Foundation
import Combine
import CoreMotion

/// 从陀螺仪读重力方向。
///
/// 只在 App 里用——WidgetKit 的锁屏/灵动岛是系统渲染的静态快照，
/// 读不到传感器，所以"锁屏框里倾斜掉下来"做不到。
final class TiltProvider: ObservableObject {

    /// 向右为正
    @Published private(set) var gx: Double = 0
    /// 向下为正（手机竖直时 1.0，倒过来是 -1.0）
    @Published private(set) var gy: Double = 1.0

    /// 手机平放时重力是垂直屏幕的，这时候没法判断"下"，标记一下
    @Published private(set) var isFlat: Bool = false

    @Published private(set) var available: Bool = false

    private let manager = CMMotionManager()
    private var running = false

    func start() {
        guard manager.isDeviceMotionAvailable, !running else { return }
        running = true
        available = true

        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let g = motion.gravity

            self.gx = g.x
            // CoreMotion 里 gravity.y 向上为正，我们规定向下为正
            self.gy = -g.y
            self.isFlat = abs(g.z) > 0.85
        }
    }

    func stop() {
        guard running else { return }
        manager.stopDeviceMotionUpdates()
        running = false
    }
}
