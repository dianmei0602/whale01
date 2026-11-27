import SwiftUI
import UIKit

struct TodoReminder: Identifiable, Equatable {
    let id: String
    let title: String
    let completed: Bool
    let listName: String
    let dueAt: Date?
    let notes: String?
    let deduplicated: Bool

    init?(json: JSONValue) {
        guard let object = json.objectValue,
              let id = object.optionalString("recordId"),
              let title = object.optionalString("title"),
              !title.isEmpty else { return nil }
        self.id = id
        self.title = title
        self.completed = object.optionalBool("completed") ?? false
        self.listName = object.optionalString("listName") ?? "提醒事项"
        self.dueAt = object.optionalString("dueAt").flatMap(ToolDate.parse)
        self.notes = object.optionalString("notes")
        self.deduplicated = object.optionalBool("deduplicated") ?? false
    }
}

private enum TodoFilter: String, CaseIterable, Identifiable {
    case pending
    case inProgress
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: return "待办"
        case .inProgress: return "进行中"
        case .completed: return "已完成"
        }
    }
}

private enum TodoTimeGroup: String, CaseIterable, Identifiable {
    case today
    case morning
    case afternoon
    case evening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "上午"
        case .afternoon: return "下午"
        case .evening: return "晚上"
        case .today: return "今天"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        case .today: return "calendar"
        }
    }

    static func resolve(_ date: Date?) -> TodoTimeGroup {
        guard let date else { return .today }
        let hour = Calendar.current.component(.hour, from: date)
        if hour < 12 { return .morning }
        if hour < 18 { return .afternoon }
        return .evening
    }
}

private enum TodoQuickCommand {
    case complete(String)
    case restore(String)
    case delete(String)

    static func parse(_ raw: String) -> TodoQuickCommand? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["帮我", "请", "我要"] where text.hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }
        guard !text.isEmpty else { return nil }

        let actions: [(String, (String) -> TodoQuickCommand)] = [
            ("标记完成", TodoQuickCommand.complete),
            ("取消完成", TodoQuickCommand.restore),
            ("已完成", TodoQuickCommand.complete),
            ("完成", TodoQuickCommand.complete),
            ("勾掉", TodoQuickCommand.complete),
            ("恢复", TodoQuickCommand.restore),
            ("删除", TodoQuickCommand.delete),
            ("删掉", TodoQuickCommand.delete),
            ("移除", TodoQuickCommand.delete)
        ]

        for (prefix, make) in actions where text.hasPrefix(prefix) {
            var rest = String(text.dropFirst(prefix.count))
            rest = rest.trimmingCharacters(in: CharacterSet(charactersIn: " ：:，,\n"))
            if !rest.isEmpty { return make(rest) }
        }

        for suffix in ["完成了", "做完了", "已完成", "搞定了"] where text.hasSuffix(suffix) {
            let rest = String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !rest.isEmpty { return .complete(rest) }
        }

        return nil
    }
}

struct TodoView: View {
    @ObservedObject var model: AppModel
    var embedded: Bool = false
    var onBackToChat: (() -> Void)? = nil
    var bottomBarInset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("whale.todo.filter") private var filter: TodoFilter = .pending
    @State private var items: [TodoReminder] = []
    @AppStorage("whale.draft.todo") private var draft = ""
    @State private var selectedList: String?
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var busyIds: Set<String> = []
    @State private var errorText: String?
    @State private var toast: String?
    @State private var undoAction: TodoUndo?
    @State private var undoExpiresAt = Date.distantPast
    @State private var showTimeEditor = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let drafts = ComposerDraftStore()
    @State private var pendingDeletion: TodoReminder?
    @State private var showVoiceSheet = false
    @FocusState private var composerFocused: Bool

    private var reminderStatus: String { model.permissionsSnapshot["reminder"] ?? "unknown" }
    private var pendingItems: [TodoReminder] { items.filter { !$0.completed } }
    private var completedItems: [TodoReminder] { items.filter(\.completed) }
    private var visibleItems: [TodoReminder] {
        let statusFiltered: [TodoReminder]
        switch filter {
        case .pending: statusFiltered = scopedItems.filter { !$0.completed }
        case .inProgress: statusFiltered = scopedItems.filter { item in
            let endOfToday = Calendar.current.date(
                byAdding: .day,
                value: 1,
                to: Calendar.current.startOfDay(for: .now)
            ) ?? Date().addingTimeInterval(86_400)
            guard !item.completed else { return false }
            guard let due = item.dueAt else { return true }
            return due < endOfToday
        }
        case .completed: statusFiltered = scopedItems.filter(\.completed)
        }
        return statusFiltered.sorted(by: reminderSort)
    }

    private var availableLists: [String] {
        Array(Set(items.map(\.listName))).sorted { left, right in
            left.localizedStandardCompare(right) == .orderedAscending
        }
    }

    private var scopedItems: [TodoReminder] {
        items.filter { item in
            if let selectedList, item.listName != selectedList { return false }
            return true
        }
    }

    private func scopedCount(for value: TodoFilter) -> Int {
        switch value {
        case .pending:
            return scopedItems.filter { !$0.completed }.count
        case .inProgress:
            let endOfToday = Calendar.current.date(
                byAdding: .day,
                value: 1,
                to: Calendar.current.startOfDay(for: .now)
            ) ?? Date().addingTimeInterval(86_400)
            return scopedItems.filter { item in
                guard !item.completed else { return false }
                guard let due = item.dueAt else { return true }
                return due < endOfToday
            }.count
        case .completed:
            return scopedItems.filter(\.completed).count
        }
    }

    private var progressCompleted: Int {
        scopedItems.filter(\.completed).count
    }

    private var progressValue: Double {
        guard !scopedItems.isEmpty else { return 0 }
        return Double(progressCompleted) / Double(scopedItems.count)
    }

    private var progressHeadline: String {
        if scopedItems.isEmpty {
            return "还没有任务"
        }
        return "还剩 \(scopedItems.count - progressCompleted) 项待完成"
    }

    private var progressSubtitle: String {
        if !scopedItems.isEmpty, progressCompleted == scopedItems.count {
            return "所有任务都已完成"
        }
        return "按自己的节奏，逐项完成"
    }

    private var contentTitle: String {
        switch filter {
        case .pending: return "待办便签"
        case .inProgress: return "进行中便签"
        case .completed: return "已完成便签"
        }
    }

    var body: some View {
        if embedded {
            page
        } else {
            NavigationStack {
                page
            }
        }
    }

    private var page: some View {
        ZStack(alignment: .top) {
                WhaleBackdrop().ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            header
                                .id("todo-top")
                            if reminderStatus != "granted" { permissionCard }
                            progressCard
                            filterBar
                            categorySelector
                            content
                            if let errorText { errorBanner(errorText) }
                            hint
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 22)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .refreshable { await reload() }
                    .onTapGesture { composerFocused = false }
                    .onChange(of: filter) { _, _ in
                        withAnimation(motion(0.16)) { proxy.scrollTo("todo-content", anchor: .top) }
                    }
                    .onChange(of: selectedList) { _, _ in
                        withAnimation(motion(0.16)) { proxy.scrollTo("todo-content", anchor: .top) }
                    }
                }

                if let toast {
                    HStack(spacing: 12) {
                        Text(toast).font(.subheadline).foregroundStyle(WhaleTheme.ink)
                        if undoAction != nil {
                            Button("撤销") { undoLastChange() }.font(.subheadline.weight(.semibold)).whaleTouchTarget()
                        }
                    }.padding(.horizontal, 14).padding(.vertical, 4)
                        .background(WhaleTheme.card, in: Capsule()).overlay(Capsule().stroke(WhaleTheme.line))
                        .padding(.top, 8)
                }
            }
            .safeAreaInset(edge: .bottom) {
                composer.padding(.bottom, embedded ? bottomBarInset : 0)
            }
            .navigationBarHidden(true)
            .task { draft = drafts.load(context: "todo"); await reload() }
            .onChange(of: draft) { _, text in drafts.save(text, context: "todo") }
            .sheet(isPresented: $showTimeEditor) {
                TodoTimeEditor(originalTitle: draft, availableLists: availableLists) { title, notes, due, listName in
                    let item = try await model.createTodoReminder(
                        title: title,
                        dueAt: due,
                        notes: notes,
                        listName: listName
                    )
                    draft = ""
                    upsert(item)
                    reveal(item)
                    undoAction = item.deduplicated ? nil : .added(item)
                    showToast(item.deduplicated ? "已有相同提醒" : "已添加 · " + title, undo: !item.deduplicated)
                    return item
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await reload() }
                }
            }
            .sheet(isPresented: $showVoiceSheet) {
                WhaleVoiceInputSheet(
                    onSend: { text in
                        showVoiceSheet = false
                        draft = text
                        submitText(text)
                    },
                    onUseText: { text in
                        showVoiceSheet = false
                        draft = text
                        composerFocused = !text.isEmpty
                    },
                    onCancel: {
                        showVoiceSheet = false
                        composerFocused = false
                    }
                )
            }
            .alert("删除这条待办？", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
                Button("取消", role: .cancel) { pendingDeletion = nil }
                Button("删除", role: .destructive) {
                    if let item = pendingDeletion { performDelete(item) }
                    pendingDeletion = nil
                }
            } message: {
                Text(pendingDeletion?.title ?? "")
            }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                if embedded { onBackToChat?() } else { dismiss() }
            } label: {
                Image(systemName: embedded ? "chevron.left" : "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WhaleTheme.ink)
                    .whaleGlassCircle(size: 44)
            }
            .buttonStyle(.whalePress)
            .accessibilityLabel(embedded ? "回到对话" : "关闭待办")

            VStack(alignment: .leading, spacing: 3) {
                Text("待办")
                    .whaleFont(size: 29, weight: .bold, design: .rounded)
                    .foregroundStyle(WhaleTheme.ink)
                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                    .whaleFont(size: 13)
                    .foregroundStyle(WhaleTheme.muted)
            }

            Spacer(minLength: 8)

            Button {
                composerFocused = false
                showTimeEditor = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(width: 48, height: 48)
                    .background(Color.primary, in: Circle())
            }
            .buttonStyle(.whalePress)
            .accessibilityLabel("新建任务")
            .accessibilityIdentifier("todo-new-task")
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("需要提醒事项权限", systemImage: "checklist")
                .whaleFont(size: 15, weight: .semibold)
                .foregroundStyle(WhaleTheme.ink)

            Text(reminderPermissionDescription)
                .whaleFont(size: 13)
                .foregroundStyle(WhaleTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if reminderStatus == "denied" || reminderStatus == "restricted" {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                } else {
                    Task {
                        await model.requestPermission("reminder")
                        await reload()
                        if reminderStatus != "granted" {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            await UIApplication.shared.open(url)
                        }
                    }
                }
            } label: {
                Text(reminderPermissionAction)
                    .whaleFont(size: 14, weight: .semibold)
                    .foregroundStyle(WhaleTheme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(WhaleTheme.auroraGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .whaleCard(padding: 16)
    }

    private var reminderPermissionDescription: String {
        switch reminderStatus {
        case "denied":
            return "权限已被拒绝。请到 设置 › 隐私与安全性 › 提醒事项 中允许鲸鱼访问；返回后会自动刷新。"
        case "restricted":
            return "系统当前限制了提醒事项访问。请检查屏幕使用时间、设备管理或家长控制设置。"
        case "addOnly":
            return "当前只允许“添加”，鲸鱼无法读取已有待办。请升级为完整访问，才能显示和勾选提醒事项。"
        default:
            return "允许后，这里会直接显示手机里真实的提醒事项，新增和勾选也会写回系统。"
        }
    }

    private var reminderPermissionAction: String {
        switch reminderStatus {
        case "denied", "restricted": return "打开系统设置"
        case "addOnly": return "升级为完整访问"
        default: return "允许访问提醒事项"
        }
    }

    private var filterBar: some View {
        HStack(spacing: 4) {
            filterButton(.pending, count: scopedCount(for: .pending))
            filterButton(.inProgress, count: scopedCount(for: .inProgress))
            filterButton(.completed, count: scopedCount(for: .completed))
        }
        .padding(4)
        .background(WhaleTheme.field, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.7)
        }
    }

    private var progressCard: some View {
        return VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 17) {
                ZStack {
                    Circle()
                        .stroke(WhaleTheme.line.opacity(0.58), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: progressValue)
                        .stroke(
                            WhaleTheme.auroraGradient,
                            style: StrokeStyle(lineWidth: 9, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(motion(0.24), value: progressValue)
                    VStack(spacing: 0) {
                        Text("\(Int((progressValue * 100).rounded()))%")
                            .whaleFont(size: 21, weight: .bold, design: .rounded)
                            .foregroundStyle(WhaleTheme.ink)
                            .monospacedDigit()
                        Text("完成")
                            .whaleFont(size: 12, weight: .medium)
                            .foregroundStyle(WhaleTheme.muted)
                    }
                }
                .frame(width: 88, height: 88)

                VStack(alignment: .leading, spacing: 7) {
                    Label("任务进度", systemImage: "chart.line.uptrend.xyaxis")
                        .whaleFont(size: 13, weight: .semibold)
                        .foregroundStyle(WhaleTheme.accent)
                    Text(progressHeadline)
                        .whaleFont(size: 21, weight: .bold, design: .rounded)
                        .foregroundStyle(WhaleTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(progressSubtitle)
                        .whaleFont(size: 13)
                        .foregroundStyle(WhaleTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(WhaleTheme.line.opacity(0.72))
                .frame(height: 0.7)

            HStack(spacing: 0) {
                progressMetric("\(scopedItems.count)", label: "全部")
                progressDivider
                progressMetric("\(progressCompleted)", label: "已完成")
                progressDivider
                progressMetric("\(scopedItems.count - progressCompleted)", label: "待完成")
            }
        }
        .padding(18)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(WhaleTheme.card.opacity(0.92))
                LinearGradient(
                    colors: [WhaleTheme.accentSoft.opacity(0.9), .clear, WhaleTheme.moon.opacity(0.07)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.8)
        }
        .whaleSoftElevation()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("任务完成进度，共 \(scopedItems.count) 项，已完成 \(progressCompleted) 项")
        .accessibilityIdentifier("todo-progress-card")
    }

    private func progressMetric(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .whaleFont(size: 18, weight: .bold, design: .rounded)
                .foregroundStyle(WhaleTheme.ink)
                .monospacedDigit()
            Text(label)
                .whaleFont(size: 12, weight: .medium)
                .foregroundStyle(WhaleTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var progressDivider: some View {
        Rectangle()
            .fill(WhaleTheme.line.opacity(0.72))
            .frame(width: 0.7, height: 28)
    }

    @ViewBuilder
    private var categorySelector: some View {
        if availableLists.count > 1 {
            VStack(alignment: .leading, spacing: 9) {
                Text("列表")
                    .whaleFont(size: 13, weight: .semibold)
                    .foregroundStyle(WhaleTheme.muted)
                WhaleFlowLayout(spacing: 8, lineSpacing: 8) {
                    categoryButton(nil, title: "全部", icon: "square.grid.2x2")
                    ForEach(availableLists, id: \.self) { list in
                        categoryButton(list, title: list, icon: categoryIcon(for: list))
                    }
                }
            }
        }
    }

    private func categoryButton(_ list: String?, title: String, icon: String) -> some View {
        let selected = selectedList == list
        return Button {
            withAnimation(motion(0.14)) { selectedList = list }
        } label: {
            Label(title, systemImage: icon)
                .whaleFont(size: 13, weight: .semibold)
                .foregroundStyle(selected ? Color(uiColor: .systemBackground) : WhaleTheme.ink)
                .padding(.horizontal, 13)
                .frame(minHeight: 38)
                .background(
                    Capsule().fill(selected ? Color.primary : WhaleTheme.card.opacity(0.78))
                )
                .overlay(Capsule().strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.7))
                .contentShape(Capsule())
        }
        .buttonStyle(.whalePress)
    }

    private func categoryIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("工作") || lower.contains("work") { return "briefcase.fill" }
        if lower.contains("生活") || lower.contains("personal") { return "person.fill" }
        if lower.contains("学习") || lower.contains("study") { return "book.fill" }
        return "folder.fill"
    }

    private func filterButton(_ value: TodoFilter, count: Int) -> some View {
        Button {
            withAnimation(motion(0.14)) { filter = value }
        } label: {
            HStack(spacing: 5) {
                Text(value.title)
                Text("\(count)")
                    .whaleFont(size: 12, weight: .bold, design: .rounded)
                    .monospacedDigit()
                    .opacity(0.68)
            }
            .whaleFont(size: 13, weight: .semibold)
            .foregroundStyle(filter == value ? Color(uiColor: .systemBackground) : WhaleTheme.muted)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(filter == value ? Color.primary : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.whalePress)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text(contentTitle)
                    .whaleFont(size: 20, weight: .bold, design: .rounded)
                    .foregroundStyle(WhaleTheme.ink)
                Spacer(minLength: 8)
                Text("\(visibleItems.count) 项")
                    .whaleFont(size: 13, weight: .medium)
                    .foregroundStyle(WhaleTheme.muted)
            }

            if isLoading && items.isEmpty {
                HStack(spacing: 9) {
                    ProgressView().scaleEffect(0.8)
                    Text("正在读取提醒事项…")
                        .whaleFont(size: 13)
                        .foregroundStyle(WhaleTheme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if visibleItems.isEmpty {
                emptyState
            } else {
                LazyVStack(alignment: .leading, spacing: 15) {
                    ForEach(TodoTimeGroup.allCases) { group in
                        let grouped = visibleItems
                            .filter { TodoTimeGroup.resolve($0.dueAt) == group }
                            .sorted(by: reminderSort)

                        if !grouped.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(group.title, systemImage: group.icon)
                                    .whaleFont(size: 13, weight: .semibold)
                                    .foregroundStyle(WhaleTheme.muted)
                                    .padding(.leading, 2)

                                ForEach(Array(grouped.enumerated()), id: \.element.id) { index, item in
                                    TodoStickyNote(
                                        item: item,
                                        busy: busyIds.contains(item.id),
                                        featured: index == 0,
                                        onToggle: { toggle(item) },
                                        onDelete: { delete(item) }
                                    )
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                    }
                }
            }
        }
        .id("todo-content")
    }

    private var emptyState: some View {
        VStack(spacing: 11) {
            Image(systemName: emptyIcon)
                .whaleFont(size: 30, weight: .light)
                .foregroundStyle(WhaleTheme.accent)
            Text(emptyTitle)
                .whaleFont(size: 15, weight: .semibold)
                .foregroundStyle(WhaleTheme.ink)
            Text(emptyHint)
                .whaleFont(size: 13)
                .foregroundStyle(WhaleTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                composerFocused = false
                showTimeEditor = true
            } label: {
                Label("新建任务", systemImage: "plus")
                    .whaleFont(size: 14, weight: .semibold)
                    .foregroundStyle(WhaleTheme.accent)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(WhaleTheme.accentSoft, in: Capsule())
            }
            .buttonStyle(.whalePress)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(WhaleTheme.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.7)
        }
    }

    private var emptyIcon: String {
        switch filter {
        case .pending: return "checkmark.circle"
        case .inProgress: return "clock.badge.checkmark"
        case .completed: return "archivebox"
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .pending: return "还没有待办"
        case .inProgress: return "没有进行中的事项"
        case .completed: return "还没有已完成事项"
        }
    }

    private var emptyHint: String {
        switch filter {
        case .pending: return "为新任务补充标题、描述和提醒时间，或直接使用下面的快速输入。"
        case .inProgress: return "今天到期或已逾期的未完成事项会显示在这里。"
        case .completed: return "勾掉的事会出现在这里，可以再恢复。"
        }
    }

    private func reminderSort(_ left: TodoReminder, _ right: TodoReminder) -> Bool {
        switch (left.dueAt, right.dueAt) {
        case let (leftDate?, rightDate?):
            return leftDate == rightDate
                ? left.title.localizedStandardCompare(right.title) == .orderedAscending
                : leftDate < rightDate
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return left.title.localizedStandardCompare(right.title) == .orderedAscending
        }
    }

    private var hint: some View {
        Text("点击 + 新建完整任务；下方可快速输入或语音添加。「完成 买菜」勾掉，「删除 买菜」移除。")
            .whaleFont(size: 13)
            .foregroundStyle(WhaleTheme.muted.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle").font(.subheadline).foregroundStyle(WhaleTheme.warm)
            if message.contains("提醒时间") {
                Button("补充具体时间") { showTimeEditor = true }.font(.body).whaleTouchTarget()
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(WhaleTheme.soft, in: RoundedRectangle(cornerRadius: 14))
    }

    private var composer: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Button {
                    composerFocused = false
                    showVoiceSheet = true
                } label: {
                    Image(systemName: "mic.fill")
                        .whaleFont(size: 17, weight: .semibold)
                        .foregroundStyle(WhaleTheme.accent)
                        .frame(width: 44, height: 44)
                        .background(WhaleTheme.accentSoft, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
                .accessibilityLabel("语音新增待办")
                .accessibilityIdentifier("open-todo-voice-sheet")

                TextField("记一件事，或点击麦克风", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .whaleFont(size: 14)
                    .focused($composerFocused)
                    .submitLabel(.return)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button { submitDraft() } label: {
                    ZStack {
                        Circle()
                            .fill(WhaleTheme.auroraGradient)
                            .frame(width: 44, height: 44)
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(WhaleTheme.onAccent)
                        } else {
                            Image(systemName: "arrow.up")
                                .whaleFont(size: 14, weight: .bold)
                                .foregroundStyle(WhaleTheme.onAccent)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                .accessibilityLabel("提交待办")
            }
            .padding(.leading, 13)
            .padding(.trailing, 7)
            .padding(.vertical, 7)
            .background(WhaleTheme.field, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.8)
            )

            Text("点击提交后保存；语音识别后可先检查内容")
                .whaleFont(size: 13)
                .foregroundStyle(WhaleTheme.muted.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.top, 9)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func submitDraft() {
        submitText(draft)
    }

    private func submitText(_ text: String) {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !isSubmitting else { return }
        errorText = nil
        undoAction = nil
        isSubmitting = true

        Task {
            do {
                if let command = TodoQuickCommand.parse(raw) {
                    let message = try await run(command)
                    draft = ""
                    await reload(silent: true)
                    showToast(message, undo: undoAction != nil)
                } else {
                    let parsed = TodoQuickParser.parseAdd(raw)
                    if let message = parsed.validationError {
                        throw ToolExecutionError(code: "needs_clarification", message: message)
                    }
                    let title = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty else {
                        throw ToolExecutionError(code: "empty_reminder", message: "写点具体内容再添加。")
                    }
                    let item = try await model.createTodoReminder(title: title, dueAt: parsed.dueAt)
                    draft = ""
                    upsert(item)
                    reveal(item)
                    undoAction = item.deduplicated ? nil : .added(item)
                    await reload(silent: true)
                    if let dueAt = parsed.dueAt {
                        showToast(item.deduplicated ? "已有相同提醒" : "已添加 · \(dueText(dueAt))", undo: !item.deduplicated)
                    } else {
                        showToast(item.deduplicated ? "已有相同提醒" : "已添加 · \(item.title)", undo: !item.deduplicated)
                    }
                }
            } catch {
                errorText = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    private func run(_ command: TodoQuickCommand) async throws -> String {
        switch command {
        case .complete(let keyword):
            let target = try uniqueMatch(keyword, in: pendingItems, missing: "没有找到未完成的「\(keyword)」。")
            let updated = try await model.setTodoReminder(target, completed: true)
            upsert(updated)
            undoAction = .completion(before: target, after: updated)
            return "已完成 · \(target.title)"
        case .restore(let keyword):
            let target = try uniqueMatch(keyword, in: completedItems, missing: "没有找到已完成的「\(keyword)」。")
            let updated = try await model.setTodoReminder(target, completed: false)
            upsert(updated)
            undoAction = .completion(before: target, after: updated)
            return "已恢复 · \(target.title)"
        case .delete(let keyword):
            let target = try uniqueMatch(keyword, in: items, missing: "没有找到「\(keyword)」。")
            pendingDeletion = target
            return "请核对要删除的待办"
        }
    }

    private func uniqueMatch(_ keyword: String, in source: [TodoReminder], missing: String) throws -> TodoReminder {
        let key = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let exact = source.filter { $0.title.caseInsensitiveCompare(key) == .orderedSame }
        let matches = exact.isEmpty ? source.filter { $0.title.localizedCaseInsensitiveContains(key) } : exact
        if matches.isEmpty { throw ToolExecutionError(code: "reminder_not_found", message: missing) }
        if matches.count > 1 {
            let names = matches.prefix(3).map(\.title).joined(separator: "、")
            throw ToolExecutionError(
                code: "ambiguous_reminder",
                message: "有 \(matches.count) 条匹配「\(key)」：\(names)。请写更完整的标题。"
            )
        }
        return matches[0]
    }

    private func toggle(_ item: TodoReminder) {
        guard !busyIds.contains(item.id) else { return }
        busyIds.insert(item.id)
        errorText = nil
        Task {
            do {
                let updated = try await model.setTodoReminder(item, completed: !item.completed)
                withAnimation(motion(0.18)) {
                    upsert(updated)
                }
                undoAction = .completion(before: item, after: updated)
                await reload(silent: true)
                showToast(item.completed ? "已恢复 · \(item.title)" : "已完成 · \(item.title)", undo: true)
            } catch {
                errorText = error.localizedDescription
            }
            busyIds.remove(item.id)
        }
    }

    private func delete(_ item: TodoReminder) {
        pendingDeletion = item
    }

    private func performDelete(_ item: TodoReminder) {
        guard !busyIds.contains(item.id) else { return }
        busyIds.insert(item.id)
        errorText = nil
        Task {
            do {
                try await model.deleteTodoReminder(item)
                withAnimation(motion(0.18)) {
                    removeLocal(item.id)
                }
                await reload(silent: true)
                showToast("已删除 · \(item.title)")
            } catch {
                errorText = error.localizedDescription
            }
            busyIds.remove(item.id)
        }
    }

    private func reload(silent: Bool = false) async {
        guard !isLoading else { return }
        model.refreshPermissions()
        guard reminderStatus == "granted" else { items = []; return }
        isLoading = true
        if !silent { errorText = nil }
        defer { isLoading = false }
        do {
            items = try await model.loadTodoReminders(includeCompleted: true)
            if let selectedList, !items.contains(where: { $0.listName == selectedList }) {
                self.selectedList = nil
            }
            model.refreshPermissions()
        } catch {
            let permissionDenied = (error as? ToolExecutionError)?.code == "permission_denied"
            if !permissionDenied || items.isEmpty {
                errorText = error.localizedDescription
            }
            model.refreshPermissions()
        }
    }

    private func upsert(_ item: TodoReminder) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        items.sort { left, right in
            if left.completed != right.completed { return !left.completed }
            switch (left.dueAt, right.dueAt) {
            case let (leftDate?, rightDate?): return leftDate < rightDate
            case (_?, nil): return true
            case (nil, _?): return false
            default: return left.title.localizedStandardCompare(right.title) == .orderedAscending
            }
        }
    }

    private func reveal(_ item: TodoReminder) {
        filter = .pending
        selectedList = nil
    }

    private func motion(_ duration: Double) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: duration)
    }

    private func removeLocal(_ id: String) {
        items.removeAll { $0.id == id }
    }

    private func showToast(_ text: String, undo: Bool = false) {
        toast = text
        if !undo { undoAction = nil }
        undoExpiresAt = Date().addingTimeInterval(8)
        let expires = undoExpiresAt
        Task {
            try? await Task.sleep(nanoseconds: undo ? 8_000_000_000 : 3_000_000_000)
            if undoExpiresAt == expires { toast = nil; undoAction = nil }
        }
    }

    private func undoLastChange() {
        guard let action = undoAction, !isSubmitting else { return }
        let pressedAt = Date()
        let expiry = undoExpiresAt
        guard pressedAt <= expiry else { undoAction = nil; return }
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                let latest = try await model.loadTodoReminders(includeCompleted: true)
                let current = latest.first { $0.id == action.expected.id }
                guard action.canUndo(current: current, now: pressedAt, expiresAt: expiry) else {
                    throw ToolExecutionError(code: "undo_changed", message: "事项已变化或撤销时间已过，请到待办里核对。")
                }
                switch action {
                case .added(let item): try await model.deleteTodoReminder(item); removeLocal(item.id)
                case .completion(let before, let after): let restored = try await model.setTodoReminder(after, completed: before.completed); upsert(restored)
                }
                showToast("已撤销本次修改")
                await reload(silent: true)
            } catch { errorText = error.localizedDescription }
        }
    }

    private func dueText(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "今天 \(time)" }
        if calendar.isDateInTomorrow(date) { return "明天 \(time)" }
        return date.formatted(.dateTime.month().day().hour().minute())
    }

}
