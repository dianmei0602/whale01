import SwiftUI
import Foundation

/// 「日程」页：今天的时间轴 + 新增日程（带提醒）。
struct ScheduleView: View {
    @Environment(AppState.self) private var state

    @State private var showAdd = false
    @State private var newTitle = ""
    @State private var newTime = Date()
    @State private var remindMinutes = 10
    @State private var busy = false
    @State private var toast: String?

    private let cyan = CardPalette.accent

    private var sortedMeetings: [MeetingItem] {
        state.meetings.sorted { $0.start < $1.start }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if sortedMeetings.isEmpty {
                emptyState
            } else {
                timeline
            }

            Spacer(minLength: 0)

            reminderCenter
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(background)
        .sheet(isPresented: $showAdd) { addSheet }
        .overlay(alignment: .bottom) { toastView }
    }

    private var background: some View {
        AppBackground()
    }

    // MARK: - 头

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("日程")
                    .font(.nomiScaled(size: 31.5, weight: .bold))
                    .foregroundColor(CardPalette.ink)

                Spacer()

                Button {
                    newTitle = ""
                    newTime = nextHour()
                    remindMinutes = 10
                    showAdd = true
                } label: {
                    Text("＋ 新增")
                        .font(.nomiScaled(size: 14.5, weight: .medium))
                        .foregroundColor(CardPalette.ink)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(CardPalette.raised)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(CardPalette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Text(subtitle)
                .font(.nomiScaled(size: 14))
                .foregroundColor(CardPalette.subtle)
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var subtitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: Date()) + " · \(sortedMeetings.count) 个安排"
    }

    // MARK: - 时间轴

    private var timeline: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sortedMeetings) { meeting in
                    row(meeting)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
    }

    private func row(_ meeting: MeetingItem) -> some View {
        let isNow = abs(meeting.start.timeIntervalSinceNow) < 45 * 60

        return HStack(alignment: .top, spacing: 12) {
            Text(timeText(meeting.start))
                .font(.nomiScaled(size: 14, weight: .medium))
                .foregroundColor(isNow ? cyan : CardPalette.subtle)
                .frame(width: 46, alignment: .trailing)
                .padding(.top, 12)

            VStack(spacing: 0) {
                Circle()
                    .fill(isNow ? cyan : Color.white.opacity(0.16))
                    .frame(width: 7, height: 7)
                    .padding(.top, 15)
                Rectangle()
                    .fill(CardPalette.line)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.nomiScaled(size: 16, weight: .semibold))
                    .foregroundColor(CardPalette.ink)

                Text(detailText(meeting))
                    .font(.nomiScaled(size: 13.5))
                    .foregroundColor(CardPalette.subtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(isNow ? cyan.opacity(0.07) : CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isNow ? cyan.opacity(0.30) : CardPalette.line, lineWidth: 1)
            )
            .padding(.bottom, 10)
        }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func detailText(_ meeting: MeetingItem) -> String {
        var parts: [String] = []
        if let location = meeting.location, !location.isEmpty {
            parts.append(location)
        }
        if meeting.isAllDay {
            parts.append("全天")
        } else {
            let minutes = Int(meeting.start.timeIntervalSinceNow / 60)
            if minutes > 0 {
                parts.append("还有 \(minutes / 60) 小时 \(minutes % 60) 分")
            } else if minutes > -60 {
                parts.append("正在进行")
            }
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.nomiScaled(size: 25.5))
                .foregroundColor(cyan)
                .frame(width: 54, height: 54)
                .background(cyan.opacity(0.12))
                .clipShape(Circle())

            Text("今天没有安排。")
                .font(.nomiScaled(size: 17.5, weight: .semibold))
                .foregroundColor(CardPalette.ink)

            Text("点右上角「＋ 新增」加一个")
                .font(.nomiScaled(size: 14))
                .foregroundColor(CardPalette.subtle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 提醒中心

    private var reminderCenter: some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.fill")
                .font(.nomiScaled(size: 15))
                .foregroundColor(Color(red: 1.00, green: 0.74, blue: 0.38))

            VStack(alignment: .leading, spacing: 2) {
                Text("提醒中心")
                    .font(.nomiScaled(size: 14.5, weight: .semibold))
                    .foregroundColor(CardPalette.ink)
                Text("新增日程时设的提醒，会交给系统日历弹出")
                    .font(.nomiScaled(size: 12))
                    .foregroundColor(CardPalette.subtle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        )
    }

    // MARK: - 新增弹层

    private var addSheet: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("例如 方案评审", text: $newTitle)
                }

                Section("时间") {
                    DatePicker("开始", selection: $newTime, displayedComponents: [.hourAndMinute])
                }

                Section("提醒") {
                    Picker("提前", selection: $remindMinutes) {
                        Text("不提醒").tag(0)
                        Text("10 分钟").tag(10)
                        Text("30 分钟").tag(30)
                        Text("1 小时").tag(60)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Text("会写进系统日历，并交给日历 App 提醒。")
                        .font(.nomiScaled(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CardPalette.screen)
            .navigationTitle("新增日程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showAdd = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "保存中…" : "添加") {
                        Task { await save() }
                    }
                    .disabled(busy || newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var toastView: some View {
        Group {
            if let toast = toast {
                Text(toast)
                    .font(.nomiScaled(size: 14))
                    .foregroundColor(Color(red: 0.87, green: 0.96, blue: 1.00))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Color(red: 0.07, green: 0.11, blue: 0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(cyan.opacity(0.32), lineWidth: 1)
                    )
                    .padding(.bottom, 90)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - 动作

    private func nextHour() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: Date())
        components.hour = (components.hour ?? 0) + 1
        return calendar.date(from: components) ?? Date()
    }

    private func save() async {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        busy = true
        defer { busy = false }

        let ok = await CalendarService.addEvent(title: title,
                                                start: newTime,
                                                alarmMinutes: remindMinutes)

        if ok {
            showAdd = false
            await state.refresh()

            if remindMinutes > 0 {
                let remindAt = newTime.addingTimeInterval(TimeInterval(-remindMinutes * 60))
                showToast("已添加 · \(timeText(remindAt)) 提醒你")
            } else {
                showToast("已添加 · 不提醒")
            }
        } else {
            showToast("没写进日历，检查一下授权")
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = text }
        Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) { toast = nil }
            }
        }
    }
}
