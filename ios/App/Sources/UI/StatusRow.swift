import SwiftUI

/// 首页顶部那一排仪表：天气 / 日程 / 待办。
/// 三格等宽，中间用竖线分隔——像一块小小的仪表盘。
struct StatusRow: View {
    let status: DayStatus

    var body: some View {
        HStack(spacing: 0) {
            cell(
                value: status.temperature.map { "\(Int($0.rounded()))°" } ?? "—",
                label: status.weatherText,
                detail: status.cityName,
                accent: Color(red: 0.38, green: 0.73, blue: 1.00)
            )

            divider

            cell(
                value: status.hasCalendarAccess ? "\(status.meetingCount)" : "—",
                label: "个会",
                detail: status.hasCalendarAccess
                    ? (status.nextMeetingText ?? "今天没有")
                    : "未授权日历",
                accent: Color(red: 1.00, green: 0.74, blue: 0.38)
            )

            divider

            cell(
                value: stepValue,
                label: "步",
                detail: stepDetail,
                accent: Color(red: 0.36, green: 0.92, blue: 0.66)
            )
        }
        .frame(height: 78)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        )
    }

    private var stepValue: String {
        guard let steps = status.steps else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    private var stepDetail: String {
        guard status.hasMotionAccess else { return "未授权运动" }
        guard let steps = status.steps else { return "还没数据" }
        if steps >= status.stepGoal {
            return "达标了"
        }
        return "还差 \(status.stepGoal - steps)"
    }

    private func cell(value: String, label: String, detail: String, accent: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.nomiScaled(size: 25.5, weight: .bold))
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.nomiScaled(size: 13))
                .foregroundColor(CardPalette.ink.opacity(0.85))
                .lineLimit(1)

            Text(detail)
                .font(.nomiScaled(size: 11.5))
                .foregroundColor(CardPalette.subtle)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
    }

    private var divider: some View {
        Rectangle()
            .fill(CardPalette.line)
            .frame(width: 1, height: 40)
    }
}
