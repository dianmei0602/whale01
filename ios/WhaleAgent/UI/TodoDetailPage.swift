import SwiftUI

struct TodoDetailPage: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var todoStore: TodoTimelineStore
    @Environment(\.dismiss) private var dismiss

    @State private var current: TodoReminder
    @State private var project: String
    @State private var priority: Int
    @State private var isBusy = false
    @State private var errorText: String?
    @State private var confirmDelete = false

    init(item: TodoReminder, model: AppModel) {
        _model = ObservedObject(wrappedValue: model)
        _current = State(initialValue: item)
        _project = State(initialValue: item.projectName ?? "")
        _priority = State(initialValue: item.priority)
    }

    var body: some View {
        Form {
            Section("任务") {
                Text(current.title)
                    .font(.headline)
                LabeledContent(
                    "状态",
                    value: current.completed ? "已完成" : "待办"
                )
                LabeledContent("系统列表", value: current.listName)
            }

            Section("本地组织") {
                TextField("项目", text: $project)
                Picker("优先级", selection: $priority) {
                    Text("高").tag(1)
                    Text("普通").tag(2)
                    Text("低").tag(3)
                }
                Button("保存项目与优先级") {
                    model.updateTodoMetadata(
                        current,
                        project: project,
                        priority: priority
                    )
                    todoStore.upsert(current)
                    dismiss()
                }
            }

            if let errorText {
                Section {
                    Label(
                        errorText,
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(WhaleTheme.warm)
                }
            }

            Section {
                Button(current.completed ? "恢复为待办" : "标记完成") {
                    Task { await toggleCompletion() }
                }
                .disabled(isBusy)

                Button("删除待办", role: .destructive) {
                    confirmDelete = true
                }
                .disabled(isBusy)
            }
        }
        .scrollContentBackground(.hidden)
        .background(WhaleBackdrop())
        .alert("删除这条待办？", isPresented: $confirmDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task { await deleteCurrent() }
            }
        } message: {
            Text(current.title)
        }
    }

    @MainActor
    private func toggleCompletion() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            current = try await model.setTodoReminder(
                current,
                completed: !current.completed
            )
            todoStore.upsert(current)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func deleteCurrent() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await model.deleteTodoReminder(current)
            todoStore.remove(id: current.id)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
