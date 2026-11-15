import Foundation
import ActivityKit

/// 让灵动岛跟着今日页一起变。
/// 规则引擎说"今天有事"→ 起一个 Live Activity；没事 → 收掉。
@MainActor
enum PetActivityController {

    static func sync(mood: PetMood,
                     glow: Double,
                     line: String,
                     title: String = "待机",
                     phase: String = "idle",
                     walkTick: Int = 0,
                     action: String = "walk",
                     tintHex: String = "5CEBFF",
                     posX: Double = 0.5,
                     eyeOpen: Double = 1.0,
                     headTilt: Double = 0,
                     posY: Double = 0.5,
                     bodyRotate: Double = 0,
                     eventTitle: String = "",
                     eventPlace: String = "",
                     eventTime: String = "",
                     countdown: String = "",
                     eventHint: String = "",
                     eventKind: String = "idle",
                     eventID: String = "",
                     enabled: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if !enabled {
            end()
            return
        }

        let state = PetActivityAttributes.ContentState(moodID: mood.id,
                                                       glow: glow,
                                                       line: line,
                                                       title: title,
                                                       phase: phase,
                                                       walkTick: walkTick,
                                                       action: action,
                                                       tintHex: tintHex,
                                                       posX: posX,
                                                       eyeOpen: eyeOpen,
                                                       headTilt: headTilt,
                                                       posY: posY,
                                                       bodyRotate: bodyRotate,
                                                       eventTitle: eventTitle,
                                                       eventPlace: eventPlace,
                                                       eventTime: eventTime,
                                                       countdown: countdown,
                                                       eventHint: eventHint,
                                                       eventKind: eventKind,
                                                       eventID: eventID)

        // 45 分钟后标记为过期：避免一个旧状态在锁屏上无限存活
        let stale = Date().addingTimeInterval(45 * 60)

        if let running = Activity<PetActivityAttributes>.activities.first {
            Task {
                await running.update(ActivityContent(state: state, staleDate: stale))
            }
        } else {
            _ = try? Activity.request(
                attributes: PetActivityAttributes(startedAt: Date()),
                content: ActivityContent(state: state, staleDate: stale)
            )
        }
    }

    static func end() {
        Task {
            for activity in Activity<PetActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}