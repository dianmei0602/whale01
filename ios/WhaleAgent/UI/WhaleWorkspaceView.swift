import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum WhaleWorkspaceSection: String, CaseIterable, Identifiable {
    case inbox
    case brief
    case projects
    case knowledge
    case reading
    case focus
    case followUps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox: return "收件箱"
        case .brief: return "晨晚报"
        case .projects: return "项目"
        case .knowledge: return "知识库"
        case .reading: return "阅读"
        case .focus: return "专注"
        case .followUps: return "跟进"
        }
    }

    var icon: String {
        switch self {
        case .inbox: return "tray.full"
        case .brief: return "sun.horizon"
        case .projects: return "square.stack.3d.up"
        case .knowledge: return "books.vertical"
        case .reading: return "book.closed"
        case .focus: return "scope"
        case .followUps: return "arrow.triangle.branch"
        }
    }
}

struct WhaleWorkspaceView: View {
    @ObservedObject var model: AppModel
    var embedded: Bool = false
    let onOpenMusic: () -> Void
    let onOpenChat: (String) -> Void

    @StateObject private var store = WhaleWorkspaceStore.shared
    @StateObject private var reading = DiscoverReadingLibrary.shared
    @EnvironmentObject private var todoStore: TodoTimelineStore
    @EnvironmentObject private var navigation: RootNavigationModel
    @Environment(\.dismiss) private var dismiss
    @State private var section: WhaleWorkspaceSection = .inbox
    @State private var sheet: WorkspaceSheet?
    @State private var readingFilter: ReadingStatus?
    @State private var toast: String?
    @State private var taskDraft = ""
    @State private var taskError: String?
    @State private var taskLoading = false
    @State private var taskSubmitting = false
    @State private var busyTaskIds: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                            ToolbarItem(placement: .primaryAction) {
                                addMenu
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
                        model: model,
                        onOpenChat: onOpenChat,
                        onShowToast: showToast
                    )
                }
            case .projectEditor:
                WorkspaceProjectEditor(store: store)
            case .followUpEditor:
                WorkspaceFollowUpEditor(store: store)
            case .reader(let article):
                NativeArticleReaderView(
                    item: newsItem(for: article),
                    library: reading
                )
            case .highlight(let article):
                WorkspaceReadingHighlightSheet(article: article, store: store) {
                    showToast("摘录已保存到私人知识库")
                }
            }
        }
    }

    private var workspaceContent: some View {
        ZStack(alignment: .top) {
            WhaleBackdrop().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    workspaceIdentity
                    tasksOverview
                    sectionSelector
                    if let issue = store.loadIssue {
                        Label(issue, systemImage: "exclamationmark.triangle")
                            .whaleFont(size: 13)
                            .foregroundStyle(WhaleTheme.warm)
                            .fixedSize(horizontal: false, vertical: true)
                            .whaleCard(padding: 13)
                    }
                    sectionContent
                        .id("workspace-top-\(section.rawValue)")
                        .accessibilityIdentifier(
                            "workspace-section-content-\(section.rawValue)"
                        )
                }
                .padding(.horizontal, WhaleTheme.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(
                ScrollOffsetMemory(
                    key: "workspace-section-\(section.rawValue)"
                )
            )
            .refreshable {
                await loadTaskOverview(silent: true)
                if section == .brief {
                    NotificationCenter.default.post(name: .whaleWorkspaceBriefRefresh, object: nil)
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

    private var addMenu: some View {
        Menu {
            Button("记录想法", systemImage: "square.and.pencil") {
                sheet = .captureEditor
            }
            Button("新建项目", systemImage: "folder.badge.plus") {
                sheet = .projectEditor
            }
            Button("新增跟进", systemImage: "arrow.triangle.branch") {
                sheet = .followUpEditor
            }
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("新增")
    }

    private var workspaceIdentity: some View {
        HStack(spacing: 10) {
            WhaleMarkView(size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("工作台")
                    .whaleFont(size: 22, weight: .bold, design: .rounded)
                    .foregroundStyle(WhaleTheme.ink)
                Text("待办、记录、阅读都在这里")
                    .whaleFont(size: 12)
                    .foregroundStyle(WhaleTheme.muted)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("workspace-title")
    }

    private var pendingTasks: [TodoReminder] {
        todoStore.pending
    }

    private var completedTaskCount: Int {
        todoStore.completed.count
    }

    private var tasksOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("待办", systemImage: "checklist")
                    .whaleFont(size: 16, weight: .bold)
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
                    .background(WhaleTheme.cardSolid, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                ForEach(pendingTasks.prefix(4)) { item in
                    taskOverviewRow(item)
                }
                if pendingTasks.count > 4 {
                    Text("还有 \(pendingTasks.count - 4) 项未显示")
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
        .padding(14)
        .background(WhaleTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(WhaleTheme.line.opacity(0.85), lineWidth: 0.7)
        }
        .accessibilityIdentifier("workspace-tasks-overview")
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

    private var sectionSelector: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(WhaleWorkspaceSection.allCases) { item in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                            section = item
                        }
                    } label: {
                        Label(item.title, systemImage: item.icon)
                            .whaleFont(size: 13, weight: .semibold)
                            .foregroundStyle(section == item ? WhaleTheme.onAccent : WhaleTheme.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 40)
                            .background(
                                section == item ? WhaleTheme.accent : WhaleTheme.card,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        section == item ? Color.clear : WhaleTheme.line,
                                        lineWidth: 0.7
                                    )
                            }
                    }
                    .buttonStyle(.whalePress)
                    .accessibilityIdentifier("workspace-section-" + item.rawValue)
                }
                if embedded {
                    addMenu
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .inbox:
            inboxSection
        case .brief:
            WorkspaceBriefSection(model: model, store: store)
        case .projects:
            projectsSection
        case .knowledge:
            knowledgeSection
        case .reading:
            readingSection
        case .focus:
            WorkspaceFocusSection(model: model, store: store, onOpenMusic: onOpenMusic)
        case .followUps:
            followUpsSection
        }
    }

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            workspaceIntro(
                title: "统一收件箱",
                detail: "文字、网页分享、照片和文件先进入这里。只有你确认后才转为待办、日程或知识条目。",
                icon: "tray.and.arrow.down.fill"
            ) {
                Button {
                    sheet = .captureEditor
                } label: {
                    Label("记录或导入", systemImage: "plus")
                        .whaleFont(size: 13, weight: .semibold)
                        .foregroundStyle(WhaleTheme.onAccent)
                        .padding(.horizontal, 13)
                        .frame(minHeight: 38)
                        .background(WhaleTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("workspace-open-capture-editor")
            }

            if store.inbox.isEmpty {
                workspaceEmpty(
                    title: "收件箱是空的",
                    detail: "可以记录一句话，或从照片、PDF 和系统分享菜单收集内容。",
                    icon: "tray"
                )
            } else {
                ForEach(store.inbox) { item in
                    captureRow(item)
                }
            }
        }
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            workspaceIntro(
                title: "项目空间",
                detail: "把同一件事的收件内容、知识条目和后续跟进放在一个项目里。",
                icon: "square.stack.3d.up.fill"
            ) {
                Button {
                    sheet = .projectEditor
                } label: {
                    Label("新建项目", systemImage: "folder.badge.plus")
                        .whaleFont(size: 13, weight: .semibold)
                        .foregroundStyle(WhaleTheme.onAccent)
                        .padding(.horizontal, 13)
                        .frame(minHeight: 38)
                        .background(WhaleTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if store.projects.isEmpty {
                workspaceEmpty(
                    title: "还没有项目",
                    detail: "例如“春节旅行”“装修”“求职”或“课程学习”。",
                    icon: "folder"
                )
            } else {
                ForEach(store.projects) { project in
                    projectCard(project)
                }
            }
        }
    }

    private var knowledgeSection: some View {
        WorkspaceKnowledgeSection(
            store: store,
            onSelect: { sheet = .captureDetail($0.id) },
            onAsk: { prompt in onOpenChat(prompt) }
        )
    }

    private var readingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            workspaceIntro(
                title: "阅读工作台",
                detail: "复用发现页的真实收藏。可以打开原文、标记读完，或把摘要保存到私人知识库。",
                icon: "book.pages.fill"
            ) {
                Text("\(reading.saved.count) 篇")
                    .whaleFont(size: 12, weight: .semibold)
                    .foregroundStyle(WhaleTheme.accent)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 34)
                    .background(WhaleTheme.accentSoft, in: Capsule())
            }

            HStack(spacing: 8) {
                readingFilterButton(nil, title: "全部")
                readingFilterButton(.toRead, title: "待读")
                readingFilterButton(.reading, title: "在读")
                readingFilterButton(.finished, title: "读完")
            }

            if reading.saved.isEmpty {
                workspaceEmpty(
                    title: "还没有稍后读内容",
                    detail: "在发现页的资讯详情里点书签，内容会出现在这里。",
                    icon: "bookmark"
                )
            } else {
                ForEach(displayedReading) { article in
                    readingCard(article)
                }
            }
        }
    }

    private var followUpsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            workspaceIntro(
                title: "重要跟进",
                detail: "只保存你明确添加的人和事，不会主动读取通讯录或推断关系。",
                icon: "arrow.triangle.branch"
            ) {
                Button {
                    sheet = .followUpEditor
                } label: {
                    Label("新增跟进", systemImage: "plus")
                        .whaleFont(size: 13, weight: .semibold)
                        .foregroundStyle(WhaleTheme.onAccent)
                        .padding(.horizontal, 13)
                        .frame(minHeight: 38)
                        .background(WhaleTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if store.pendingFollowUps.isEmpty {
                workspaceEmpty(
                    title: "没有待跟进事项",
                    detail: "可以记录需要回访、确认或继续联系的事情。",
                    icon: "checkmark.circle"
                )
            } else {
                ForEach(store.pendingFollowUps) { item in
                    followUpRow(item)
                }
            }

            let completed = store.followUps.filter(\.isCompleted)
            if !completed.isEmpty {
                Text("已完成")
                    .whaleFont(size: 13, weight: .semibold)
                    .foregroundStyle(WhaleTheme.muted)
                    .padding(.top, 5)
                ForEach(completed.prefix(8)) { item in
                    followUpRow(item)
                }
            }
        }
    }

    private func workspaceIntro<Accessory: View>(
        title: String,
        detail: String,
        icon: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WhaleTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(WhaleTheme.accentSoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .whaleFont(size: 19, weight: .bold, design: .rounded)
                        .foregroundStyle(WhaleTheme.ink)
                    Text(detail)
                        .whaleFont(size: 13)
                        .foregroundStyle(WhaleTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
            }
            HStack {
                Spacer()
                accessory()
            }
        }
        .whaleCard(padding: 16)
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

    private func captureRow(_ item: WorkspaceCapture) -> some View {
        Button {
            sheet = .captureDetail(item.id)
        } label: {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: item.kind.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WhaleTheme.accent)
                    .frame(width: 38, height: 38)
                    .background(WhaleTheme.accentSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
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
                        Text(item.createdAt.formatted(.relative(presentation: .named)))
                        if item.isKnowledge {
                            Label("知识库", systemImage: "books.vertical")
                        }
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

    private func projectCard(_ project: WorkspaceProject) -> some View {
        let captures = store.captures.filter { $0.projectID == project.id && !$0.isArchived }
        let followUps = store.followUps.filter { $0.projectID == project.id && !$0.isCompleted }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(WhaleTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name)
                        .whaleFont(size: 17, weight: .bold)
                        .foregroundStyle(WhaleTheme.ink)
                    if !project.summary.isEmpty {
                        Text(project.summary)
                            .whaleFont(size: 13)
                            .foregroundStyle(WhaleTheme.muted)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text("\(captures.count) 条 · \(followUps.count) 跟进")
                    .whaleFont(size: 11, weight: .semibold)
                    .foregroundStyle(WhaleTheme.accent)
            }
            ForEach(captures.prefix(3)) { item in
                Button {
                    sheet = .captureDetail(item.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.kind.icon)
                            .foregroundStyle(WhaleTheme.muted)
                        Text(item.title)
                            .whaleFont(size: 13)
                            .foregroundStyle(WhaleTheme.ink)
                            .lineLimit(1)
                        Spacer()
                        Text(item.updatedAt.formatted(.dateTime.month().day()))
                            .whaleFont(size: 11)
                            .foregroundStyle(WhaleTheme.muted)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(WhaleTheme.muted)
                    }
                    .frame(minHeight: 34)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if captures.isEmpty && followUps.isEmpty {
                Text("还没有内容。在收件箱详情里把条目分配到这个项目。")
                    .whaleFont(size: 12)
                    .foregroundStyle(WhaleTheme.muted)
            }
        }
        .whaleCard(padding: 15)
    }

    private func readingCard(_ article: SavedArticle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(article.title)
                .whaleFont(size: 16, weight: .semibold)
                .foregroundStyle(WhaleTheme.ink)
                .lineLimit(3)
            Text(article.summary)
                .whaleFont(size: 13)
                .foregroundStyle(WhaleTheme.muted)
                .lineLimit(2)
            HStack(spacing: 8) {
                Text(article.source)
                Text("·")
                Text(article.status.title)
                Text("· \(Int(article.progress * 100))%")
                Spacer()
                if article.status != .finished {
                    Button("读完") {
                        let placeholder = NewsItem(
                            id: article.id,
                            title: article.title,
                            summary: article.summary,
                            source: article.source,
                            link: article.link,
                            publishedAt: nil,
                            channel: article.channel,
                            rank: nil
                        )
                        reading.markRead(placeholder)
                    }
                    .foregroundStyle(WhaleTheme.accent)
                }
                Button("摘录") {
                    sheet = .highlight(article)
                }
                .foregroundStyle(WhaleTheme.accent)
                Button("打开") {
                    sheet = .reader(article)
                }
                .foregroundStyle(WhaleTheme.accent)
            }
            .whaleFont(size: 12, weight: .semibold)
            ProgressView(value: article.progress)
                .tint(article.status == .finished ? WhaleTheme.success : WhaleTheme.accent)
        }
        .whaleCard(padding: 14)
    }

    private var displayedReading: [SavedArticle] {
        guard let readingFilter else { return reading.saved }
        return reading.articles(with: readingFilter)
    }

    private func newsItem(for article: SavedArticle) -> NewsItem {
        NewsItem(
            id: article.id,
            title: article.title,
            summary: article.summary,
            source: article.source,
            link: article.link,
            publishedAt: nil,
            channel: article.channel,
            rank: nil
        )
    }

    private func readingFilterButton(_ status: ReadingStatus?, title: String) -> some View {
        Button {
            readingFilter = status
        } label: {
            Text(title)
                .whaleFont(size: 12, weight: .semibold)
                .foregroundStyle(readingFilter == status ? WhaleTheme.onAccent : WhaleTheme.ink)
                .padding(.horizontal, 11)
                .frame(minHeight: 34)
                .background(
                    readingFilter == status ? WhaleTheme.accent : WhaleTheme.card,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func followUpRow(_ item: WorkspaceFollowUp) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                store.toggleFollowUp(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(item.isCompleted ? WhaleTheme.success : WhaleTheme.muted)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isCompleted ? "恢复跟进" : "标记跟进完成")

            VStack(alignment: .leading, spacing: 4) {
                Text(item.subject)
                    .whaleFont(size: 15, weight: .semibold)
                    .foregroundStyle(WhaleTheme.ink)
                    .strikethrough(item.isCompleted)
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .whaleFont(size: 13)
                        .foregroundStyle(WhaleTheme.muted)
                        .lineLimit(2)
                }
                if let dueAt = item.dueAt {
                    Text(dueAt.formatted(.dateTime.month().day().hour().minute()))
                        .whaleFont(size: 12, weight: .medium)
                        .foregroundStyle(dueAt < Date() && !item.isCompleted ? WhaleTheme.warm : WhaleTheme.muted)
                }
            }
            Spacer(minLength: 4)
            Menu {
                Button("删除", systemImage: "trash", role: .destructive) {
                    store.deleteFollowUp(item)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 38, height: 38)
                    .foregroundStyle(WhaleTheme.muted)
            }
        }
        .padding(13)
        .background(WhaleTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(WhaleTheme.line, lineWidth: 0.7)
        }
    }

    private func showToast(_ text: String) {
        WhaleAccessibility.announce(text)
        withAnimation(.easeOut(duration: 0.18)) {
            toast = text
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if toast == text {
                withAnimation(.easeIn(duration: 0.18)) {
                    toast = nil
                }
            }
        }
    }
}

private struct WorkspaceKnowledgeSection: View {
    @ObservedObject var store: WhaleWorkspaceStore
    let onSelect: (WorkspaceCapture) -> Void
    let onAsk: (String) -> Void
    @State private var query = ""

    private var results: [WorkspaceCapture] {
        store.searchKnowledge(query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Label("私人知识库", systemImage: "books.vertical.fill")
                    .whaleFont(size: 19, weight: .bold, design: .rounded)
                    .foregroundStyle(WhaleTheme.ink)
                Text("回答只使用本机保存的内容。检索结果会显示标题、摘要和原始来源，不把命中的资料说成模型推理。")
                    .whaleFont(size: 13)
                    .foregroundStyle(WhaleTheme.muted)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(WhaleTheme.muted)
                    TextField("问我以前保存了什么", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(WhaleTheme.muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(WhaleTheme.field, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                Text(query.isEmpty ? "直接输入关键词，或先浏览全部条目。" : "找到 \(results.count) 条本机资料")
                    .whaleFont(size: 11, weight: .medium)
                    .foregroundStyle(WhaleTheme.muted)
                if !query.isEmpty && !results.isEmpty {
                    Button {
                        onAsk(questionPrompt)
                    } label: {
                        Label("带着这些真实来源问鲸鱼", systemImage: "sparkles")
                            .whaleFont(size: 13, weight: .semibold)
                            .foregroundStyle(WhaleTheme.onAccent)
                            .padding(.horizontal, 13)
                            .frame(minHeight: 38)
                            .background(WhaleTheme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .whaleCard(padding: 16)

            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: query.isEmpty ? "books.vertical" : "magnifyingglass")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(WhaleTheme.muted)
                    Text(query.isEmpty ? "还没有知识条目" : "没有找到匹配资料")
                        .whaleFont(size: 16, weight: .semibold)
                        .foregroundStyle(WhaleTheme.ink)
                    Text(query.isEmpty ? "在收件箱详情里打开“保存到知识库”。" : "换一个关键词，或确认资料是否已经保存。")
                        .whaleFont(size: 13)
                        .foregroundStyle(WhaleTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(WhaleTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ForEach(results) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(item.kind.title, systemImage: item.kind.icon)
                                    .whaleFont(size: 11, weight: .semibold)
                                    .foregroundStyle(WhaleTheme.accent)
                                Spacer()
                                Text(item.updatedAt.formatted(.relative(presentation: .named)))
                                    .whaleFont(size: 11)
                                    .foregroundStyle(WhaleTheme.muted)
                            }
                            Text(item.title)
                                .whaleFont(size: 16, weight: .semibold)
                                .foregroundStyle(WhaleTheme.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(snippet(for: item))
                                .whaleFont(size: 13)
                                .foregroundStyle(WhaleTheme.muted)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                            if let source = item.sourceURL, !source.isEmpty {
                                Text(source)
                                    .whaleFont(size: 11)
                                    .foregroundStyle(WhaleTheme.accent)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .whaleCard(padding: 14)
                    }
                    .buttonStyle(.whalePress)
                }
            }
        }
    }

    private func snippet(for item: WorkspaceCapture) -> String {
        let source = item.body.replacingOccurrences(of: "\n", with: " ")
        guard !query.isEmpty, let range = source.range(of: query, options: .caseInsensitive) else {
            return String(source.prefix(160))
        }
        let lower = source.index(range.lowerBound, offsetBy: -40, limitedBy: source.startIndex) ?? source.startIndex
        let upper = source.index(range.upperBound, offsetBy: 100, limitedBy: source.endIndex) ?? source.endIndex
        return String(source[lower..<upper])
    }

    private var questionPrompt: String {
        let sources = results.prefix(3).map { item in
            """
            【\(item.title)】
            \(String(item.body.prefix(900)))
            来源：\(item.sourceURL ?? "本机记录")
            """
        }.joined(separator: "\n\n")
        return """
        请只根据下面保存的本机资料回答“\(query)”。
        如果资料不足，请直接说明不足，不要补写。回答末尾逐条列出实际使用的标题和来源。

        \(sources)
        """
    }
}

private struct WorkspaceBriefSection: View {
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

private struct WorkspaceFocusSection: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: WhaleWorkspaceStore
    let onOpenMusic: () -> Void

    private var nextEvent: CalendarEventPreview? {
        model.upcomingEvents
            .filter { $0.endAt > Date() }
            .sorted { $0.startAt < $1.startAt }
            .first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Label("上下文专注模式", systemImage: "scope")
                    .whaleFont(size: 19, weight: .bold, design: .rounded)
                    .foregroundStyle(WhaleTheme.ink)
                Text("只改变鲸鱼工作台里的上下文和建议，不会替你开启系统勿扰或伪造专注完成记录。")
                    .whaleFont(size: 13)
                    .foregroundStyle(WhaleTheme.muted)
                if let mode = store.activeFocusMode, let startedAt = store.focusStartedAt {
                    HStack {
                        Label(mode.title, systemImage: mode.icon)
                            .whaleFont(size: 15, weight: .semibold)
                            .foregroundStyle(WhaleTheme.accent)
                        Spacer()
                        TimelineView(.periodic(from: Date(), by: 1)) { context in
                            Text(elapsedText(from: startedAt, to: context.date))
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                                .foregroundStyle(WhaleTheme.ink)
                        }
                    }
                    Button("结束专注") {
                        store.endFocus()
                    }
                    .whaleFont(size: 13, weight: .semibold)
                    .foregroundStyle(WhaleTheme.onAccent)
                    .padding(.horizontal, 13)
                    .frame(minHeight: 38)
                    .background(WhaleTheme.accent, in: Capsule())
                    .buttonStyle(.plain)
                    Button {
                        onOpenMusic()
                    } label: {
                        Label("打开系统音乐库", systemImage: "music.note")
                            .whaleFont(size: 13, weight: .semibold)
                            .foregroundStyle(WhaleTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .whaleCard(padding: 16)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(WorkspaceFocusMode.allCases) { mode in
                    Button {
                        store.startFocus(mode)
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(WhaleTheme.accent)
                            Text(mode.title)
                                .whaleFont(size: 16, weight: .bold)
                                .foregroundStyle(WhaleTheme.ink)
                            Text(mode.suggestion)
                                .whaleFont(size: 12)
                                .foregroundStyle(WhaleTheme.muted)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
                        .padding(13)
                        .background(
                            store.activeFocusMode == mode
                                ? WhaleTheme.accentSoft
                                : WhaleTheme.card,
                            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .strokeBorder(
                                    store.activeFocusMode == mode
                                        ? WhaleTheme.accent.opacity(0.35)
                                        : WhaleTheme.line,
                                    lineWidth: 0.8
                                )
                        }
                    }
                    .buttonStyle(.whalePress)
                }
            }

            if let nextEvent {
                VStack(alignment: .leading, spacing: 5) {
                    Label("下一项真实日程", systemImage: "calendar")
                        .whaleFont(size: 13, weight: .semibold)
                        .foregroundStyle(WhaleTheme.accent)
                    Text(nextEvent.title)
                        .whaleFont(size: 16, weight: .semibold)
                        .foregroundStyle(WhaleTheme.ink)
                    Text(nextEvent.startAt.formatted(.dateTime.month().day().hour().minute()))
                        .whaleFont(size: 12)
                        .foregroundStyle(WhaleTheme.muted)
                }
                .whaleCard(padding: 14)
            }

            if !store.focusSessions.isEmpty {
                Text("最近专注 \(store.focusSessions.count) 次")
                    .whaleFont(size: 12, weight: .medium)
                    .foregroundStyle(WhaleTheme.muted)
            }
        }
    }

    private func elapsedText(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct WorkspaceCaptureEditor: View {
    @ObservedObject var store: WhaleWorkspaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var captureText = ""
    @State private var kind: WorkspaceCaptureKind = .note
    @State private var projectID: String?
    @State private var saveToKnowledge = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var isImporting = false
    @State private var errorText: String?
    @State private var showsVoice = false
    @FocusState private var focused: Bool

    private var hasChanges: Bool {
        !title.isEmpty
            || !captureText.isEmpty
            || showsVoice
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("收件内容") {
                    TextField("标题（可留空自动生成）", text: $title)
                    TextEditor(text: $captureText)
                        .frame(minHeight: 150)
                        .accessibilityIdentifier("workspace-capture-body")
                    HStack {
                        Button {
                            focused = false
                            showsVoice = true
                        } label: {
                            Label(
                                "语音补一句",
                                systemImage: "mic"
                            )
                        }
                        .disabled(isImporting)
                        .accessibilityIdentifier("workspace-capture-voice")
                        Spacer()
                        if isImporting {
                            ProgressView()
                        }
                    }
                }

                Section("来源") {
                    Picker("类型", selection: $kind) {
                        ForEach(WorkspaceCaptureKind.allCases) { value in
                            Label(value.title, systemImage: value.icon).tag(value)
                        }
                    }
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

                Section("归档方式") {
                    Picker("项目", selection: $projectID) {
                        Text("未分配").tag(String?.none)
                        ForEach(store.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    Toggle("同时保存到私人知识库", isOn: $saveToKnowledge)
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
            .navigationTitle("记录到收件箱")
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
        let finalKind: WorkspaceCaptureKind = {
            guard kind == .note, cleanBody.contains("http") else { return kind }
            return .link
        }()
        _ = store.capture(
            title: title,
            body: cleanBody,
            kind: finalKind,
            projectID: projectID,
            isKnowledge: saveToKnowledge
        )
        dismiss()
    }

    private func ingestPhoto(_ item: PhotosPickerItem) async {
        guard !isImporting else { return }
        isImporting = true
        errorText = nil
        defer { isImporting = false; photoItem = nil }
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
            saveImported(text: document.text, title: "图片记录 · \(Date().formatted(.dateTime.month().day()))", kind: .image)
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
            kind: kind,
            projectID: projectID,
            isKnowledge: saveToKnowledge
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
    @ObservedObject var model: AppModel
    let onOpenChat: (String) -> Void
    let onShowToast: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var bodyText: String
    @State private var kind: WorkspaceCaptureKind
    @State private var projectID: String?
    @State private var isKnowledge: Bool
    @State private var followUpEnabled = false
    @State private var followUpDue = Date().addingTimeInterval(86_400)
    @State private var isSavingTodo = false
    @State private var errorText: String?
    @State private var confirmTodo = false
    @State private var destructiveAction: WorkspaceCaptureDestructiveAction?

    init(
        item: WorkspaceCapture,
        store: WhaleWorkspaceStore,
        model: AppModel,
        onOpenChat: @escaping (String) -> Void,
        onShowToast: @escaping (String) -> Void
    ) {
        self.item = item
        _store = ObservedObject(wrappedValue: store)
        _model = ObservedObject(wrappedValue: model)
        self.onOpenChat = onOpenChat
        self.onShowToast = onShowToast
        _title = State(initialValue: item.title)
        _bodyText = State(initialValue: item.body)
        _kind = State(initialValue: item.kind)
        _projectID = State(initialValue: item.projectID)
        _isKnowledge = State(initialValue: item.isKnowledge)
    }

    private var hasChanges: Bool {
        title != item.title
            || bodyText != item.body
            || kind != item.kind
            || projectID != item.projectID
            || isKnowledge != item.isKnowledge
            || followUpEnabled
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextField("标题", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 180)
                }

                Section("归档") {
                    Picker("类型", selection: $kind) {
                        ForEach(WorkspaceCaptureKind.allCases) { value in
                            Label(value.title, systemImage: value.icon).tag(value)
                        }
                    }
                    Picker("项目", selection: $projectID) {
                        Text("未分配").tag(String?.none)
                        ForEach(store.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    Toggle("保存到私人知识库", isOn: $isKnowledge)
                    Toggle("加入重要跟进", isOn: $followUpEnabled)
                    if followUpEnabled {
                        DatePicker(
                            "跟进日期",
                            selection: $followUpDue,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                if let source = item.sourceURL, !source.isEmpty {
                    Section("原始来源") {
                        Text(source)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
                }

                Section("下一步") {
                    Button {
                        confirmTodo = true
                    } label: {
                        Label(isSavingTodo ? "正在写入…" : "转为待办", systemImage: "checklist")
                    }
                    .disabled(isSavingTodo)
                    Button {
                        askWhaleToSchedule()
                    } label: {
                        Label("让鲸鱼帮我安排日程", systemImage: "calendar.badge.plus")
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
            .navigationTitle("收件详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("移入归档") {
                        destructiveAction = .archive
                    }
                    Spacer()
                    Button("删除", role: .destructive) {
                        destructiveAction = .delete
                    }
                }
            }
            .confirmationDialog(
                "写入系统提醒事项？",
                isPresented: $confirmTodo,
                titleVisibility: .visible
            ) {
                Button("确认写入") {
                    Task { await createTodo() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("会创建：\(title)。这一步会请求提醒事项权限，并真实写入系统。")
            }
            .confirmationDialog(
                "处理这条记录？",
                isPresented: Binding(
                    get: { destructiveAction != nil },
                    set: { if !$0 { destructiveAction = nil } }
                ),
                titleVisibility: .visible
            ) {
                if destructiveAction == .archive {
                    Button("移入归档") {
                        store.archive(item)
                        destructiveAction = nil
                        dismiss()
                    }
                }
                if destructiveAction == .delete {
                    Button("确认删除", role: .destructive) {
                        store.delete(item)
                        destructiveAction = nil
                        dismiss()
                    }
                }
                Button("取消", role: .cancel) {
                    destructiveAction = nil
                }
            } message: {
                Text(item.title)
            }
        }
        .presentationDetents([.large])
        .whaleDraftGuard(
            hasChanges: hasChanges,
            isBusy: isSavingTodo
        )
    }

    private func save() {
        var next = item
        next.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        next.body = bodyText
        next.kind = kind
        next.projectID = projectID
        next.isKnowledge = isKnowledge
        store.update(next)
        if followUpEnabled {
            _ = store.addFollowUp(
                subject: next.title,
                detail: String(next.body.prefix(400)),
                dueAt: followUpDue,
                projectID: projectID
            )
        }
        onShowToast("已保存")
        dismiss()
    }

    private func createTodo() async {
        guard !isSavingTodo else { return }
        isSavingTodo = true
        errorText = nil
        defer { isSavingTodo = false }
        do {
            let projectName = store.projects.first { $0.id == projectID }?.name
            _ = try await model.createTodoReminder(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                dueAt: nil,
                project: projectName
            )
            var next = item
            next.isArchived = true
            store.update(next)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onShowToast("已写入系统提醒事项")
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func askWhaleToSchedule() {
        save()
        let prompt = "请先读取我的真实日历，再为这件事给出 1～3 个候选时间；在写入前让我确认。不要自行创建日程。\n\n标题：\(title)\n内容：\(String(bodyText.prefix(1200)))"
        onOpenChat(prompt)
    }
}

private struct WorkspaceProjectEditor: View {
    @ObservedObject var store: WhaleWorkspaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var summary = ""

    private var hasChanges: Bool {
        !name.isEmpty || !summary.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("项目名称") {
                    TextField("例如：春节旅行、装修、求职", text: $name)
                }
                Section("说明") {
                    TextEditor(text: $summary)
                        .frame(minHeight: 120)
                }
            }
            .scrollContentBackground(.hidden)
            .background(WhaleBackdrop())
            .navigationTitle("新建项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        _ = store.addProject(name: name, summary: summary)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .whaleDraftGuard(hasChanges: hasChanges)
    }
}

private struct WorkspaceReadingHighlightSheet: View {
    let article: SavedArticle
    @ObservedObject var store: WhaleWorkspaceStore
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var excerpt: String
    @State private var note = ""

    private var hasChanges: Bool {
        excerpt != article.summary || !note.isEmpty
    }

    init(article: SavedArticle, store: WhaleWorkspaceStore, onSaved: @escaping () -> Void) {
        self.article = article
        _store = ObservedObject(wrappedValue: store)
        self.onSaved = onSaved
        _excerpt = State(initialValue: article.summary)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("原文") {
                    Text(article.title)
                        .font(.headline)
                    Text(article.source)
                        .font(.caption)
                        .foregroundStyle(WhaleTheme.muted)
                }
                Section("摘录") {
                    TextEditor(text: $excerpt)
                        .frame(minHeight: 130)
                }
                Section("我的批注") {
                    TextEditor(text: $note)
                        .frame(minHeight: 90)
                }
                Section {
                    Text("保存后会进入私人知识库，并保留原文链接。")
                        .font(.footnote)
                        .foregroundStyle(WhaleTheme.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(WhaleBackdrop())
            .navigationTitle("阅读摘录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let combined = [excerpt, note.isEmpty ? "" : "批注：\(note)"]
                            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            .joined(separator: "\n\n")
                        _ = store.capture(
                            title: "摘录 · \(article.title)",
                            body: combined,
                            kind: .reading,
                            sourceURL: article.link,
                            isKnowledge: true
                        )
                        onSaved()
                        dismiss()
                    }
                    .disabled(excerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .whaleDraftGuard(hasChanges: hasChanges)
    }
}

private struct WorkspaceFollowUpEditor: View {
    @ObservedObject var store: WhaleWorkspaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var subject = ""
    @State private var detail = ""
    @State private var dueAt = Date().addingTimeInterval(86_400)
    @State private var useDueDate = true
    @State private var projectID: String?

    private var hasChanges: Bool {
        !subject.isEmpty
            || !detail.isEmpty
            || projectID != nil
            || !useDueDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("跟进事项") {
                    TextField("跟进对象或事项", text: $subject)
                    Text("例如：王老师 / 酒店前台 / 合同回访。不会从通讯录自动猜测。")
                        .font(.caption)
                        .foregroundStyle(WhaleTheme.muted)
                    TextEditor(text: $detail)
                        .frame(minHeight: 100)
                }
                Section("时间与项目") {
                    Toggle("设置跟进日期", isOn: $useDueDate)
                    if useDueDate {
                        DatePicker(
                            "跟进日期",
                            selection: $dueAt,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                    Picker("项目", selection: $projectID) {
                        Text("未分配").tag(String?.none)
                        ForEach(store.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                }
                Section {
                    Text("这是本机跟进清单。只有在 App 内选择转为待办时，才会写入系统提醒事项。")
                        .font(.footnote)
                        .foregroundStyle(WhaleTheme.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(WhaleBackdrop())
            .navigationTitle("新增跟进")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        _ = store.addFollowUp(
                            subject: subject,
                            detail: detail,
                            dueAt: useDueDate ? dueAt : nil,
                            projectID: projectID
                        )
                        dismiss()
                    }
                    .disabled(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .whaleDraftGuard(hasChanges: hasChanges)
    }
}

extension Notification.Name {
    static let whaleWorkspaceBriefRefresh = Notification.Name("whale.workspace.brief.refresh")
    static let whaleOpenWorkspace = Notification.Name("whale.workspace.open")
}
