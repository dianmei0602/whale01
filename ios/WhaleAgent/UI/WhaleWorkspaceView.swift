import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct WhaleWorkspaceView: View {
    @ObservedObject var model: AppModel
    var embedded: Bool = false

    @StateObject private var store = WhaleWorkspaceStore.shared
    @EnvironmentObject private var todoStore: TodoTimelineStore
    @EnvironmentObject private var navigation: RootNavigationModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var surface: WhaleWorkspaceSurface = .todos
    @State private var sheet: WorkspaceSheet?
    @State private var toast: String?
    @State private var taskDraft = ""
    @State private var taskError: String?
    @State private var taskLoading = false
    @State private var taskSubmitting = false
    @State private var busyTaskIds: Set<String> = []

    var body: some View {
        Group {
            if embedded {
                workspaceContent
            } else {
                NavigationStack {
                    workspaceContent
                        .navigationTitle("鲸鱼工作台")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") { dismiss() }
                            }
                        }
                }
            }
        }
        .tint(WhaleTheme.accent)
        .sheet(item: $sheet) { destination in
            switch destination {
            case .captureEditor:
                WorkspaceCaptureEditor(store: store)
            case .captureDetail(let id):
                if let item = store.captures.first(where: { $0.id == id }) {
                    WorkspaceCaptureDetailSheet(
                        item: item,
                        store: store,
                        onShowToast: showToast
                    )
                }
            }
        }
    }

    private var workspaceContent: some View {
        ZStack(alignment: .top) {
            WhaleBackdrop().ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        workspaceIdentity
                            .id("workspace-surface-top")
                        surfaceSelector
                        if let issue = store.loadIssue {
                            Label(issue, systemImage: "exclamationmark.triangle")
                                .whaleFont(size: 13)
                                .foregroundStyle(WhaleTheme.warm)
                                .fixedSize(horizontal: false, vertical: true)
                                .whaleCard(padding: 13)
                        }
                        surfaceContent
                    }
                    .padding(.horizontal, WhaleTheme.pagePadding)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    await refreshCurrentSurface()
                }
                .onChange(of: surface) { _, _ in
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        proxy.scrollTo("workspace-surface-top", anchor: .top)
                    }
                }
            }
            .task {
                await loadTaskOverview()
            }
            .onChange(of: model.permissionsSnapshot) { _, _ in
                Task { await loadTaskOverview(silent: true) }
            }

            if let toast {
                Text(toast)
                    .whaleFont(size: 13, weight: .semibold)
                    .foregroundStyle(WhaleTheme.ink)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(WhaleTheme.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(WhaleTheme.line, lineWidth: 0.8))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var workspaceIdentity: some View {
        HStack(spacing: 10) {
            WhaleMarkView(size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("工作台")
                    .whaleFont(size: 22, weight: .bold, design: .rounded)
                    .foregroundStyle(WhaleTheme.ink)
                Text("待办 · 记事 · 晨晚报")
                    .whaleFont(size: 12)
                    .foregroundStyle(WhaleTheme.muted)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("workspace-title")
    }

    private var surfaceSelector: some View {
        HStack(spacing: 6) {
            ForEach(WhaleWorkspaceSurface.allCases) { item in
                let selected = surface == item
                Button {
                    guard surface != item else { return }
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        surface = item
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(item.title)
                            .whaleFont(size: 13, weight: .semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selected ? WhaleTheme.onAccent : WhaleTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        selected ? WhaleTheme.accent : WhaleTheme.card,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                selected ? Color.clear : WhaleTheme.line,
                                lineWidth: 0.7
                            )
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.whalePress)
                .accessibilityLabel(item.title)
                .accessibilityIdentifier(item.accessibilityIdentifier)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private var surfaceContent: some View {
        switch surface {
        case .todos:
            todosSection
        case .notes:
            notesSection
        case .brief:
            WorkspaceBriefSection(model: model, store: store)
        }
    }

    private func refreshCurrentSurface() async {
        switch surface {
        case .todos:
            await loadTaskOverview(silent: true)
        case .notes:
            return
        case .brief:
            NotificationCenter.default.post(name: .whaleWorkspaceBriefRefresh, object: nil)
        }
    }

    // MARK: - Todos

    private var pendingTasks: [TodoReminder] {
        todoStore.pending
    }

    private var completedTaskCount: Int {
        todoStore.completed.count
    }

    private var todosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("待办", systemImage: "checklist")
                    .whaleFont(size: 18, weight: .bold, design: .rounded)
                    .foregroundStyle(WhaleTheme.ink)
                if !pendingTasks.isEmpty {
                    Text("\(pendingTasks.count)")
                        .whaleFont(size: 11, weight: .semibold)
                        .foregroundStyle(WhaleTheme.accent)
                        .padding(.horizontal, 7)
                        .frame(minHeight: 22)
                        .background(WhaleTheme.accentSoft, in: Capsule())
                }
                Spacer()
                Button("全部") {
                    navigation.workspacePath.append(.todos)
                }
                .whaleFont(size: 12, weight: .semibold)
                .foregroundStyle(WhaleTheme.accent)
                .buttonStyle(.whalePress)
                .accessibilityIdentifier("workspace-open-todo")
            }

            HStack(spacing: 8) {
                TextField("快速添加待办", text: $taskDraft)
                    .whaleFont(size: 14)
                    .submitLabel(.done)
                    .onSubmit { Task { await addTaskFromOverview() } }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .background(
                        WhaleTheme.cardSolid,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .accessibilityIdentifier("workspace-task-draft")
                Button {
                    Task { await addTaskFromOverview() }
                } label: {
                    Image(systemName: taskSubmitting ? "hourglass" : "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(WhaleTheme.onAccent)
                        .frame(width: 42, height: 42)
                        .background(WhaleTheme.accent, in: Circle())
                }
                .buttonStyle(.whalePress)
                .disabled(taskSubmitting || taskDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("添加待办")
            }

            if let taskError {
                Text(taskError)
                    .whaleFont(size: 12)
                    .foregroundStyle(WhaleTheme.warm)
                    .fixedSize(horizontal: false, vertical: true)
            } else if taskLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if pendingTasks.isEmpty {
                Text("目前没有未完成事项。")
                    .whaleFont(size: 13)
                    .foregroundStyle(WhaleTheme.muted)
            } else {
                ForEach(pendingTasks.prefix(5)) { item in
                    taskOverviewRow(item)
                }
                if pendingTasks.count > 5 {
                    Text("还有 \(pendingTasks.count - 5) 项，可点“全部”查看")
                        .whaleFont(size: 12)
                        .foregroundStyle(WhaleTheme.muted)
                }
            }

            if completedTaskCount > 0 {
                Text("已完成 \(completedTaskCount) 项")
                    .whaleFont(size: 11)
                    .foregroundStyle(WhaleTheme.muted)
            }
        }
        .padding(15)
        .background(WhaleTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(WhaleTheme.line.opacity(0.85), lineWidth: 0.7)
        }
    }

    private func taskOverviewRow(_ item: TodoReminder) -> some View {
        Button {
            Task { await toggleTask(item) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: busyTaskIds.contains(item.id) ? "hourglass" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(WhaleTheme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .whaleFont(size: 14, weight: .medium)
                        .foregroundStyle(WhaleTheme.ink)
                        .lineLimit(1)
                    if let due = item.dueAt {
                        Text(taskDueText(due))
                            .whaleFont(size: 11)
                            .foregroundStyle(WhaleTheme.muted)
                    }
                }
                Spacer(minLength: 6)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WhaleTheme.muted.opacity(0.55))
            }
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.whalePress)
        .disabled(busyTaskIds.contains(item.id))
        .accessibilityLabel("完成 \(item.title)")
    }

    @MainActor
    private func loadTaskOverview(silent: Bool = false) async {
        guard !taskLoading else { return }
#if DEBUG
        if TodoDemoMode.isSyncFixture { return }
#endif
        model.refreshPermissions()
        guard model.permissionsSnapshot["reminder"] == "granted" else {
            todoStore.replaceLoaded([])
            taskError = "允许提醒事项权限后，待办会显示在这里。"
            return
        }
        taskLoading = true
        if !silent { taskError = nil }
        defer { taskLoading = false }
        do {
            let items = try await model.loadTodoReminders(includeCompleted: true)
            todoStore.replaceLoaded(items)
            todoStore.markLoaded()
            taskError = nil
        } catch {
            taskError = error.localizedDescription
        }
    }

    @MainActor
    private func addTaskFromOverview() async {
        let title = taskDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !taskSubmitting else { return }
        taskSubmitting = true
        defer { taskSubmitting = false }
        do {
            let item = try await model.createTodoReminder(title: title, dueAt: nil)
            taskDraft = ""
            todoStore.upsert(item)
            taskError = nil
        } catch {
            taskError = error.localizedDescription
        }
    }

    @MainActor
    private func toggleTask(_ item: TodoReminder) async {
        guard !busyTaskIds.contains(item.id) else { return }
        busyTaskIds.insert(item.id)
        defer { busyTaskIds.remove(item.id) }
#if DEBUG
        if TodoDemoMode.isSyncFixture {
            todoStore.upsert(
                TodoReminder(
                    id: item.id,
                    title: item.title,
                    completed: !item.completed,
                    listName: item.listName,
                    dueAt: item.dueAt,
                    notes: item.notes,
                    deduplicated: item.deduplicated
                )
            )
            return
        }
#endif
        do {
            let updated = try await model.setTodoReminder(item, completed: !item.completed)
            todoStore.upsert(updated)
            taskError = nil
        } catch {
            taskError = error.localizedDescription
        }
    }

    private func taskDueText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "今天 HH:mm" : "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "note.text")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WhaleTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(
                        WhaleTheme.accentSoft,
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text("记事")
                        .whaleFont(size: 19, weight: .bold, design: .rounded)
                        .foregroundStyle(WhaleTheme.ink)
                    Text("记录一句话、网页、照片或文件。")
                        .whaleFont(size: 13)
                        .foregroundStyle(WhaleTheme.muted)
                }
                Spacer(minLength: 4)
                Button {
                    sheet = .captureEditor
                } label: {
                    Label("记一笔", systemImage: "plus")
                        .whaleFont(size: 13, weight: .semibold)
                        .foregroundStyle(WhaleTheme.onAccent)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 38)
                        .background(WhaleTheme.accent, in: Capsule())
                }
                .buttonStyle(.whalePress)
                .accessibilityIdentifier("workspace-open-capture-editor")
            }
            .whaleCard(padding: 15)

            if store.inbox.isEmpty {
                workspaceEmpty(
                    title: "还没有记事",
                    detail: "点“记一笔”，留下想法、链接或导入一份文件。",
                    icon: "note.text"
                )
            } else {
                ForEach(store.inbox) { item in
                    noteRow(item)
                }
            }
        }
    }

    private func workspaceEmpty(title: String, detail: String, icon: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(WhaleTheme.muted)
            Text(title)
                .whaleFont(size: 16, weight: .semibold)
                .foregroundStyle(WhaleTheme.ink)
            Text(detail)
                .whaleFont(size: 13)
                .foregroundStyle(WhaleTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(WhaleTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(WhaleTheme.line, lineWidth: 0.7)
        }
    }

    private func noteRow(_ item: WorkspaceCapture) -> some View {
        Button {
            sheet = .captureDetail(item.id)
        } label: {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: item.kind.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WhaleTheme.accent)
                    .frame(width: 38, height: 38)
                    .background(
                        WhaleTheme.accentSoft,
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .whaleFont(size: 15, weight: .semibold)
                        .foregroundStyle(WhaleTheme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !item.body.isEmpty {
                        Text(item.body.replacingOccurrences(of: "\n", with: " "))
                            .whaleFont(size: 13)
                            .foregroundStyle(WhaleTheme.muted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    HStack(spacing: 6) {
                        Text(item.kind.title)
                        Text("·")
                        Text(item.updatedAt.formatted(.relative(presentation: .named)))
                    }
                    .whaleFont(size: 11, weight: .medium)
                    .foregroundStyle(WhaleTheme.muted)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WhaleTheme.muted.opacity(0.65))
                    .padding(.top, 12)
            }
            .padding(14)
            .background(WhaleTheme.card, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(WhaleTheme.line, lineWidth: 0.7)
            }
        }
        .buttonStyle(.whalePress)
    }

    private func showToast(_ text: String) {
        WhaleAccessibility.announce(text)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            toast = text
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard toast == text else { return }
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.18)) {
                toast = nil
            }
        }
    }
}

private struct WorkspaceCaptureEditor: View {
    @ObservedObject var store: WhaleWorkspaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var captureText = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var isImporting = false
    @State private var errorText: String?
    @State private var showsVoice = false
    @FocusState private var focused: Bool

    private var hasChanges: Bool {
        !title.isEmpty || !captureText.isEmpty || showsVoice
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextField("标题（可留空自动生成）", text: $title)
                    TextEditor(text: $captureText)
                        .frame(minHeight: 150)
                        .accessibilityIdentifier("workspace-capture-body")
                    HStack {
                        Button {
                            focused = false
                            showsVoice = true
                        } label: {
                            Label("语音补一句", systemImage: "mic")
                        }
                        .disabled(isImporting)
                        .accessibilityIdentifier("workspace-capture-voice")
                        Spacer()
                        if isImporting {
                            ProgressView()
                        }
                    }
                }

                Section("补充来源") {
                    Button {
                        photoItem = nil
                        showPhotoPicker = true
                    } label: {
                        Label("从照片识别文字", systemImage: "photo")
                    }
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("从 PDF 或图片导入", systemImage: "doc")
                    }
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
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(
                            isImporting
                                || (title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    && captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        )
                }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $photoItem,
                matching: .images
            )
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await ingestPhoto(item) }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                Task { await ingestFile(result) }
            }
            .sheet(isPresented: $showsVoice) {
                WhaleVoiceCaptureSheet(
                    target: .workspace,
                    onCommit: insertVoiceDraft,
                    onCancel: {}
                )
                .presentationDetents([.height(310)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
            .whaleDraftGuard(
                hasChanges: hasChanges,
                isBusy: isImporting
            )
        }
    }

    private func save() {
        let cleanBody = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        let kind: WorkspaceCaptureKind = cleanBody.localizedCaseInsensitiveContains("http")
            ? .link
            : .note
        _ = store.capture(
            title: title,
            body: cleanBody,
            kind: kind
        )
        dismiss()
    }

    private func ingestPhoto(_ item: PhotosPickerItem) async {
        guard !isImporting else { return }
        isImporting = true
        errorText = nil
        defer {
            isImporting = false
            photoItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ToolExecutionError(code: "empty_photo", message: "没有读到照片数据。")
            }
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("workspace-photo-\(UUID().uuidString).\(ext)")
            try data.write(to: url, options: .atomic)
            defer { try? FileManager.default.removeItem(at: url) }
            let document = try await DocumentTextExtractor.extract(url: url)
            saveImported(
                text: document.text,
                title: "图片记录 · \(Date().formatted(.dateTime.month().day()))",
                kind: .image
            )
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func ingestFile(_ result: Result<[URL], Error>) async {
        guard !isImporting else { return }
        isImporting = true
        errorText = nil
        defer { isImporting = false }
        do {
            guard let url = try result.get().first else {
                throw ToolExecutionError(code: "empty_file", message: "没有选择文件。")
            }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let document = try await DocumentTextExtractor.extract(url: url)
            let isPDF = url.pathExtension.lowercased() == "pdf"
            saveImported(
                text: document.text,
                title: url.deletingPathExtension().lastPathComponent,
                kind: isPDF ? .document : .image
            )
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func saveImported(text: String, title: String, kind: WorkspaceCaptureKind) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            errorText = "没有识别到可用文字，请换一张更清晰的图片或可复制文字的 PDF。"
            return
        }
        _ = store.capture(
            title: title,
            body: cleaned,
            kind: kind
        )
        dismiss()
    }

    private func insertVoiceDraft(_ text: String) {
        captureText = mergeVoiceDraft(
            prefix: captureText,
            recognized: text
        )
        focused = true
    }

    private func mergeVoiceDraft(prefix: String, recognized: String) -> String {
        let spoken = recognized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return prefix }
        guard !prefix.isEmpty else { return spoken }
        return prefix.last?.isWhitespace == true ? prefix + spoken : prefix + "\n" + spoken
    }
}

private struct WorkspaceCaptureDetailSheet: View {
    let item: WorkspaceCapture
    @ObservedObject var store: WhaleWorkspaceStore
    let onShowToast: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var bodyText: String
    @State private var errorText: String?
    @State private var confirmDelete = false

    init(
        item: WorkspaceCapture,
        store: WhaleWorkspaceStore,
        onShowToast: @escaping (String) -> Void
    ) {
        self.item = item
        _store = ObservedObject(wrappedValue: store)
        self.onShowToast = onShowToast
        _title = State(initialValue: item.title)
        _bodyText = State(initialValue: item.body)
    }

    private var hasChanges: Bool {
        title != item.title || bodyText != item.body
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextField("标题", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityIdentifier("workspace-note-title")
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 180)
                        .accessibilityIdentifier("workspace-note-body")
                }

                if let source = item.sourceURL, !source.isEmpty {
                    Section("原始来源") {
                        Text(source)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
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
            .navigationTitle("记事详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(
                            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                && bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("删除", role: .destructive) {
                        confirmDelete = true
                    }
                }
            }
            .confirmationDialog(
                "删除这条记事？",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("确认删除", role: .destructive) {
                    store.delete(item)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text(item.title)
            }
        }
        .presentationDetents([.large])
        .whaleDraftGuard(hasChanges: hasChanges)
    }

    private func save() {
        let cleanBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty || !cleanTitle.isEmpty else {
            errorText = "标题和内容不能同时为空。"
            return
        }
        var next = item
        next.title = cleanTitle.isEmpty ? String(cleanBody.prefix(36)) : cleanTitle
        next.body = cleanBody
        store.update(next)
        onShowToast("已保存")
        dismiss()
    }
}

extension Notification.Name {
    static let whaleWorkspaceBriefRefresh = Notification.Name("whale.workspace.brief.refresh")
    static let whaleOpenWorkspace = Notification.Name("whale.workspace.open")
}
