import Foundation
import CoreLocation

/// 拿当前位置。失败或没授权就返回 nil，由调用方退回设置里的城市。
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private var waiting: [CheckedContinuation<CLLocationCoordinate2D?, Never>] = []
    private var authorizationWaiting: CheckedContinuation<Bool, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// 一次拿全：坐标 + 完整地址 + 精度。失败返回 nil。
    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            return true
        }
        guard status == .notDetermined else { return false }

        return await withCheckedContinuation { continuation in
            authorizationWaiting = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentFix(requestPermission: Bool = true) async -> LocationFix? {
        guard let coordinate = await currentCoordinate(requestPermission: requestPermission) else { return nil }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        let placemarks = try? await geocoder.reverseGeocodeLocation(
            location,
            preferredLocale: Locale(identifier: "zh_CN")
        )
        let place = placemarks?.first

        return LocationFix(latitude: coordinate.latitude,
                           longitude: coordinate.longitude,
                           cityName: place?.locality ?? place?.administrativeArea,
                           district: place?.subLocality,
                           street: place?.thoroughfare,
                           number: place?.subThoroughfare,
                           placeName: place?.name,
                           horizontalAccuracy: max(0, location.horizontalAccuracy))
    }

    func currentCoordinate(requestPermission: Bool = true) async -> CLLocationCoordinate2D? {
        let status = manager.authorizationStatus
        if status == .notDetermined, requestPermission {
            guard await requestAuthorization() else { return nil }
        }

        let now = manager.authorizationStatus
        guard now == .authorizedWhenInUse || now == .authorizedAlways else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            waiting.append(continuation)
            manager.requestLocation()
        }
    }

    func cityName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let geocoder = CLGeocoder()
        let placemarks = try? await geocoder.reverseGeocodeLocation(
            CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            preferredLocale: Locale(identifier: "zh_CN")
        )
        guard let place = placemarks?.first else { return nil }
        return place.locality ?? place.subAdministrativeArea ?? place.administrativeArea
    }

    // MARK: - CLLocationManagerDelegate

    // CLLocationManagerDelegate 的方法是 nonisolated 的，
    // @MainActor 类直接实现会报「隔离不匹配」。所以这里标 nonisolated，
    // 再把结果跳回主线程。
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        let lat = coordinate?.latitude
        let lon = coordinate?.longitude

        Task { @MainActor in
            let fix: CLLocationCoordinate2D? = {
                guard let lat = lat, let lon = lon else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }()
            self.resume(with: fix)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in
            self.resume(with: nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.finishAuthorization(status)
        }
    }

    private func finishAuthorization(_ status: CLAuthorizationStatus) {
        guard status != .notDetermined, let continuation = authorizationWaiting else { return }
        authorizationWaiting = nil
        continuation.resume(
            returning: status == .authorizedWhenInUse || status == .authorizedAlways
        )
    }

    private func resume(with coordinate: CLLocationCoordinate2D?) {
        let pending = waiting
        waiting.removeAll()
        for continuation in pending {
            continuation.resume(returning: coordinate)
        }
    }
}
