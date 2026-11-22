import Combine
import SwiftUI
import UIKit

struct WorkspaceBriefSection: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: WhaleWorkspaceStore
    @EnvironmentObject private var todoStore: TodoTimelineStore
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var review = WorkspaceDailyReview(
        id: "",
        morningFocus: "",
        eveningNote: "",
        createdAt: Date(),
        updatedAt: Date()
    )
    @State private var morningFocus = ""
    @State private var eveningNote = ""

    private var pending: [TodoReminder] {
        todoStore.pending
    }

    private var completed: [TodoReminder] {
        todoStore.completed
    }

    private var upcoming: [CalendarEventPreview] {
        model.upcomingEvents
            .filter { $0.endAt > Date() }
            .sorted { $0.startAt < $1.startAt }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("\(greeting)，今天先看真实数据", systemImage: "sun.horizon.fill")
                        .whaleFont(size: 19, weight: .bold, design: .rounded)
                        .foregroundStyle(WhaleTheme.ink)
                    Spacer()
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
                Text("晨间简报来自系统日历和提醒事项；晚间复盘只统计真实完成与未完成的内容。")
                    .whaleFont(size: 13)
                    .foregroundStyle(WhaleTheme.muted)
                HStack(spacing: 0) {
                    briefMetric("\(upcoming.count)", label: "接下来", tint: WhaleTheme.accent)
                    briefDivider
                    briefMetric("\(pending.count)", label: "未完成", tint: WhaleTheme.coral)
                    briefDivider
                    briefMetric("\(completed.count)", label: "已完成", tint: WhaleTheme.success)
                }
                .padding(.top, 4)
            }
            .whaleCard(padding: 16)

            if isLoading && todoStore.items.isEmpty {
                ProgressView("正在读取真实日程与提醒…")
                    .frame(maxWidth: .infinity)
                    .whaleCard(padding: 18)
            }
            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle")
                    .whaleFont(size: 13)
                    .foregroundStyle(WhaleTheme.warm)
                    .whaleCard(padding: 14)
            }

            briefGroup(title: "接下来", icon: "calendar") {
                if upcoming.isEmpty {
                    Text("接下来 7 天没有系统日历安排。")
                        .whaleFont(size: 13)
                        .foregroundStyle(WhaleTheme.muted)
                } else {
                    ForEach(upcoming) { event in
                        HStack(alignment: .top, spacing: 9) {
                            Text(event.startAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                                .whaleFont(size: 12, weight: .semibold)
                                .foregroundStyle(WhaleTheme.accent)
                                .frame(width: 72, alignment: .leading)
                            Text(event.title)
                                .whaleFont(size: 14, weight: .medium)
                                .foregroundStyle(WhaleTheme.ink)
                            Spacer()
                        }
                    }
                }
            }

            briefGroup(title: "未完成", icon: "circle.dashed") {
                if pending.isEmpty {
                    Text("系统提醒事项中没有未完成事项。")
                        .whaleFont(size: 13)
                        .foregroundStyle(WhaleTheme.muted)
                } else {
                    ForEach(pending.prefix(6)) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(WhaleTheme.coral)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .whaleFont(size: 14, weight: .medium)
                                    .foregroundStyle(WhaleTheme.ink)
                                if let due = item.dueAt {
                                    Text(due.formatted(.dateTime.month().day().hour().minute()))
                                        .whaleFont(size: 11)
                                        .foregroundStyle(WhaleTheme.muted)
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }

            briefGroup(title: "早晨写一句", icon: "pencil.line") {
                TextEditor(text: $morningFocus)
                    .frame(minHeight: 82)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(WhaleTheme.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("这里只记录你的今日重点，不会自动改任务优先级。")
                    .whaleFont(size: 11)
                    .foregroundStyle(WhaleTheme.muted)
            }

            briefGroup(title: "晚间复盘", icon: "moon.stars") {
                if completed.isEmpty && pending.isEmpty {
                    Text("今天没有可核对的提醒事项。")
                        .whaleFont(size: 13)
                        .foregroundStyle(WhaleTheme.muted)
                } else {
                    Text("已完成 \(completed.count) 项 · 未完成 \(pending.count) 项")
                        .whaleFont(size: 14, weight: .semibold)
                        .foregroundStyle(WhaleTheme.ink)
                }
                TextEditor(text: $eveningNote)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(WhaleTheme.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button {
                    store.saveReview(review, morningFocus: morningFocus, eveningNote: eveningNote)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label("保存今日复盘", systemImage: "checkmark.circle.fill")
                        .whaleFont(size: 13, weight: .semibold)
                        .foregroundStyle(WhaleTheme.onAccent)
                        .padding(.horizontal, 13)
                        .frame(minHeight: 38)
                        .background(WhaleTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .whaleWorkspaceBriefRefresh)) { _ in
            Task { await load() }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 11 { return "早上好" }
        if hour < 18 { return "下午好" }
        return "晚上好"
    }

    private func load() async {
        guard !isLoading else { return }
#if DEBUG
        if TodoDemoMode.isSyncFixture { return }
#endif
        isLoading = true
        errorText = nil
        let current = store.review()
        review = current
        morningFocus = current.morningFocus
        eveningNote = current.eveningNote
        do {
            let reminders = try await model.loadTodoReminders(includeCompleted: true)
            todoStore.replaceLoaded(reminders)
            todoStore.markLoaded()
        } catch {
            errorText = error.localizedDescription
        }
        await model.refreshDashboard(force: true)
        isLoading = false
    }

    private func briefMetric(_ value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .whaleFont(size: 23, weight: .bold, design: .rounded)
                .foregroundStyle(tint)
            Text(label)
                .whaleFont(size: 11, weight: .medium)
                .foregroundStyle(WhaleTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var briefDivider: some View {
        Rectangle()
            .fill(WhaleTheme.line)
            .frame(width: 0.5, height: 32)
    }

    private func briefGroup<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .whaleFont(size: 14, weight: .bold)
                .foregroundStyle(WhaleTheme.accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .whaleCard(padding: 14)
    }
}

