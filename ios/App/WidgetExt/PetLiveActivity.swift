import SwiftUI
import WidgetKit
import ActivityKit

/// 灵动岛 + 锁屏。
///
/// **锁屏是 Nomi 的家**：没有深色卡片，直接浮在壁纸上。
/// 有事件时，事件信息贴在它下面：事件名、时间、倒计时、一行提示、最多两个动作。
/// 没有事件时，只有它自己。
struct PetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetActivityAttributes.self) { context in
            LockScreenPet(state: context.state)
                .widgetURL(URL(string: "nomi://today"))
                .activityBackgroundTint(Color.clear)
                .activitySystemActionForegroundColor(Color(red: 0.31, green: 0.88, blue: 1.00))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    // 展开态给完整角色（缩小版，头身比例不变）
                    PetWalking(state: context.state, size: 34)
                        .padding(.leading, 10)
                        .padding(.top, 2)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(EventText.countdown(context.state))
                            .font(.system(size: 17, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.white)

                        Text(EventText.kindLabel(context.state))
                            .font(.system(size: 10.5))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        if context.state.eventTitle.isEmpty {
                            Text(context.state.line)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.62))
                                .lineLimit(1)
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(context.state.eventTitle)
                                    .font(.system(size: 14.5, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text(context.state.eventTime)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.55))
                                    .lineLimit(1)
                            }

                            if !context.state.eventPlace.isEmpty {
                                Text(context.state.eventPlace)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.55))
                                    .lineLimit(1)
                            }

                            Text(context.state.eventHint)
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(1)
                        }

                        if !context.state.eventID.isEmpty {
                            HStack(spacing: 10) {
                                Link(destination: URL(string: "nomi://prepare/\(context.state.eventID)")!) {
                                    Text("准备一下")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundColor(Color(red: 0.06, green: 0.10, blue: 0.14))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Color(red: 0.31, green: 0.88, blue: 1.00))
                                        .clipShape(Capsule())
                                }

                                Link(destination: URL(string: "nomi://event/\(context.state.eventID)")!) {
                                    Text("查看")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Color.white.opacity(0.14))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
            } compactLeading: {
                HStack(spacing: 8) {
                    EyeGlow(width: 4,
                            height: 12 * PetLiveActivity.blinkScale(tick: context.state.walkTick),
                            tint: Color(hex: context.state.tintHex))
                    EyeGlow(width: 4,
                            height: 12 * PetLiveActivity.blinkScale(tick: context.state.walkTick),
                            tint: Color(hex: context.state.tintHex))
                }
                .padding(.leading, 2)
            } compactTrailing: {
                // compact 只放倒计时，不写事件名，避免被系统裁掉
                if context.state.eventTitle.isEmpty {
                    Color.clear.frame(width: 1, height: 1)
                } else {
                    Text(EventText.shortCountdown(context.state))
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(Color(red: 0.31, green: 0.88, blue: 1.00))
                }
            } minimal: {
                EyeGlow(width: 5,
                        height: 13 * PetLiveActivity.blinkScale(tick: context.state.walkTick),
                        tint: Color(hex: context.state.tintHex))
            }
            .keylineTint(Color(red: 0.31, green: 0.88, blue: 1.00))
        }
    }

    /// 眨眼：每 6 帧闭一次眼
    static func blinkScale(tick: Int) -> CGFloat {
        tick % 6 == 0 ? 0.16 : 1.0
    }
}

/// 事件文案的派生逻辑：视图里不写判断，集中在这里
enum EventText {
    static func countdown(_ state: PetActivityAttributes.ContentState) -> String {
        let text = state.countdown.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? state.title : text
    }

    static func shortCountdown(_ state: PetActivityAttributes.ContentState) -> String {
        // "22 分钟后" → "22m"
        let digits = state.countdown.filter { $0.isNumber }
        guard !digits.isEmpty else { return "•" }
        return state.countdown.contains("小时") ? "\(digits)h" : "\(digits)m"
    }

    static func kindLabel(_ state: PetActivityAttributes.ContentState) -> String {
        switch state.eventKind {
        case "soon":     return "该准备了"
        case "now":      return "进行中"
        case "upcoming": return "接下来"
        default:         return state.phase.uppercased()
        }
    }
}

/// 会动的小人：动作由 App 推过来的 `action` 决定，位置由 `posX` 决定。
struct PetWalking: View {
    let state: PetActivityAttributes.ContentState
    var size: CGFloat = 34
    /// 锁屏上不要地面影子（会像个发光椭圆）
    var showShadow: Bool = true

    private var posterName: String {
        switch state.action {
        case "sit", "crawl":
            return "NomiWidgetSleepy"
        case "nod":
            return "NomiWidgetThinking"
        case "jump", "hop", "run":
            return "NomiWidgetExcited"
        default:
            return "NomiWidgetIdle"
        }
    }

    var body: some View {
        Image(posterName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size * 1.15, height: size * 1.28)
    }
}

/// 锁屏：把整块壁纸当它的家。
///
/// 上面是完整角色（96pt），有事件时下面补一条事件信息。
/// 没有事件就只留角色，不占空间也不编数据。
struct LockScreenPet: View {
    let state: PetActivityAttributes.ContentState

    private var robotSize: CGFloat { 72 }

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                let raw = CGFloat(min(max(state.posX, 0.06), 0.94))
                let x = geo.size.width * raw
                let rawY = CGFloat(min(max(state.posY, 0.14), 0.86))
                let y = geo.size.height * rawY

                PetWalking(state: state, size: robotSize, showShadow: false)
                    .rotationEffect(.degrees(state.bodyRotate))
                    .position(x: x, y: y)
            }
            .frame(height: 108)

            if !state.eventTitle.isEmpty {
                eventCard
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }
        }
    }

    private var eventCard: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(state.eventTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(state.eventTime)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Text(state.eventHint)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(EventText.countdown(state))
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundColor(Color(red: 0.31, green: 0.88, blue: 1.00))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
