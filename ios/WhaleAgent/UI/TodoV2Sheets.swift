import SwiftUI

struct TodoDetailSheet: View {
    @ObservedObject var model: AppModel
    let onChanged: (TodoReminder?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var current: TodoReminder
    @State private var project: String
    @State private var priority: Int
    @State private var candidates: [TodoScheduleCandidate] = []
    @State private var isBusy = false
    @State private var errorText: String?
    @State private var confirmDelete = false

    init(item: TodoReminder, model: AppModel, onChanged: @escaping (TodoReminder?) -> Void) {
        _model = ObservedObject(wrappedValue: model)
        self.onChanged = onChanged
        _current = State(initialValue: item)
        _project = State(initialValue: item.projectName ?? "")
        _priority = State(initialValue: item.priority)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务") {
                    Text(current.title)
                        .font(.headline)
                    LabeledContent("状态", value: current.completed ? "已完成" : "待办")
                    LabeledContent("系统列表", value: current.listName)
                }

                Section("本地组织") {
                    TextField("项目，例如 鲸鱼 2.0", text: $project)
                    Picker("优先级", selection: $priority) {
                        Text("高").tag(1)
                        Text("普通").tag(2)
                        Text("低").tag(3)
                    }
                    if let minutes = current.estimatedMinutes {
                        LabeledContent("预计时长", value: "\(minutes) 分钟")
                    }
                    Button("保存项目与优先级") {
                        model.updateTodoMetadata(
                            current,
                            project: project,
                            priority: priority
                        )
                        onChanged(current)
                        dismiss()
                    }
                }

                Section("安排") {
                    if current.dueAt != nil {
                        ForEach(candidates.prefix(3)) { candidate in
                            Button {
                                Task { await apply(candidate) }
                            } label: {
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(candidate.start.formatted(.dateTime.hour().minute()))
                                            .font(.body.weight(.semibold))
                                        Text("到 \(candidate.end.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(WhaleTheme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right.circle")
                                }
                            }
                        }
                    } else {
                        Text("当前在收件箱，可先设置时间。")
                            .foregroundStyle(WhaleTheme.muted)
                    }
                    Button("智能排期") { Task { await loadCandidates() } }
                    Button("移入收件箱") { Task { await moveToInbox() } }
                        .disabled(isBusy)
                }

                if let errorText {
                    Section {
                        Label(errorText, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(WhaleTheme.warm)
                    }
                }

                Section {
                    Button(current.completed ? "恢复为待办" : "标记完成") {
                        Task { await toggleCompletion() }
                    }
                    .disabled(isBusy)
                    Button("删除待办", role: .destructive) { confirmDelete = true }
                        .disabled(isBusy)
                }
            }
            .scrollContentBackground(.hidden)
            .background(WhaleBackdrop())
            .tint(WhaleTheme.accent)
            .navigationTitle("待办详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task {
                if current.dueAt != nil { await loadCandidates() }
            }
            .alert("删除这条待办？", isPresented: $confirmDelete) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) { Task { await deleteCurrent() } }
            } message: {
                Text(current.title)
            }
        }
    }

    private func loadCandidates() async {
        if model.upcomingEvents.isEmpty {
            await model.refreshDashboard(force: true)
        }
        candidates = TodoSchedulePlanner.candidates(for: current, events: model.upcomingEvents)
        if candidates.isEmpty {
            errorText = "今天没有找到合适的空档，可以减少预计时长或选择其他日期。"
        } else {
            errorText = nil
        }
    }

    private func apply(_ candidate: TodoScheduleCandidate) async {
        isBusy = true
        defer { isBusy = false }
        do {
            current = try await model.rescheduleTodoReminder(current, dueAt: candidate.start)
            onChanged(current)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func moveToInbox() async {
        isBusy = true
        defer { isBusy = false }
        do {
            current = try await model.rescheduleTodoReminder(current, dueAt: nil)
            onChanged(current)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func toggleCompletion() async {
        isBusy = true
        defer { isBusy = false }
        do {
            current = try await model.setTodoReminder(current, completed: !current.completed)
            onChanged(current)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func deleteCurrent() async {
        isBusy = true
        do {
            try await model.deleteTodoReminder(current)
            onChanged(nil)
            dismiss()
        } catch {
            errorText = error.localizedDescription
            isBusy = false
        }
    }
}

struct TodoScheduleSheet: View {
    let item: TodoReminder
    @ObservedObject var model: AppModel
    let onChanged: (TodoReminder?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [TodoScheduleCandidate] = []
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.title)
                            .font(.headline)
                        Text("读取真实日历后给出候选空档；点选后才写入提醒时间。")
                            .font(.subheadline)
                            .foregroundStyle(WhaleTheme.muted)
                    }
                    .padding(.vertical, 4)
                }

                Section("候选空档") {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("正在核对日历…")
                        }
                    } else if candidates.isEmpty {
                        Text(errorText ?? "今天没有找到合适空档。")
                            .foregroundStyle(WhaleTheme.muted)
                    } else {
                        ForEach(candidates) { candidate in
                            Button {
                                Task { await apply(candidate) }
                            } label: {
                                HStack {
                                    Image(systemName: "clock.badge.checkmark")
                                        .foregroundStyle(WhaleTheme.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(candidate.start.formatted(.dateTime.hour().minute()))
                                            .font(.body.weight(.semibold))
                                        Text("至 \(candidate.end.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(WhaleTheme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(WhaleTheme.accent)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button("移入收件箱", systemImage: "tray.and.arrow.down") {
                        Task { await moveToInbox() }
                    }
                    Button("重新查找", systemImage: "arrow.clockwise") {
                        Task { await loadCandidates() }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(WhaleBackdrop())
            .tint(WhaleTheme.accent)
            .navigationTitle("智能排期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .task { await loadCandidates() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func loadCandidates() async {
        isLoading = true
        errorText = nil
        if model.upcomingEvents.isEmpty {
            await model.refreshDashboard(force: true)
        }
        candidates = TodoSchedulePlanner.candidates(for: item, events: model.upcomingEvents)
        isLoading = false
    }

    private func apply(_ candidate: TodoScheduleCandidate) async {
        do {
            let updated = try await model.rescheduleTodoReminder(item, dueAt: candidate.start)
            onChanged(updated)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func moveToInbox() async {
        do {
            let updated = try await model.rescheduleTodoReminder(item, dueAt: nil)
            onChanged(updated)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct TodoFromMessageSheet: View {
    let candidate: MessageTodoCandidate
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var dueAt: Date?
    @State private var project = ""
    @State private var estimatedMinutes = 30
    @State private var errorText: String?
    @State private var isSaving = false

    init(candidate: MessageTodoCandidate, model: AppModel) {
        self.candidate = candidate
        _model = ObservedObject(wrappedValue: model)
        let compact = candidate.text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = TodoQuickParser.parsePreview(String(compact.prefix(120)))
        _title = State(initialValue: parsed.title)
        _dueAt = State(initialValue: parsed.dueAt)
        _project = State(initialValue: parsed.project ?? "")
        _estimatedMinutes = State(initialValue: parsed.estimatedMinutes ?? 30)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    OperationPreviewCard(operationPreview) { EmptyView() }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section("预览") {
                    TextField("待办标题", text: $title, axis: .vertical)
                        .lineLimit(2...5)
                    if let currentDue = dueAt {
                        DatePicker(
                            "截止时间",
                            selection: Binding(
                                get: { self.dueAt ?? currentDue },
                                set: { self.dueAt = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        Button("移入收件箱", role: .destructive) { self.dueAt = nil }
                    } else {
                        Button("设置截止时间") {
                            self.dueAt = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
                        }
                    }
                    TextField("项目", text: $project)
                    Stepper("预计 \(estimatedMinutes) 分钟", value: $estimatedMinutes, in: 5...240, step: 5)
                }
                Section {
                    Text("确认后才会写入系统提醒事项。原回答不会被修改。")
                        .font(.footnote)
                        .foregroundStyle(WhaleTheme.muted)
                }
                if let errorText {
                    Section {
                        Label(errorText, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(WhaleTheme.warm)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(WhaleBackdrop())
            .tint(WhaleTheme.accent)
            .navigationTitle("转为待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中…" : "确认添加") {
                        Task { await save() }
                    }
                    .disabled(
                        isSaving
                            || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func save() async {
        isSaving = true
        errorText = nil
        defer { isSaving = false }
        do {
            let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try await model.createTodoReminder(
                title: cleanedTitle,
                dueAt: dueAt,
                project: project,
                estimatedMinutes: estimatedMinutes
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private var operationPreview: OperationPreview {
        OperationPreview.todo(
            TodoQuickPreview(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                dueAt: dueAt,
                project: project.trimmingCharacters(in: .whitespacesAndNewlines),
                estimatedMinutes: estimatedMinutes,
                originalText: candidate.text
            )
        )
    }
}
