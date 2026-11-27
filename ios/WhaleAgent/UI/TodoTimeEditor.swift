import SwiftUI

struct TodoTimeEditor: View {
    let originalTitle: String
    let availableLists: [String]
    let onAdd: (String, String?, Date?, String?) async throws -> TodoReminder

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var title = ""
    @State private var notes = ""
    @State private var includesReminder = true
    @State private var due = Date().addingTimeInterval(3_600)
    @State private var selectedListName: String?
    @State private var saving = false
    @State private var error: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case notes
    }

    private var cleanedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            WhaleBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    editorSection(title: "任务标题", systemImage: "text.cursor") {
                        TextField("准备完成什么？", text: $title, axis: .vertical)
                            .whaleFont(size: 17, weight: .medium)
                            .foregroundStyle(WhaleTheme.ink)
                            .lineLimit(1...3)
                            .focused($focusedField, equals: .title)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .notes }
                            .accessibilityIdentifier("todo-task-title")
                    }

                    editorSection(title: "描述", systemImage: "text.alignleft") {
                        ZStack(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("补充背景、步骤或要带的东西")
                                    .whaleFont(size: 15)
                                    .foregroundStyle(WhaleTheme.muted.opacity(0.72))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $notes)
                                .whaleFont(size: 15)
                                .foregroundStyle(WhaleTheme.ink)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 96)
                                .focused($focusedField, equals: .notes)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $includesReminder.animation(
                            reduceMotion ? nil : .easeOut(duration: 0.16)
                        )) {
                            Label("设置提醒时间", systemImage: "clock")
                                .whaleFont(size: 16, weight: .semibold)
                                .foregroundStyle(WhaleTheme.ink)
                        }
                        .tint(WhaleTheme.accent)

                        if includesReminder {
                            Divider().overlay(WhaleTheme.line)
                            HStack(spacing: 10) {
                                DatePicker(
                                    "日期",
                                    selection: $due,
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)

                                DatePicker(
                                    "时间",
                                    selection: $due,
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)

                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .whaleCard(padding: 16)

                    HStack(spacing: 12) {
                        Label("提醒列表", systemImage: "folder")
                            .whaleFont(size: 16, weight: .semibold)
                            .foregroundStyle(WhaleTheme.ink)
                        Spacer(minLength: 8)
                        Picker("提醒列表", selection: $selectedListName) {
                            Text("系统默认").tag(String?.none)
                            ForEach(availableLists, id: \.self) { list in
                                Text(list).tag(Optional(list))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(WhaleTheme.accent)
                    }
                    .whaleCard(padding: 16)

                    Label("任务会写入系统提醒事项；之后仍可在这里勾选、恢复或删除。", systemImage: "checklist")
                        .whaleFont(size: 13)
                        .foregroundStyle(WhaleTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)

                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .whaleFont(size: 13, weight: .medium)
                            .foregroundStyle(WhaleTheme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 112)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            createButton
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
        }
        .onAppear {
            title = originalTitle
            focusedField = originalTitle.isEmpty ? .title : nil
        }
        .accessibilityIdentifier("todo-task-editor")
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WhaleTheme.ink)
                    .whaleGlassCircle(size: 44)
            }
            .buttonStyle(.whalePress)
            .disabled(saving)
            .accessibilityLabel("取消新建任务")

            VStack(alignment: .leading, spacing: 3) {
                Text("新建任务")
                    .whaleFont(size: 28, weight: .bold, design: .rounded)
                    .foregroundStyle(WhaleTheme.ink)
                Text(Date.now.formatted(.dateTime.month().day().weekday(.wide)))
                    .whaleFont(size: 13, weight: .medium)
                    .foregroundStyle(WhaleTheme.muted)
            }

            Spacer(minLength: 0)
        }
    }

    private func editorSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .whaleFont(size: 14, weight: .semibold)
                .foregroundStyle(WhaleTheme.muted)
            content()
        }
        .whaleCard(padding: 16)
    }

    private var createButton: some View {
        Button {
            save()
        } label: {
            HStack(spacing: 9) {
                if saving {
                    ProgressView()
                        .tint(Color(uiColor: .systemBackground))
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                }
                Text(saving ? "正在创建" : "创建任务")
                    .whaleFont(size: 16, weight: .semibold)
            }
            .foregroundStyle(Color(uiColor: .systemBackground))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(Color.primary, in: Capsule())
        }
        .buttonStyle(.whalePress)
        .disabled(saving || cleanedTitle.isEmpty)
        .opacity(cleanedTitle.isEmpty ? 0.5 : 1)
        .accessibilityIdentifier("todo-create-task")
    }

    private func save() {
        guard !cleanedTitle.isEmpty, !saving else { return }
        focusedField = nil
        saving = true
        error = nil
        Task {
            defer { saving = false }
            do {
                let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                _ = try await onAdd(
                    cleanedTitle,
                    cleanNotes.isEmpty ? nil : cleanNotes,
                    includesReminder ? due : nil,
                    selectedListName
                )
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
