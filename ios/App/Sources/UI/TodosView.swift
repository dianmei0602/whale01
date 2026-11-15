import SwiftUI

/// 全部待办：按 今天 / 明天 / 以后 / 没定时间 分组。
///
/// 勾掉会写回系统「提醒事项」；本页只是另一个入口，不存第二份数据。
/// 完成后先保留 1.2 秒「已完成」回执，避免状态突然消失。
struct TodosView: View {

    @Environment(\.dismiss) private var dismiss
    /// 由调用方显式传入，避免 sheet 里拿不到环境对象
    var state: AppState

    /// 刚点完成、还在等写回的那几条
    @State private var doneIDs: Set<String> = []
    @State private var errorText: String?

    private var groups: [TodoGroup] {
        TodoGrouper.group(state.pendingTodos)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let errorText {
                        banner(errorText)
                    }

                    if groups.isEmpty {
                        emptyState
                    } else {
                        ForEach(groups) { group in
                            groupSection(group)
                        }
                    }

                    sourceLine
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
            .background(CardPalette.screen)
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .font(.nomiScaled(size: 15, weight: .semibold))
                        .foregroundColor(CardPalette.accent)
                }
            }
        }
    }

    private var titleText: String {
        state.pendingTodos.isEmpty ? "待办" : "待办 \(state.pendingTodos.count)"
    }

    // MARK: - 分组

    private func groupSection(_ group: TodoGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.title)
                .font(.nomiScaled(size: 12, weight: .semibold))
                .foregroundColor(CardPalette.subtle)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(group.items) { todo in
                    row(todo)
                    if todo.id != group.items.last?.id {
                        Rectangle()
                            .fill(CardPalette.line)
                            .frame(height: 0.5)
                            .padding(.leading, 44)
                    }
                }
            }
            .background(CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            )
        }
    }

    // MARK: - 一行

    private func row(_ todo: TodoItem) -> some View {
        let done = doneIDs.contains(todo.id)
        let overdue = TodoGrouper.isOverdue(todo.due)

        return HStack(alignment: .top, spacing: 12) {
            Button {
                complete(todo)
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.nomiScaled(size: 20))
                    .foregroundColor(done ? CardPalette.accent : CardPalette.accent.opacity(overdue ? 0.9 : 0.75))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "已完成 \(todo.title)" : "完成 \(todo.title)")

            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .font(.nomiScaled(size: 15, weight: .medium))
                    .foregroundColor(done ? CardPalette.subtle : CardPalette.ink)
                    .strikethrough(done, color: CardPalette.subtle)
                    .lineLimit(2)

                if done {
                    Text("已完成 ✓")
                        .font(.nomiScaled(size: 11.5, weight: .semibold))
                        .foregroundColor(CardPalette.accent)
                } else if let text = TodoGrouper.dueText(todo.due) {
                    Text(text)
                        .font(.nomiScaled(size: 11.5))
                        .foregroundColor(overdue ? CardPalette.amberInk : CardPalette.subtle)
                }
            }

            Spacer(minLength: 0)

            if !done {
                Menu {
                    Button("改到明天 9:00") { reschedule(todo, toDaysFromNow: 1) }
                    Button("改到后天 9:00") { reschedule(todo, toDaysFromNow: 2) }
                    Button("改到下周一 9:00") { rescheduleToNextMonday(todo) }
                    Divider()
                    Button("删除这条", role: .destructive) { remove(todo) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.nomiScaled(size: 14, weight: .semibold))
                        .foregroundColor(CardPalette.subtle)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("更多：\(todo.title)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - 动作

    private func complete(_ todo: TodoItem) {
        errorText = nil
        withAnimation(.easeOut(duration: 0.15)) {
            _ = doneIDs.insert(todo.id)
        }

        Task { @MainActor in
            let ok = await state.completeTodo(id: todo.id)

            if !ok {
                // 写不回去就把 UI 恢复原样，不假装完成
                withAnimation(.easeOut(duration: 0.15)) {
                    _ = doneIDs.remove(todo.id)
                }
                errorText = "这条没写回去——提醒事项权限可能没开。"
                return
            }

            // 留一下回执再让它消失
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeOut(duration: 0.2)) {
                _ = doneIDs.remove(todo.id)
            }
        }
    }

    private func reschedule(_ todo: TodoItem, toDaysFromNow days: Int) {
        guard let target = atNine(daysFromNow: days) else { return }
        applyReschedule(todo, to: target)
    }

    private func rescheduleToNextMonday(_ todo: TodoItem) {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        let now = Date()
        var components = DateComponents()
        components.weekday = 2   // 周一
        guard let next = calendar.nextDate(after: now,
                                           matching: components,
                                           matchingPolicy: .nextTime) else { return }
        var target = calendar.startOfDay(for: next)
        target = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: target) ?? target
        applyReschedule(todo, to: target)
    }

    private func atNine(daysFromNow days: Int) -> Date? {
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: days, to: Date()) else { return nil }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)
    }

    private func applyReschedule(_ todo: TodoItem, to date: Date) {
        errorText = nil
        Task { @MainActor in
            let ok = await state.rescheduleTodo(id: todo.id, due: date)
            if !ok {
                errorText = "改时间没成功，提醒事项权限可能没开。"
            }
        }
    }

    private func remove(_ todo: TodoItem) {
        errorText = nil
        Task { @MainActor in
            let ok = await state.deleteTodo(id: todo.id)
            if !ok {
                errorText = "删除没成功，提醒事项权限可能没开。"
            }
        }
    }

    // MARK: - 零件

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("没有待办")
                .font(.nomiScaled(size: 17, weight: .semibold))
                .foregroundColor(CardPalette.ink)

            Text("想加点什么，回 Nomi 说一句「加个待办…」就行。")
                .font(.nomiScaled(size: 12.5))
                .foregroundColor(CardPalette.subtle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func banner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.nomiScaled(size: 13))
                .foregroundColor(CardPalette.amberInk)

            Text(text)
                .font(.nomiScaled(size: 12.5))
                .foregroundColor(CardPalette.amberInk)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(CardPalette.amberSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var sourceLine: some View {
        Text(state.dayStatus.hasReminderAccess
             ? "数据来自系统「提醒事项」，勾选会同步回去"
             : "没有提醒事项权限，所以这里是空的")
            .font(.nomiScaled(size: 11))
            .foregroundColor(CardPalette.subtle.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }
}
