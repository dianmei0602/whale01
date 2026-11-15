import SwiftUI
import Foundation

/// 聊天里那张日程卡片：今天 / 明天切换，带统计行和地点。
struct ScheduleCardView: View {
    let payload: AssistantView.SchedulePayload

    @State private var showTomorrow = false
    @State private var expanded = false

    private let cyan = CardPalette.accent

    private var meetings: [MeetingItem] {
        showTomorrow ? payload.tomorrow : payload.today
    }

    private var shown: [MeetingItem] {
        expanded ? meetings : Array(meetings.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            segmented
            summary
            rows
            if meetings.count > 3 {
                footer
            }
        }
        .padding(15)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        )
        .padding(.leading, 8)
    }

    // MARK: - 头

    private var header: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(cyan.opacity(0.14))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "calendar")
                        .font(.nomiScaled(size: 15, weight: .medium))
                        .foregroundColor(cyan)
                )

            Text("日程")
                .font(.nomiScaled(size: 17, weight: .semibold))
                .foregroundColor(CardPalette.ink)

            Spacer()

            Text((showTomorrow ? "TOMORROW" : "TODAY") + " · " + String(format: "%02d", meetings.count) + " EVT")
                .font(.nomiScaled(size: 11, weight: .medium))
                .foregroundColor(CardPalette.subtle)
                .tracking(0.6)
        }
        .padding(.bottom, 12)
    }

    // MARK: - 今天 / 明天

    private var segmented: some View {
        HStack(spacing: 0) {
            segment(title: "今天", isOn: !showTomorrow) { showTomorrow = false }
            segment(title: "明天", isOn: showTomorrow) { showTomorrow = true }
        }
        .padding(3)
        .background(CardPalette.raised)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .padding(.bottom, 12)
    }

    private func segment(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                action()
                expanded = false
            }
        } label: {
            Text(title)
                .font(.nomiScaled(size: 15, weight: .semibold))
                .foregroundColor(isOn ? CardPalette.ink : CardPalette.subtle)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isOn ? cyan.opacity(0.16) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(isOn ? cyan.opacity(0.45) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 统计

    private var summary: some View {
        HStack(spacing: 14) {
            stat(label: "EVT", value: String(format: "%02d", meetings.count))
            stat(label: "BUSY", value: busyText)
            stat(label: "NEXT", value: nextText)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 10)
    }

    private func stat(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.nomiScaled(size: 10.5, weight: .medium))
                .foregroundColor(CardPalette.subtle)
                .tracking(0.5)
            Text(value)
                .font(.nomiScaled(size: 12, weight: .semibold))
                .foregroundColor(CardPalette.ink.opacity(0.85))
        }
    }

    private var busyText: String {
        let total = meetings.reduce(0.0) { sum, meeting in
            guard let end = meeting.end, !meeting.isAllDay else { return sum }
            return sum + max(0, end.timeIntervalSince(meeting.start))
        }
        let minutes = Int(total / 60)
        return "\(minutes / 60)H\(String(format: "%02d", minutes % 60))M"
    }

    private var nextText: String {
        let now = Date()
        let upcoming = meetings.first { $0.start > now && !$0.isAllDay }
        guard let next = upcoming else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: next.start)
    }

    // MARK: - 行

    private var rows: some View {
        VStack(spacing: 0) {
            if meetings.isEmpty {
                Text("这一天没有安排。")
                    .font(.nomiScaled(size: 14))
                    .foregroundColor(CardPalette.subtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, meeting in
                    rowView(meeting, index: index)
                }
            }
        }
    }

    private func rowView(_ meeting: MeetingItem, index: Int) -> some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(barColor(index))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(timeText(meeting.start))
                        .font(.nomiScaled(size: 14, weight: .semibold))
                        .foregroundColor(barColor(index))
                    Text(meeting.title)
                        .font(.nomiScaled(size: 15.5, weight: .semibold))
                        .foregroundColor(CardPalette.ink)
                        .lineLimit(1)
                }

                if let location = meeting.location, !location.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.nomiScaled(size: 10.5))
                        Text(location)
                            .font(.nomiScaled(size: 12))
                    }
                    .foregroundColor(CardPalette.subtle)
                    .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CardPalette.line).frame(height: 1)
        }
    }

    private func barColor(_ index: Int) -> Color {
        let palette: [Color] = [
            cyan,
            Color(red: 0.72, green: 0.58, blue: 1.00),
            Color(red: 1.00, green: 0.74, blue: 0.38),
            Color(red: 0.36, green: 0.92, blue: 0.66)
        ]
        return palette[index % palette.count]
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - 底部

    private var footer: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() }
        } label: {
            HStack(spacing: 5) {
                Text(expanded ? "收起" : "展开全部 \(meetings.count) 项")
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.nomiScaled(size: 10.5, weight: .semibold))
            }
            .font(.nomiScaled(size: 13.5))
            .foregroundColor(CardPalette.subtle)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
        .buttonStyle(.plain)
    }
}
