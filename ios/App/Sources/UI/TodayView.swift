import SwiftUI
import UIKit
import Foundation

/// 今日只回答一个问题：今天怎么走。
///
/// 页面不再放天气/会议/步数三栏仪表盘，也不重复画 Nomi。
/// 标题先给结论，下面是一条完整议程，最后才是数据来源。
struct TodayView: View {
    /// 深链要求高亮的日程
    var highlightID: String? = nil
    /// 空状态里的主操作：回到 Nomi，把安排说出来
    var onOpenAssistant: () -> Void = { }

    @Environment(AppState.self) private var state
    @State private var sheet: ActiveSheet?

    enum ActiveSheet: String, Identifiable {
        case debug, settings
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    pageHeader

                    if let message = state.errorText, !message.isEmpty {
                        errorCard(message)
                    }

                    if let event = currentMeeting ?? upcomingMeeting {
                        nextEventCard(event)
                    }

                    overviewCards

                    agendaSection

                    if !state.pendingTodos.isEmpty {
                        todoSection
                    }

                    sourceFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .simultaneousGesture(
                DragGesture(minimumDistance: 24).onEnded { value in
                    if abs(value.translation.width) > 80,
                       abs(value.translation.width) > abs(value.translation.height) * 1.2 {
                        onOpenAssistant()
                    }
                }
            )
        }
        .task {
            await state.refresh()
            syncIsland()
        }
        .onChange(of: state.meetings.count) { _, _ in
            syncIsland()
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .debug:
                DebugPanel()
            case .settings:
                SettingsSheet(state: state)
            }
        }
    }

    // MARK: - 标题

    private var pageHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(Self.dateText)
                    .font(.nomiScaled(size: 13, weight: .medium))
                    .foregroundColor(CardPalette.subtle)

                Text(todayTitle)
                    .font(.nomiScaled(size: 34, weight: .bold))
                    .tracking(-0.7)
                    .foregroundColor(CardPalette.ink)

                Text(headlineSummary)
                    .font(.nomiScaled(size: 14.5))
                    .foregroundColor(CardPalette.subtle)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

            }

            Spacer(minLength: 0)

            Menu {
                Button("刷新今天") {
                    Task {
                        await state.refresh()
                        syncIsland()
                    }
                }
                Button("设置") { sheet = .settings }
                Button("诊断") { sheet = .debug }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.nomiScaled(size: 17, weight: .semibold))
                    .foregroundColor(CardPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(CardPalette.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(CardPalette.line, lineWidth: 1))
            }
            .accessibilityLabel("今天的更多操作")
        }
    }

    private var headlineSummary: String {
        if state.loading && state.meetings.isEmpty {
            return "正在整理今天的安排。"
        }

        guard state.dayStatus.hasCalendarAccess else {
            return "还没拿到日历权限，所以今天的安排还看不见。"
        }

        if let current = currentMeeting {
            return "「\(current.title)」正在进行，\(endTimeText(current)) 结束。"
        }

        if let next = upcomingMeeting {
            return "下一件是「\(next.title)」，\(timeText(next.start)) 开始。"
        }

        return "今天没有安排，想做什么可以直接告诉 Nomi。"
    }

    private var todayTitle: String {
        let count = state.meetings.count + state.pendingTodos.count
        guard state.dayStatus.hasCalendarAccess else { return "今天" }
        return count == 0 ? "今天" : "今天 \(count) 件事"
    }

    // MARK: - 参考稿概览

    private func nextEventCard(_ meeting: MeetingItem) -> some View {
        let now = Date()
        let isNow = meeting.start <= now && (meeting.end ?? meeting.start) > now
        let place = meeting.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isNow ? "正在进行" : "下一件事")
                    .font(.nomiScaled(size: 11, weight: .semibold))
                    .tracking(0.9)
                    .foregroundColor(CardPalette.accent)

                Spacer(minLength: 0)

                Text(isNow ? endTimeText(meeting) + " 结束" : countdown(meeting))
                    .font(.nomiScaled(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(CardPalette.subtle)
            }

            Text("\(timeText(meeting.start))  \(meeting.title)")
                .font(.nomiScaled(size: 20, weight: .semibold))
                .foregroundColor(CardPalette.ink)
                .lineLimit(2)

            Text(place.isEmpty ? prepareSummary(meeting) : place + " · " + prepareSummary(meeting))
                .font(.nomiScaled(size: 12.5))
                .foregroundColor(CardPalette.subtle)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        )
    }

    private var overviewCards: some View {
        HStack(spacing: 10) {
            overviewCard(label: "天气", value: weatherValue, detail: weatherDetail)
            overviewCard(label: "步数", value: stepsValue, detail: stepsDetail)
        }
    }

    private func overviewCard(label: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.nomiScaled(size: 11, weight: .medium))
                .foregroundColor(CardPalette.subtle)

            Text(value)
                .font(.nomiScaled(size: 22, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(CardPalette.ink)

            Text(detail)
                .font(.nomiScaled(size: 11.5))
                .foregroundColor(CardPalette.subtle)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardPalette.raised)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var weatherValue: String {
        guard let temperature = state.currentTemperature else { return "—" }
        return "\(Int(temperature.rounded()))°"
    }

    private var weatherDetail: String {
        guard state.currentTemperature != nil else { return "还没获取" }
        return "\(state.dayStatus.weatherText) · \(state.dayStatus.cityName)"
    }

    private var stepsValue: String {
        guard let steps = state.dayStatus.steps else { return "—" }
        return steps.formatted()
    }

    private var stepsDetail: String {
        guard let steps = state.dayStatus.steps else { return "还没数据" }
        let goal = max(1, state.dayStatus.stepGoal)
        let percent = min(999, Int(Double(steps) / Double(goal) * 100))
        return "目标 \(goal.formatted()) · \(percent)%"
    }

    private func countdown(_ meeting: MeetingItem) -> String {
        let seconds = meeting.start.timeIntervalSince(Date())
        let minutes = max(0, Int(seconds / 60))
        if minutes < 1 { return "马上" }
        if minutes < 60 { return "\(minutes) 分钟后" }
        return "\(minutes / 60) 小时后"
    }

    private func prepareSummary(_ meeting: MeetingItem) -> String {
        if meeting.location?.isEmpty == false {
            return "材料准备好再出发"
        }
        return "需要准备什么，可以问 Nomi"
    }

    // MARK: - 完整议程

    private var agendaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("完整议程")
                    .font(.nomiScaled(size: 15, weight: .semibold))
                    .foregroundColor(CardPalette.ink)

                Spacer()

                Text(state.meetings.isEmpty ? "空" : "\(state.meetings.count) 件")
                    .font(.nomiScaled(size: 12.5))
                    .foregroundColor(CardPalette.subtle)
            }

            VStack(spacing: 0) {
                if state.loading && state.meetings.isEmpty {
                    agendaLoading
                } else if state.meetings.isEmpty {
                    agendaEmpty
                } else {
                    ForEach(Array(state.meetings.enumerated()), id: \.element.id) { index, meeting in
                        agendaRow(meeting)

                        if index < state.meetings.count - 1 {
                            Rectangle()
                                .fill(CardPalette.line)
                                .frame(height: 0.5)
                                .padding(.leading, 74)
                                .padding(.trailing, 16)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            )
        }
    }

    private var agendaLoading: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(CardPalette.accent)

            Text("正在读取系统日历…")
                .font(.nomiScaled(size: 14))
                .foregroundColor(CardPalette.subtle)
        }
        .padding(18)
    }

    private var agendaEmpty: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                Image(systemName: state.dayStatus.hasCalendarAccess
                      ? "calendar.badge.checkmark"
                      : "calendar.badge.exclamationmark")
                    .font(.nomiScaled(size: 18, weight: .medium))
                    .foregroundColor(CardPalette.accent)

                Text(state.dayStatus.hasCalendarAccess
                     ? "今天没有安排"
                     : "看不到今天的安排")
                    .font(.nomiScaled(size: 17, weight: .semibold))
                    .foregroundColor(CardPalette.ink)
            }

            Text(state.dayStatus.hasCalendarAccess
                 ? "想加点什么，直接回 Nomi 说一句。"
                 : "没有日历权限，所以这里不会猜测或补造日程。")
                .font(.nomiScaled(size: 13))
                .foregroundColor(CardPalette.subtle)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if state.dayStatus.hasCalendarAccess {
                    onOpenAssistant()
                } else {
                    openSystemSettings()
                }
            } label: {
                HStack(spacing: 5) {
                    Text(state.dayStatus.hasCalendarAccess ? "告诉 Nomi" : "打开日历权限")
                    Image(systemName: "arrow.up.right")
                        .font(.nomiScaled(size: 11, weight: .semibold))
                }
                .font(.nomiScaled(size: 13, weight: .semibold))
                .foregroundColor(CardPalette.accent)
                .frame(minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
    }

    private func agendaRow(_ meeting: MeetingItem) -> some View {
        let now = Date()
        let end = meeting.end ?? meeting.start
        let isNow = meeting.start <= now && end > now
        let isNext = !isNow && meeting.id == upcomingMeeting?.id
        let isPast = end <= now
        let highlighted = meeting.id == highlightID || isNow || isNext
        let place = meeting.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(timeText(meeting.start))
                    .font(.nomiScaled(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(highlighted ? CardPalette.accent : CardPalette.ink)

                if let end = meeting.end {
                    Text(timeText(end))
                        .font(.nomiScaled(size: 11.5))
                        .monospacedDigit()
                        .foregroundColor(CardPalette.subtle)
                }
            }
            .frame(width: 48, alignment: .leading)

            Circle()
                .fill(highlighted ? CardPalette.accent : CardPalette.line)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.nomiScaled(size: 16, weight: isNow || isNext ? .semibold : .medium))
                    .foregroundColor(isPast ? CardPalette.subtle : CardPalette.ink)
                    .lineLimit(2)

                if !place.isEmpty {
                    Text(place)
                        .font(.nomiScaled(size: 12.5))
                        .foregroundColor(CardPalette.subtle)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if isNow {
                statusPill("进行中")
            } else if isNext && !place.isEmpty {
                Button("出发") {
                    openMaps(for: meeting)
                }
                .font(.nomiScaled(size: 12.5, weight: .semibold))
                .foregroundColor(CardPalette.accent)
                .frame(minWidth: 44, minHeight: 44)
                .buttonStyle(.plain)
                .accessibilityLabel("导航到 \(meeting.title)")
            } else if isNext {
                statusPill("接下来")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(highlighted ? CardPalette.raised.opacity(0.72) : Color.clear)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
        )
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.nomiScaled(size: 11.5, weight: .semibold))
            .foregroundColor(CardPalette.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(CardPalette.accent.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - 待办

    private var todoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("还没做完")
                    .font(.nomiScaled(size: 15, weight: .semibold))
                    .foregroundColor(CardPalette.ink)
                Spacer()
                Text("\(state.pendingTodos.count) 件")
                    .font(.nomiScaled(size: 12.5))
                    .foregroundColor(CardPalette.subtle)
            }

            VStack(spacing: 0) {
                ForEach(Array(state.pendingTodos.prefix(4))) { todo in
                    todoRow(todo)

                    if todo.id != state.pendingTodos.prefix(4).last?.id {
                        Rectangle()
                            .fill(CardPalette.line)
                            .frame(height: 0.5)
                            .padding(.leading, 50)
                            .padding(.trailing, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            )
        }
    }

    private func todoRow(_ todo: TodoItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                Task { _ = await state.completeTodo(id: todo.id) }
            } label: {
                Image(systemName: "circle")
                    .font(.nomiScaled(size: 19, weight: .regular))
                    .foregroundColor(CardPalette.accent)
                    .frame(width: 34, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("完成 \(todo.title)")

            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .font(.nomiScaled(size: 15, weight: .medium))
                    .foregroundColor(CardPalette.ink)
                    .lineLimit(2)

                if let due = todo.due {
                    Text(dueText(due))
                        .font(.nomiScaled(size: 12))
                        .foregroundColor(due < Date() ? CardPalette.amberInk : CardPalette.subtle)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 状态与回执

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.nomiScaled(size: 15, weight: .medium))
                .foregroundColor(CardPalette.amberInk)
                .padding(.top, 1)

            Text(message)
                .font(.nomiScaled(size: 12.5))
                .foregroundColor(CardPalette.amberInk)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(CardPalette.amberSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var sourceFooter: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "clock")
                .font(.nomiScaled(size: 11, weight: .medium))

            Text(sourceLine)
                .font(.nomiScaled(size: 11.5))
                .lineLimit(2)

            Spacer(minLength: 0)

            Button("刷新") {
                Task {
                    await state.refresh()
                    syncIsland()
                }
            }
            .font(.nomiScaled(size: 12, weight: .medium))
            .foregroundColor(CardPalette.accent)
            .buttonStyle(.plain)
        }
        .foregroundColor(CardPalette.subtle)
        .padding(.top, 2)
    }

    private var sourceLine: String {
        var parts: [String] = []
        parts.append(state.dayStatus.hasCalendarAccess ? "日程来自系统日历" : "没有日历权限")

        if state.currentTemperature != nil {
            parts.append("天气来自 Open-Meteo")
        } else {
            parts.append("天气暂未获取")
        }

        parts.append("更新于 \(freshnessText)")
        return parts.joined(separator: " · ")
    }

    private var freshnessText: String {
        let seconds = Date().timeIntervalSince(state.lastRefreshAt)
        guard seconds < 3600 else { return "较早" }
        if seconds < 90 { return "刚刚" }
        return "\(Int(seconds / 60)) 分钟前"
    }

    // MARK: - 日程计算

    private var currentMeeting: MeetingItem? {
        let now = Date()
        return state.meetings.first { meeting in
            meeting.start <= now && (meeting.end ?? meeting.start) > now
        }
    }

    private var upcomingMeeting: MeetingItem? {
        let now = Date()
        return state.meetings.first { $0.start > now }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func endTimeText(_ meeting: MeetingItem) -> String {
        guard let end = meeting.end else { return "今天" }
        return timeText(end)
    }

    private func dueText(_ date: Date) -> String {
        let calendar = Calendar.current
        if date < Date() { return "已过期" }
        if calendar.isDateInToday(date) { return "今天 \(timeText(date))" }
        if calendar.isDateInTomorrow(date) { return "明天" }
        return "过几天"
    }

    private func openMaps(for meeting: MeetingItem) {
        let query = meeting.location ?? meeting.title
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://maps.apple.com/?q=\(encoded)")
        else { return }

        UIApplication.shared.open(url)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// 今日页只把当前事件同步到锁屏；没有事件时不显示猜测内容。
    private func syncIsland() {
        guard let event = currentMeeting ?? upcomingMeeting else {
            PetActivityController.sync(mood: state.currentMood,
                                       glow: state.pet.look.glow,
                                       line: "今天没有安排",
                                       title: "在呢",
                                       phase: "idle",
                                       enabled: false)
            return
        }

        let seconds = event.start.timeIntervalSince(Date())
        let countdown: String
        let kind: String

        if seconds <= 0 {
            countdown = "进行中"
            kind = "now"
        } else {
            let minutes = Int(seconds / 60)
            countdown = minutes < 60 ? "\(minutes) 分钟后" : "\(minutes / 60) 小时后"
            kind = minutes <= 10 ? "soon" : "upcoming"
        }

        let time = [event.start, event.end]
            .compactMap { $0 }
            .map(timeText)
            .joined(separator: "–")

        PetActivityController.sync(mood: state.currentMood,
                                   glow: state.pet.look.glow,
                                   line: event.title,
                                   title: countdown,
                                   phase: "idle",
                                   eventTitle: event.title,
                                   eventPlace: event.location ?? "",
                                   eventTime: time,
                                   countdown: countdown,
                                   eventHint: "点开查看今天怎么走。",
                                   eventKind: kind,
                                   eventID: event.id,
                                   enabled: true)
    }

    // MARK: - 文案

    private static var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: Date())
    }
}
