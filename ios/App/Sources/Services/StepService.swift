import Foundation
import CoreMotion

/// 今日步数。走 CoreMotion，不走 HealthKit——
/// 后者需要付费开发者账号才能签出 entitlement。
///
/// 注意：这个数反映的是"手机跟你走了多少步"，不是"你走了多少步"。
/// 手机放桌上时不计，和支付宝/高德对不上是正常的。
struct StepSummary: Sendable {
    let steps: Int
    let distanceMeters: Double?
}

@MainActor
final class StepService {
    private let pedometer = CMPedometer()

    var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    var isAuthorized: Bool {
        CMPedometer.authorizationStatus() == .authorized
    }

    func todaySummary() async -> StepSummary? {
        guard isAvailable, isAuthorized else { return nil }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = Date()
        guard end > start else { return nil }

        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, _ in
                guard let data = data else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: StepSummary(
                    steps: data.numberOfSteps.intValue,
                    distanceMeters: data.distance?.doubleValue
                ))
            }
        }
    }
}
