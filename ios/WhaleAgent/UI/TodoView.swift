import SwiftUI
import UIKit

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
    var showsHeader: Bool = true
    var hidesNavigationBar: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var todoStore: TodoTimelineStore
    @EnvironmentObject private var navigation: RootNavigationModel
    @StateObject private var voice = VoiceInputController()

    @AppStorage("whale.todo.board") private var board: TodoBoard = .today
    private var items: [TodoReminder] { todoStore.items }
    @AppStorage("whale.draft.todo") private var draft = ""
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
    @State private var quickPreview: TodoQuickPreview?
    @State private var scheduleItem: TodoReminder?
    @FocusState private var composerFocused: Bool
    @State private var voicePrefix = ""
    @State private var voiceSessionID: UUID?
    @State private var voiceDraftIsActive = false

    private var reminderStatus: String { model.permissionsSnapshot["reminder"] ?? "unknown" }
    private var pendingItems: [TodoReminder] { items.filter { !$0.completed } }
    private var completedItems: [TodoReminder] { items.filter(\.completed) }
    private var visibleItems: [TodoReminder] {
        if board == .projects {
            return items
                .filter { !$0.completed && $0.projectName != nil }
                .sorted { left, right in
                    let lhs = left.projectName ?? ""
                    let rhs = right.projectName ?? ""
                    if lhs != rhs { return lhs.localizedStandardCompare(rhs) == .orderedAscending }
                    return (left.dueAt ?? .distantFuture) < (right.dueAt ?? .distantFuture)
                }
        }
        return items.filter { board.includes($0) }
    }

    private var projectGroups: [(String, [TodoReminder])] {
        let grouped = Dictionary(grouping: visibleItems) { $0.projectName ?? "未分组" }
        return grouped
            .map { ($0.key, $0.value) }
            .sorted { $0.0.localizedStandardCompare($1.0) == .orderedAscending }
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
                            if showsHeader {
                                header
                                    .id("todo-top")
                            } else {
                                Color.clear
                                    .frame(height: 0)
                                    .id("todo-top")
                            }
                            if reminderStatus != "granted" { permissionCard }
                            boardBar
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
                    .onChange(of: board) { _, _ in
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("todo-top", anchor: .top) }
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
            .navigationBarHidden(hidesNavigationBar)
            .task { draft = drafts.load(context: "todo"); await reload() }
            .onChange(of: draft) { _, text in drafts.save(text, context: "todo") }
            .sheet(isPresented: $showTimeEditor) {
                TodoTimeEditor(original: draft) { title, due in
                    let item = try await model.createTodoReminder(title: title, dueAt: due)
                    draft = ""; upsert(item); undoAction = item.deduplicated ? nil : .added(item)
                    showToast(item.deduplicated ? "已有相同提醒" : "已添加 · " + title, undo: !item.deduplicated)
                }
            }
            .sheet(item: $scheduleItem) { item in
                TodoScheduleSheet(item: item, model: model) { updated in
                    if let updated {
                        upsert(updated)
                        board = .planned
                        showToast("已安排 · \(dueText(updated.dueAt ?? Date()))", undo: false)
                    }
                    Task { await reload(silent: true) }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await reload() }
                } else {
                    restoreVoiceDraft()
                }
            }
            .onChange(of: voice.transcript) { _, text in
                guard voiceDraftIsActive,
                      let voiceSessionID,
                      voice.currentSessionID == voiceSessionID else { return }
                draft = mergeVoiceDraft(prefix: voicePrefix, recognized: text)
            }
            .onChange(of: voice.finalResult) { _, result in
                guard let result,
                      voiceDraftIsActive,
                      result.sessionId == voiceSessionID,
                      voice.errorText == nil else { return }
                draft = mergeVoiceDraft(prefix: voicePrefix, recognized: result.text)
                voiceDraftIsActive = false
                voiceSessionID = nil
                composerFocused = true
            }
            .onChange(of: voice.errorText) { _, error in
                if error != nil { restoreVoiceDraft() }
            }
            .onDisappear { restoreVoiceDraft() }
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
            WhaleIconTile(systemName: "checklist", size: 46, tint: WhaleTheme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("待办")
                    .whaleFont(size: 24, weight: .bold, design: .rounded)
                    .foregroundStyle(WhaleTheme.ink)
                Text("收件箱、今天、计划和项目，各自有位置")
                    .whaleFont(size: 13)
                    .foregroundStyle(WhaleTheme.muted)
            }
            Spacer(minLength: 8)
            if !embedded || onBackToChat != nil {
                Button {
                    if embedded { onBackToChat?() } else { dismiss() }
                } label: {
                    Image(systemName: embedded ? "bubble.left.and.bubble.right" : "xmark")
                        .font(.system(size: embedded ? 15 : 14, weight: .semibold))
                        .foregroundStyle(WhaleTheme.ink)
                        .whaleGlassCircle(size: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(embedded ? "回到对话" : "关闭待办")
            }
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("需要提醒事项权限", systemImage: "checklist")
                .whaleFont(size: 15, weight: .semibold)
                .foregroundStyle(WhaleTheme.ink)

            Text(reminderStatus == "denied"
                 ? "权限已被拒绝。请到 设置 › 隐私与安全性 › 提醒事项 中允许鲸鱼访问；返回后会自动刷新。"
                 : "允许后，这里会直接显示手机里真实的提醒事项，新增和勾选也会写回系统。")
                .whaleFont(size: 13)
                .foregroundStyle(WhaleTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if reminderStatus == "denied" {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                } else {
                    Task {
                        await model.requestPermission("reminder")
                        await reload()
                    }
                }
            } label: {
                Text(reminderStatus == "denied" ? "打开系统设置" : "允许访问提醒事项")
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

    private var boardBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(TodoBoard.allCases) { value in
                    let count = value == .projects
                        ? Set(items.filter { !$0.completed && $0.projectName != nil }.compactMap(\.projectName)).count
                        : items.filter { value.includes($0) }.count
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { board = value }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: value.icon)
                                .whaleFont(size: 12, weight: .semibold)
                            Text(value.title)
                            Text(count == 0 ? "" : "\(count)")
                                .whaleFont(size: 10, weight: .bold)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    (board == value ? WhaleTheme.onAccent : WhaleTheme.muted).opacity(0.14),
                                    in: Capsule()
                                )
                        }
                        .whaleFont(size: 13, weight: .semibold)
                        .foregroundStyle(board == value ? WhaleTheme.onAccent : WhaleTheme.ink)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 38)
                        .background {
                            Capsule().fill(board == value ? WhaleTheme.accent : WhaleTheme.card.opacity(0.82))
                        }
                        .overlay(Capsule().strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(board == value ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("todo-board-bar")
    }

    @ViewBuilder
    private var content: some View {
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
        } else if board == .projects {
            LazyVStack(alignment: .leading, spacing: 13) {
                ForEach(projectGroups, id: \.0) { group in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 7) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .foregroundStyle(WhaleTheme.accent)
                            Text(group.0)
                                .whaleFont(size: 14, weight: .bold)
                                .foregroundStyle(WhaleTheme.ink)
                            Text("\(group.1.count)")
                                .whaleFont(size: 11, weight: .semibold)
                                .foregroundStyle(WhaleTheme.muted)
                        }
                        ForEach(group.1) { item in
                            row(item)
                        }
                    }
                }
            }
        } else {
            LazyVStack(spacing: 9) {
                ForEach(visibleItems) { item in
                    row(item)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: emptyIcon)
                .whaleFont(size: 28, weight: .light)
                .foregroundStyle(WhaleTheme.muted.opacity(0.7))
            Text(emptyTitle)
                .whaleFont(size: 15, weight: .semibold)
                .foregroundStyle(WhaleTheme.ink)
            Text(emptyHint)
                .whaleFont(size: 13)
                .foregroundStyle(WhaleTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }

    private var emptyIcon: String {
        board.icon
    }

    private var emptyTitle: String {
        board == .inbox ? "收件箱已清空" : board == .today ? "今天没有待办" : board == .planned ? "还没有计划好的事项" : "还没有项目"
    }

    private var emptyHint: String {
        switch board {
        case .inbox: return "没有日期的任务会先放进这里。"
        case .today: return "今天到期或逾期的任务会出现在这里。"
        case .planned: return "写清日期和时间，任务会进入计划。"
        case .projects: return "录入时写「#项目名」即可归入项目。"
        }
    }

    private func row(_ item: TodoReminder) -> some View {
        HStack(alignment: .center, spacing: 11) {
            Button { toggle(item) } label: {
                ZStack {
                    Circle()
                        .strokeBorder(item.completed ? WhaleTheme.success : WhaleTheme.line, lineWidth: 1.6)
                        .background(Circle().fill(item.completed ? WhaleTheme.success.opacity(0.14) : Color.clear))
                        .frame(width: 27, height: 27)
                    if busyIds.contains(item.id) {
                        ProgressView().scaleEffect(0.55)
                    } else if item.completed {
                        Image(systemName: "checkmark")
                            .whaleFont(size: 13, weight: .bold)
                            .foregroundStyle(WhaleTheme.success)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(busyIds.contains(item.id))
            .accessibilityLabel(item.completed ? "恢复 \(item.title)" : "完成 \(item.title)")

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .whaleFont(size: 14, weight: .medium)
                    .foregroundStyle(item.completed ? WhaleTheme.muted : WhaleTheme.ink)
                    .strikethrough(item.completed, color: WhaleTheme.muted)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        navigation.workspacePath.append(.todoDetail(item.id))
                    }

                HStack(spacing: 7) {
                    if let due = item.dueAt {
                        Label(dueText(due), systemImage: "clock")
                            .whaleFont(size: 13, weight: .medium)
                            .foregroundStyle(dueColor(item, due))
                    } else {
                        Text("无日期")
                            .whaleFont(size: 13)
                            .foregroundStyle(WhaleTheme.muted.opacity(0.75))
                    }
                    Text(item.listName)
                        .whaleFont(size: 13, weight: .medium)
                        .foregroundStyle(WhaleTheme.muted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(WhaleTheme.soft, in: Capsule())
                    if let project = item.projectName {
                        Label(project, systemImage: "square.stack.3d.up")
                            .whaleFont(size: 11, weight: .medium)
                            .foregroundStyle(WhaleTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(WhaleTheme.accentSoft, in: Capsule())
                    }
                    if let minutes = item.estimatedMinutes {
                        Label("\(minutes) 分钟", systemImage: "timer")
                            .whaleFont(size: 11, weight: .medium)
                            .foregroundStyle(WhaleTheme.muted)
                    }
                    if item.priority == 1 {
                        Image(systemName: "exclamationmark.2")
                            .whaleFont(size: 11, weight: .bold)
                            .foregroundStyle(WhaleTheme.warm)
                            .accessibilityLabel("高优先级")
                    }
                    if let notes = item.notes, !notes.isEmpty {
                        Image(systemName: "note.text")
                            .whaleFont(size: 13)
                            .foregroundStyle(WhaleTheme.muted.opacity(0.7))
                            .accessibilityLabel("有备注")
                    }
                }
            }

            Spacer(minLength: 4)

            Menu {
                if item.completed {
                    Button("恢复为待办", systemImage: "arrow.uturn.backward") { toggle(item) }
                } else {
                    Button("标记完成", systemImage: "checkmark.circle") { toggle(item) }
                }
                Button("智能排期 / 改期", systemImage: "calendar.badge.clock") {
                    scheduleItem = item
                }
                Button("移入收件箱", systemImage: "tray.and.arrow.down") {
                    rescheduleToInbox(item)
                }
                Button("删除待办", systemImage: "trash", role: .destructive) { delete(item) }
            } label: {
                Image(systemName: "ellipsis")
                    .whaleFont(size: 14, weight: .semibold)
                    .foregroundStyle(WhaleTheme.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(WhaleTheme.card.opacity(item.completed ? 0.55 : 0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.7)
        )
        .contextMenu {
            Button("打开详情", systemImage: "info.circle") {
                navigation.workspacePath.append(.todoDetail(item.id))
            }
            Button("智能排期", systemImage: "calendar.badge.clock") { scheduleItem = item }
            Button("移入收件箱", systemImage: "tray.and.arrow.down") { rescheduleToInbox(item) }
            Button("删除待办", systemImage: "trash", role: .destructive) { delete(item) }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 28)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > 82, abs(dy) < 52, abs(dx) > abs(dy) * 1.45 else { return }
                    composerFocused = false
                    if dx > 0 {
                        toggle(item)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } else {
                        scheduleItem = item
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
        )
        .accessibilityAction(named: item.completed ? "恢复" : "完成") { toggle(item) }
        .accessibilityAction(named: "智能排期") { scheduleItem = item }
    }

    private var hint: some View {
        Text("直接说或写一句；右滑完成，左滑改期。录入「#项目名」和「预计30分钟」会自动归组。")
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
            if let voiceError = voice.errorText {
                Label(voiceError, systemImage: "mic.slash.fill")
                    .whaleFont(size: 13)
                    .foregroundStyle(WhaleTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if voice.isRecording {
                voiceStrip
            }
            if let quickPreview {
                quickPreviewCard(quickPreview)
            }
            HStack(spacing: 8) {
                Button {
                    composerFocused = false
                    if voice.isRecording {
                        voice.stop()
                    } else {
                        Task { await beginVoice() }
                    }
                } label: {
                    Image(systemName: voice.isRecording ? "waveform" : "mic.fill")
                        .whaleFont(size: 17, weight: .semibold)
                        .foregroundStyle(voice.isRecording ? WhaleTheme.onAccent : WhaleTheme.accent)
                        .frame(width: 44, height: 44)
                        .background(
                            voice.isRecording ? WhaleTheme.danger : WhaleTheme.accentSoft,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting || voice.isFinalizing)
                .accessibilityLabel(voice.isRecording ? "停止语音输入" : "语音新增待办")

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
                .accessibilityLabel(quickPreview == nil ? "解析待办" : "更新待办预览")
            }
            .padding(.leading, 13)
            .padding(.trailing, 7)
            .padding(.vertical, 7)
            .background(WhaleTheme.field, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.8)
            )

            Text(quickPreview == nil ? "先解析，再确认写入系统提醒" : "核对项目、时间和预计时长后再添加")
                .whaleFont(size: 13)
                .foregroundStyle(WhaleTheme.muted.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.top, 9)
        .padding(.bottom, 8)
        .background(WhaleTheme.chrome)
    }

    private func quickPreviewCard(_ preview: TodoQuickPreview) -> some View {
        OperationPreviewCard(.todo(preview)) {
            HStack(spacing: 8) {
                Button("取消") {
                    quickPreview = nil
                    composerFocused = true
                }
                .whaleFont(size: 13, weight: .semibold)
                .foregroundStyle(WhaleTheme.muted)
                Spacer()
                Button {
                    Task { await confirmQuickPreview(preview) }
                } label: {
                    Label("确认添加", systemImage: "checkmark.circle.fill")
                        .whaleFont(size: 13, weight: .semibold)
                        .foregroundStyle(WhaleTheme.onAccent)
                        .padding(.horizontal, 13)
                        .frame(minHeight: 36)
                        .background(WhaleTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
        }
    }

    private var voiceStrip: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(WhaleTheme.danger)
                .frame(width: 8, height: 8)
            Text(voice.transcript.isEmpty ? "正在听你说…" : voice.transcript)
                .whaleFont(size: 13, weight: .medium)
                .foregroundStyle(WhaleTheme.ink)
                .lineLimit(2)
            Spacer(minLength: 6)
            Button {
                voice.stop()
            } label: {
                Text("完成")
                    .whaleFont(size: 13, weight: .semibold)
                    .foregroundStyle(WhaleTheme.danger)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(WhaleTheme.danger.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(WhaleTheme.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(WhaleTheme.danger.opacity(0.22), lineWidth: 0.8)
        )
    }

    private func submitDraft() {
        submitText(draft)
    }

    private func beginVoice() async {
        quickPreview = nil
        voicePrefix = draft
        voiceDraftIsActive = true
        voiceSessionID = nil
        await voice.start()
        if voice.isRecording {
            voiceSessionID = voice.currentSessionID
        } else {
            restoreVoiceDraft()
        }
    }

    private func mergeVoiceDraft(prefix: String, recognized: String) -> String {
        let spoken = recognized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return prefix }
        guard !prefix.isEmpty else { return spoken }
        return prefix.last?.isWhitespace == true ? prefix + spoken : prefix + "\n" + spoken
    }

    private func restoreVoiceDraft() {
        voice.cancel()
        if voiceDraftIsActive { draft = voicePrefix }
        voiceDraftIsActive = false
        voiceSessionID = nil
    }

    private func submitText(_ text: String) {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !isSubmitting else { return }
        errorText = nil
        undoAction = nil
        if let command = TodoQuickCommand.parse(raw) {
            isSubmitting = true
            Task {
                do {
                    let message = try await run(command)
                    draft = ""
                    await reload(silent: true)
                    showToast(message, undo: undoAction != nil)
                } catch {
                    errorText = error.localizedDescription
                }
                isSubmitting = false
            }
            return
        }

        let parsed = TodoQuickParser.parsePreview(raw)
        if let rawPreview = TodoQuickParser.parseAdd(raw).validationError {
            errorText = rawPreview
            return
        }
        guard !parsed.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = "写点具体内容再添加。"
            return
        }
        quickPreview = parsed
        composerFocused = false
    }

    private func confirmQuickPreview(_ preview: TodoQuickPreview) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let item = try await model.createTodoReminder(
                title: preview.title,
                dueAt: preview.dueAt,
                project: preview.project,
                estimatedMinutes: preview.estimatedMinutes
            )
            quickPreview = nil
            draft = ""
            board = preview.dueAt == nil ? .inbox : Calendar.current.isDateInToday(preview.dueAt!) ? .today : .planned
            upsert(item)
            undoAction = item.deduplicated ? nil : .added(item)
            await reload(silent: true)
            showToast(
                item.deduplicated ? "已有相同提醒" : "已添加 · \(dueText(item.dueAt ?? Date()))",
                undo: !item.deduplicated
            )
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func rescheduleToInbox(_ item: TodoReminder) {
        guard !busyIds.contains(item.id) else { return }
        busyIds.insert(item.id)
        Task {
            defer { busyIds.remove(item.id) }
            do {
                let updated = try await model.rescheduleTodoReminder(item, dueAt: nil)
                upsert(updated)
                board = .inbox
                showToast("已移入收件箱 · \(item.title)")
            } catch {
                errorText = error.localizedDescription
            }
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
                upsert(updated)
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
                removeLocal(item.id)
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
#if DEBUG
        if TodoDemoMode.isSyncFixture { return }
#endif
        model.refreshPermissions()
        guard reminderStatus == "granted" else {
            todoStore.replaceLoaded([])
            return
        }
        isLoading = true
        if !silent { errorText = nil }
        defer { isLoading = false }
        do {
            let loaded = try await model.loadTodoReminders(includeCompleted: true)
            todoStore.replaceLoaded(loaded)
            todoStore.markLoaded()
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
        todoStore.upsert(item)
    }

    private func removeLocal(_ id: String) {
        todoStore.remove(id: id)
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

    private func dueColor(_ item: TodoReminder, _ date: Date) -> Color {
        if item.completed { return WhaleTheme.muted }
        if date < Date() { return WhaleTheme.danger }
        if Calendar.current.isDateInToday(date) { return WhaleTheme.coral }
        return WhaleTheme.moon
    }
}
