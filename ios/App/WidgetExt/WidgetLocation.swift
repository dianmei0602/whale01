import Foundation
import CoreLocation

/// 小组件里的定位。
///
/// 以前小组件把上海坐标写死了，用户在杭州也看到上海的天气——那是假数据。
/// WidgetKit 支持通过 Info.plist 的 `NSWidgetWantsLocation` 拿到定位，
/// 但拿不到时会超时返回 nil，调用方就干脆不显示温度，而不是编一个。
final class WidgetLocation: NSObject, CLLocationManagerDelegate {

    static let shared = WidgetLocation()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func current() async -> CLLocationCoordinate2D? {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()

            // 3 秒拿不到就别等了，小组件刷新有时间限制
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.finish(nil)
            }
        }
    }

    private func finish(_ coordinate: CLLocationCoordinate2D?) {
        continuation?.resume(returning: coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(locations.last?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(nil)
    }
}
