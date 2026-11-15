import SwiftUI

/// 待办页只展示真实存在的日历、待办和当前执行状态。
/// 没有历史数据时显示 0，不补造「本周完成 12 件」这类数字。
struct RecordsView: View {
    var onOpenAssistant: () -> Void = { }
    var resetToken: Int = 0
    var requestedEventID: String?
    var eventRequest: Int

    @Environment(AppState.self) private var state
    @State private var filter: RecordFilter = .all
    @State private var query = ""
    @State private var searchVisible = false
    @State private var selected: ExecutionRecord?
    @State private var showNewTodo = false
    @State private var newTodoTitle = ""
    @State private var newTodoHasDue = false
    @State private var newTodoDue = Date().addingTimeInterval(3600)
    @State private var savingTodo = false
    @State private var todoErrorMessage: String?
    @State private var completingTodo = false
    @State private var detailErrorMessage: String?

    private enum RecordFilter: String, CaseIterable, Identifiable {
        case all = "全部"
        case done = "已完成"
        case doing = "进行中"
        case todo = "待办"

        var id: String { rawValue }
    }

    private enum RecordStatus: Equatable {
        case completed
        case doing
        case todo
        case scheduled
        case ended

        var title: String {
            switch self {
            case .completed: return "已完成"
            case .doing: return "进行中"
            case .todo: return "待办"
            case .scheduled: return "待安排"
            case .ended: return "已结束"
            }
        }

        var color: Color {
            switch self {
            case .completed: return CardPalette.success
            case .doing: return CardPalette.accent2
            case .todo: return CardPalette.amber
            case .scheduled: return CardPalette.accent
            case .ended: return CardPalette.subtle
            }
        }
    }

    private struct ExecutionRecord: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let date: Date
        let symbol: String
        let status: RecordStatus
        let source: String
        let actionNote: String
        var todoID: String?
    }

    private var allRecords: [ExecutionRecord] {
        let now = Date()

        let meetings = state.meetings.map { meeting -> ExecutionRecord in
            let end = meeting.end ?? meeting.start
            let status: RecordStatus
            if end <= now {
                status = .ended
            } else if meeting.start <= now {
                status = .doing
            } else {
                status = .scheduled
            }

            let place = meeting.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let time = meeting.isAllDay ? "全天" : timeText(meeting.start)
            let subtitle = [time, place].filter { !$0.isEmpty }.joined(separator: " · ")

            return ExecutionRecord(
                id: "meeting-\(meeting.id)",
                title: meeting.title,
                subtitle: subtitle,
                date: meeting.start,
                symbol: "calendar",
                status: status,
                source: "系统日历",
                actionNote: place.isEmpty ? "事件来源：系统日历" : "地点：\(place)",
                todoID: nil
            )
        }

        let todos = state.pendingTodos.map { todo -> ExecutionRecord in
            let date = todo.due ?? .distantFuture
            let due = todo.due.map { dueText($0) } ?? "没有截止时间"

            return ExecutionRecord(
                id: "todo-\(todo.id)",
                title: todo.title,
                subtitle: due,
                date: date,
                symbol: "checkmark.circle",
                status: .todo,
                source: "提醒事项",
                actionNote: "完成动作会写回系统提醒事项。",
                todoID: todo.id
            )
        }

        let completedTodos = state.completedTodos.map { todo -> ExecutionRecord in
            let completedAt = todo.completedAt ?? todo.due ?? now
            return ExecutionRecord(
                id: "completed-todo-\(todo.id)",
                title: todo.title,
                subtitle: "完成于 \(fullDateText(completedAt))",
                date: completedAt,
                symbol: "checkmark.circle.fill",
                status: .completed,
                source: "提醒事项",
                actionNote: "已完成，历史来自系统提醒事项。",
                todoID: nil
            )
        }

        return (meetings + todos + completedTodos).sorted { $0.date < $1.date }
    }

    private var visibleRecords: [ExecutionRecord] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return allRecords.filter { record in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .done:
                matchesFilter = record.status == .completed
            case .doing:
                matchesFilter = record.status == .doing
            case .todo:
                matchesFilter = record.status == .todo
            }

            let matchesQuery = needle.isEmpty
                || record.title.localizedCaseInsensitiveContains(needle)
                || record.subtitle.localizedCaseInsensitiveContains(needle)

            return matchesFilter && matchesQuery
        }
    }

    private var groupedRecords: [(String, [ExecutionRecord])] {
        let calendar = Calendar.current
        let today = visibleRecords.filter { calendar.isDateInToday($0.date) }
        let upcoming = visibleRecords.filter { !calendar.isDateInToday($0.date) && $0.date > Date() }
        let past = visibleRecords.filter { !calendar.isDateInToday($0.date) && $0.date < Date() }

        return [
            ("今天", today),
            ("接下来", upcoming),
            ("更早", past)
        ].filter { !$0.1.isEmpty }
    }

    private var doneCount: Int { allRecords.filter { $0.status == .completed }.count }
    private var doingCount: Int { allRecords.filter { $0.status == .doing }.count }
    private var todoCount: Int { allRecords.filter { $0.status == .todo }.count }
    private var meetingCount: Int {
        allRecords.filter { $0.id.hasPrefix("meeting-") }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        recordHero
                        statStrip
                        filterBar
                        searchField

                        if groupedRecords.isEmpty {
                            emptyState
                        } else {
                            ForEach(groupedRecords, id: \.0) { group in
                                recordGroup(title: group.0, records: group.1)
                            }
                        }

                        sourceNote
                    }
                    .id("records-top")
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: resetToken) { _, _ in
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo("records-top", anchor: .top)
                    }
                }
            }
        }
        .onAppear(perform: openRequestedEventIfNeeded)
        .onChange(of: eventRequest) { _, _ in
            openRequestedEventIfNeeded()
        }
        .sheet(item: $selected) { record in
            recordDetail(record)
                .onAppear {
                    detailErrorMessage = nil
                    completingTodo = false
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(CardPalette.solid)
        }
        .sheet(isPresented: $showNewTodo) {
            newTodoSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(CardPalette.solid)
                .interactiveDismissDisabled(savingTodo)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("待办")
                    .font(.nomiScaled(size: 30, weight: .bold))
                    .tracking(-0.9)
                    .foregroundStyle(CardPalette.ink)
                Text("每一件事，都有来源和状态")
                    .font(.nomiScaled(size: 11.5))
                    .foregroundStyle(CardPalette.subtle)
            }

            Spacer()

            Button {
                resetNewTodo()
                showNewTodo = true
            } label: {
                Image(systemName: "plus")
                    .font(.nomiScaled(size: 15, weight: .bold))
                    .foregroundStyle(CardPalette.navyInk)
                    .frame(width: 44, height: 44)
                    .background(CardPalette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(WhalePressStyle())
            .accessibilityLabel("新建待办")

            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    searchVisible.toggle()
                    if !searchVisible { query = "" }
                }
            } label: {
                Image(systemName: searchVisible ? "xmark" : "magnifyingglass")
                    .font(.nomiScaled(size: 15, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(CardPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(CardPalette.line, lineWidth: 1)
                    }
            }
            .buttonStyle(WhalePressStyle())
            .accessibilityLabel(searchVisible ? "关闭搜索" : "搜索记录")
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var recordHero: some View {
        WhaleGlassCard(radius: 26, padding: 18) {
            HStack(spacing: 18) {
                ProgressRing(
                    progress: doneCount + todoCount == 0
                        ? 0
                        : Double(doneCount) / Double(doneCount + todoCount),
                    color: CardPalette.accent
                )
                .frame(width: 92, height: 92)
                .overlay {
                    VStack(spacing: 1) {
                        Text("\(doneCount)")
                            .font(.nomiScaled(size: 27, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(CardPalette.ink)
                        Text("已完成")
                            .font(.nomiScaled(size: 10, weight: .medium))
                            .foregroundStyle(CardPalette.subtle)
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    WhalePill(text: "最近 30 天", symbol: "waveform.path.ecg", color: CardPalette.accent)

                    Text(heroMessage)
                        .font(.nomiScaled(size: 20, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(CardPalette.ink)
                        .lineSpacing(2)

                    Text(summaryLine)
                        .font(.nomiScaled(size: 11.5))
                        .foregroundStyle(CardPalette.subtle)
                        .lineSpacing(2)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var heroMessage: String {
        if allRecords.isEmpty {
            return "最近还没有记录。"
        }
        if todoCount > 0 {
            return "还有 \(todoCount) 件待办。"
        }
        if doneCount > 0 {
            return "最近 30 天完成了 \(doneCount) 件待办。"
        }
        return "今天有 \(meetingCount) 个日程。"
    }

    private var summaryLine: String {
        if allRecords.isEmpty {
            return "日历和提醒事项里暂时没有可展示的内容。"
        }
        var parts: [String] = []
        if doingCount > 0 { parts.append("\(doingCount) 件进行中") }
        if todoCount > 0 { parts.append("\(todoCount) 件待办") }
        if doneCount > 0 { parts.append("\(doneCount) 件已完成") }
        if parts.isEmpty { parts.append("\(meetingCount) 个日程") }
        return parts.joined(separator: " · ")
    }

    private var statStrip: some View {
        HStack(spacing: 0) {
            statCell(value: doneCount, label: "已完成", color: CardPalette.success)
            divider
            statCell(value: doingCount, label: "进行中", color: CardPalette.accent2)
            divider
            statCell(value: todoCount, label: "待办", color: CardPalette.amber)
        }
        .padding(.vertical, 12)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }

    private func statCell(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.nomiScaled(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(CardPalette.ink)
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(label)
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.subtle)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(CardPalette.line)
            .frame(width: 0.6, height: 34)
    }

    private var filterBar: some View {
        HStack(spacing: 4) {
            ForEach(RecordFilter.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                        filter = item
                    }
                } label: {
                    Text(item.rawValue)
                        .font(.nomiScaled(size: 12, weight: filter == item ? .semibold : .medium))
                        .foregroundStyle(filter == item ? CardPalette.ink : CardPalette.subtle)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background {
                            if filter == item {
                                Capsule()
                                    .fill(CardPalette.accent.opacity(0.12))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(CardPalette.raised)
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(CardPalette.line, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var searchField: some View {
        if searchVisible {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.nomiScaled(size: 13, weight: .medium))
                    .foregroundStyle(CardPalette.subtle)

                TextField("搜索记录", text: $query)
                    .font(.nomiScaled(size: 14))
                    .foregroundStyle(CardPalette.ink)

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CardPalette.faint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func recordGroup(title: String, records: [ExecutionRecord]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                    .font(.nomiScaled(size: 13, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Spacer()
                Text("\(records.count) 项")
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.faint)
            }

            VStack(spacing: 0) {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    Button {
                        selected = record
                    } label: {
                        recordRow(record)
                    }
                    .buttonStyle(WhalePressStyle(scale: 0.985))

                    if index < records.count - 1 {
                        WhaleRowDivider(leading: 50)
                    }
                }
            }
            .background(CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            }
        }
    }

    private func recordRow(_ record: ExecutionRecord) -> some View {
        HStack(spacing: 11) {
            WhaleIconTile(
                symbol: record.symbol,
                color: record.status.color,
                size: 34
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(.nomiScaled(size: 14.5, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                    .lineLimit(1)
                Text(record.subtitle.isEmpty ? record.source : record.subtitle)
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.subtle)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            WhalePill(text: record.status.title, color: record.status.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        WhaleGlassCard(radius: 22, padding: 20) {
            VStack(spacing: 10) {
                NomiAvatar(size: 48, expression: .calm)
                Text("这一类还没有记录")
                    .font(.nomiScaled(size: 17, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Text(allRecords.isEmpty
                     ? "日历和提醒事项里没有内容，可以先让 Nomi 记一件事。"
                     : "换个筛选条件看看其他状态。")
                    .font(.nomiScaled(size: 12.5))
                    .foregroundStyle(CardPalette.subtle)
                    .multilineTextAlignment(.center)

                if allRecords.isEmpty {
                    HStack(spacing: 14) {
                        Button {
                            resetNewTodo()
                            showNewTodo = true
                        } label: {
                            Text("新建待办")
                                .font(.nomiScaled(size: 13, weight: .semibold))
                                .foregroundStyle(CardPalette.navyInk)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 42)
                                .background(CardPalette.accent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(WhalePressStyle())

                        Button {
                            onOpenAssistant()
                        } label: {
                            Text("告诉 Nomi")
                                .font(.nomiScaled(size: 13, weight: .semibold))
                                .foregroundStyle(CardPalette.accent)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(WhalePressStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func openRequestedEventIfNeeded() {
        guard let requestedEventID,
              let record = allRecords.first(where: { $0.id == "meeting-\(requestedEventID)" })
        else { return }
        selected = record
    }

    private var sourceNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield")
                .font(.nomiScaled(size: 10, weight: .medium))
            Text("记录来自系统日历和提醒事项，不会补造已完成状态。")
                .font(.nomiScaled(size: 10.5))
        }
        .foregroundStyle(CardPalette.faint)
        .padding(.top, 2)
    }

    private var newTodoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    WhaleGlassCard(radius: 20, padding: 15) {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("要做什么？")
                                .font(.nomiScaled(size: 11.5, weight: .semibold))
                                .foregroundStyle(CardPalette.subtle)

                            TextField("例如：明天下午整理产品评审意见", text: $newTodoTitle)
                                .font(.nomiScaled(size: 16))
                                .foregroundStyle(CardPalette.ink)
                                .submitLabel(.done)
                        }
                    }

                    WhaleGlassCard(radius: 20, padding: 15) {
                        VStack(alignment: .leading, spacing: 13) {
                            Toggle("设置截止时间", isOn: $newTodoHasDue)
                                .font(.nomiScaled(size: 14.5, weight: .medium))
                                .foregroundStyle(CardPalette.ink)
                                .tint(CardPalette.accent)

                            if newTodoHasDue {
                                DatePicker(
                                    "截止时间",
                                    selection: $newTodoDue,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .font(.nomiScaled(size: 13.5))
                                .foregroundStyle(CardPalette.ink)
                                .tint(CardPalette.accent)
                            }
                        }
                    }

                    if let todoErrorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.nomiScaled(size: 13, weight: .semibold))
                            Text(todoErrorMessage)
                                .font(.nomiScaled(size: 12))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(CardPalette.amberInk)
                        .padding(12)
                        .background(CardPalette.amberSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                }
                .padding(18)
                .padding(.bottom, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                saveTodoButton
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(CardPalette.chrome.opacity(0.94))
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(CardPalette.line)
                            .frame(height: 0.6)
                    }
            }
            .background(AppBackground())
            .navigationTitle("新建待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showNewTodo = false
                    }
                    .disabled(savingTodo)
                }
            }
        }
        .preferredColorScheme(state.settings.appearance.colorScheme)
    }

    private var saveTodoButton: some View {
        Button {
            saveNewTodo()
        } label: {
            Group {
                if savingTodo {
                    ProgressView()
                        .tint(CardPalette.navyInk)
                } else {
                    Text("创建待办")
                        .font(.nomiScaled(size: 14.5, weight: .bold))
                }
            }
            .foregroundStyle(CardPalette.navyInk)
            .frame(maxWidth: .infinity)
            .frame(height: 49)
            .background(CardPalette.accent)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(WhalePressStyle())
        .disabled(
            savingTodo
                || newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .opacity(
            newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? 0.48
                : 1
        )
    }

    private func resetNewTodo() {
        newTodoTitle = ""
        newTodoHasDue = false
        newTodoDue = Date().addingTimeInterval(3600)
        todoErrorMessage = nil
        savingTodo = false
    }

    private func saveNewTodo() {
        let title = newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !savingTodo else { return }

        savingTodo = true
        todoErrorMessage = nil

        Task {
            let created = await state.createTodo(
                title: title,
                due: newTodoHasDue ? newTodoDue : nil
            )
            savingTodo = false

            if created {
                showNewTodo = false
                resetNewTodo()
            } else {
                todoErrorMessage = "没有写进系统提醒事项。请检查提醒事项权限后再试。"
            }
        }
    }

    private func recordDetail(_ record: ExecutionRecord) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 13) {
                    WhaleIconTile(symbol: record.symbol, color: record.status.color, size: 46)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.title)
                            .font(.nomiScaled(size: 22, weight: .bold))
                            .foregroundStyle(CardPalette.ink)
                        WhalePill(text: record.status.title, color: record.status.color)
                    }
                    Spacer()
                }

                WhaleGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        detailLine("来源", record.source)
                        detailLine("时间", fullDateText(record.date))
                        detailLine("说明", record.actionNote)
                    }
                }

                if let todoID = record.todoID {
                    if let detailErrorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                            Text(detailErrorMessage)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.nomiScaled(size: 12))
                        .foregroundStyle(CardPalette.amberInk)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CardPalette.amberSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        Task {
                            completingTodo = true
                            detailErrorMessage = nil
                            let completed = await state.completeTodo(id: todoID)
                            completingTodo = false
                            if completed {
                                selected = nil
                            } else {
                                detailErrorMessage = "没有写回系统提醒事项，这条待办尚未完成。请检查权限后重试。"
                            }
                        }
                    } label: {
                        Group {
                            if completingTodo {
                                ProgressView()
                                    .tint(CardPalette.navyInk)
                            } else {
                                Text("标记完成")
                                    .font(.nomiScaled(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundStyle(CardPalette.navyInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(CardPalette.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(WhalePressStyle())
                    .disabled(completingTodo)
                }

                Spacer()
            }
            .padding(20)
            .background(AppBackground())
            .navigationTitle("执行详情")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(state.settings.appearance.colorScheme)
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.nomiScaled(size: 11.5))
                .foregroundStyle(CardPalette.faint)
                .frame(width: 34, alignment: .leading)
            Text(value)
                .font(.nomiScaled(size: 13.5))
                .foregroundStyle(CardPalette.ink)
            Spacer(minLength: 0)
        }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func dueText(_ date: Date) -> String {
        let calendar = Calendar.current
        if date < Date() { return "已过期 · \(fullDateText(date))" }
        if calendar.isDateInToday(date) { return "今天 \(timeText(date))" }
        if calendar.isDateInTomorrow(date) { return "明天 \(timeText(date))" }
        return fullDateText(date)
    }

    private func fullDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEE HH:mm"
        return formatter.string(from: date)
    }
}

private struct ProgressRing: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(CardPalette.lineStrong, lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.55, dampingFraction: 0.86), value: progress)
        }
    }
}
