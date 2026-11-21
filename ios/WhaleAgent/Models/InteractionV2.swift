import Foundation

extension String {
    var firstLine: String {
        split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? self
    }
}

enum AgentInteractionPhase: String, Codable, CaseIterable, Equatable {
    case idle
    case listening
    case editable
    case understanding
    case streaming
    case executing
    case awaitingConfirmation
    case completed
    case failed
    case cancelled

    var title: String {
        switch self {
        case .idle: return "待命"
        case .listening: return "正在听"
        case .editable: return "可编辑"
        case .understanding: return "正在理解"
        case .streaming: return "正在回答"
        case .executing: return "正在执行"
        case .awaitingConfirmation: return "等待确认"
        case .completed: return "已完成"
        case .failed: return "未完成"
        case .cancelled: return "已取消"
        }
    }

    var isActive: Bool {
        [.listening, .understanding, .executing, .awaitingConfirmation].contains(self)
    }
}

struct AgentOperationReceipt: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let detail: String
    let status: String
    let phase: AgentInteractionPhase
    let tool: String?
    let createdAt: Date

    var canUndo: Bool {
        ["create_reminder", "update_reminder", "create_calendar_event", "update_calendar_event"].contains(tool)
            && status == "success"
    }
}

struct AgentWorkingContext: Codable, Equatable {
    let goal: String
    let status: AgentInteractionPhase
    var summary: String
    var sourceMessageId: String?
    var updatedAt: Date

    var needsAttention: Bool {
        status == .awaitingConfirmation || status == .failed
    }

    var canContinue: Bool {
        [.executing, .awaitingConfirmation, .failed, .cancelled, .completed].contains(status)
    }
}

final class AgentWorkingContextStore {
    static let shared = AgentWorkingContextStore()
    private let storageKey = "whale.working.context.v2"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(now: Date = Date()) -> AgentWorkingContext? {
        guard let data = defaults.data(forKey: storageKey),
              let context = try? JSONDecoder().decode(AgentWorkingContext.self, from: data),
              now.timeIntervalSince(context.updatedAt) < 24 * 60 * 60 else {
            clear()
            return nil
        }
        return context
    }

    func save(_ context: AgentWorkingContext) {
        guard let data = try? JSONEncoder().encode(context) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}

struct OperationPreviewRow: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let icon: String
}

struct OperationPreview: Equatable {
    enum Kind: String, Equatable {
        case create
        case update
        case delete
        case external
        case save
    }

    let kind: Kind
    let title: String
    let summary: String
    let rows: [OperationPreviewRow]
    let note: String
    let confirmLabel: String

    var actionLabel: String {
        switch kind {
        case .create: return "将创建"
        case .update: return "将修改"
        case .delete: return "将删除"
        case .external: return "将交接"
        case .save: return "将保存"
        }
    }

    static func pending(_ item: PendingTool) -> OperationPreview {
        let args = item.arguments
        let detail = ToolPresentation.detail(for: item)
        let row: (String, String?, String) -> OperationPreviewRow? = { id, value, icon in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return OperationPreviewRow(id: id, label: id, value: value, icon: icon)
        }

        let rows: [OperationPreviewRow]
        let kind: Kind
        switch item.tool {
        case "create_reminder":
            kind = .create
            rows = [
                row("内容", args.optionalString("title"), "text.alignleft"),
                row("时间", ToolPresentation.formatDateTime(args.optionalString("dueAt")), "clock"),
                row("列表", args.optionalString("listName"), "list.bullet")
            ].compactMap { $0 }
        case "update_reminder":
            kind = .update
            rows = [
                row("任务", args.optionalString("title") ?? args.optionalString("recordId"), "checklist"),
                row("新时间", ToolPresentation.formatDateTime(args.optionalString("dueAt")), "clock.arrow.circlepath"),
                row("状态", args.optionalBool("completed") == true ? "完成" : nil, "checkmark.circle"),
                row("新标题", args.optionalString("newTitle"), "pencil")
            ].compactMap { $0 }
        case "delete_reminder":
            kind = .delete
            rows = [
                row("待办", args.optionalString("title") ?? args.optionalString("recordId"), "checklist"),
                row("影响", "从系统提醒事项中移除", "trash")
            ].compactMap { $0 }
        case "create_calendar_event":
            kind = .create
            rows = [
                row("日程", args.optionalString("title"), "calendar"),
                row("开始", ToolPresentation.formatDateTime(args.optionalString("startAt")), "clock"),
                row("结束", ToolPresentation.formatDateTime(args.optionalString("endAt")), "clock.badge.checkmark")
            ].compactMap { $0 }
        case "update_calendar_event":
            kind = .update
            rows = [
                row("日程", args.optionalString("title") ?? args.optionalString("eventId"), "calendar"),
                row("新开始", ToolPresentation.formatDateTime(args.optionalString("startAt")), "clock.arrow.circlepath"),
                row("新结束", ToolPresentation.formatDateTime(args.optionalString("endAt")), "clock.badge.checkmark")
            ].compactMap { $0 }
        case "delete_calendar_event":
            kind = .delete
            rows = [
                row("日程", args.optionalString("title") ?? args.optionalString("eventId"), "calendar"),
                row("影响", "从系统日历中移除", "trash")
            ].compactMap { $0 }
        case "set_memory":
            kind = .save
            rows = [
                row("偏好", args.optionalString("key"), "brain.head.profile"),
                row("内容", args.optionalString("value"), "text.alignleft")
            ].compactMap { $0 }
        case "delete_memory":
            kind = .delete
            rows = [row("偏好", args.optionalString("key") ?? args.optionalString("id"), "brain.head.profile")].compactMap { $0 }
        case "open_navigation", "prepare_message", "open_netease_music":
            kind = .external
            rows = [row("操作", detail, ToolPresentation.icon(item.tool))].compactMap { $0 }
        default:
            kind = .update
            rows = [row("操作", detail, ToolPresentation.icon(item.tool))].compactMap { $0 }
        }

        return OperationPreview(
            kind: kind,
            title: ToolPresentation.title(item.tool),
            summary: detail,
            rows: rows,
            note: ToolPresentation.confirmationNote(item.tool),
            confirmLabel: ToolPresentation.confirmationAction(item.tool)
        )
    }

    static func todo(_ preview: TodoQuickPreview) -> OperationPreview {
        OperationPreview(
            kind: .create,
            title: "新建待办",
            summary: preview.title,
            rows: [
                OperationPreviewRow(id: "due", label: "时间", value: preview.dueText, icon: "calendar"),
                OperationPreviewRow(
                    id: "project",
                    label: "项目",
                    value: preview.project?.isEmpty == false ? (preview.project ?? "未分组") : "未分组",
                    icon: "square.stack.3d.up"
                ),
                OperationPreviewRow(id: "duration", label: "预计", value: preview.estimatedMinutes.map { "\($0) 分钟" } ?? "未设置", icon: "timer")
            ],
            note: "确认后写入系统提醒事项；可在完成后 8 秒内撤销。",
            confirmLabel: "确认添加"
        )
    }
}

final class AgentInteractionJournal {
    static let shared = AgentInteractionJournal()
    private let storageKey = "whale.interaction.receipts.v2"
    private let capacity = 30
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func list() -> [AgentOperationReceipt] {
        guard let data = defaults.data(forKey: storageKey),
              let rows = try? JSONDecoder().decode([AgentOperationReceipt].self, from: data) else {
            return []
        }
        return Array(rows.prefix(capacity))
    }

    func append(_ receipt: AgentOperationReceipt) {
        var rows = list()
        rows.removeAll { $0.id == receipt.id }
        rows.insert(receipt, at: 0)
        save(Array(rows.prefix(capacity)))
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }

    private func save(_ rows: [AgentOperationReceipt]) {
        guard let data = try? JSONEncoder().encode(rows) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

struct AssistantCommandItem: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case next
        case needsYou
        case resume
    }

    let id: String
    let kind: Kind
    let title: String
    let detail: String
    let isWarning: Bool
    let isActionable: Bool
}

enum AssistantCommandPlanner {
    static func items(
        now: Date,
        events: [CalendarEventPreview],
        todos: [TodoReminder],
        records: [TaskRecord],
        pendingConfirmation: PendingTool?
    ) -> [AssistantCommandItem] {
        let nextEvent = events
            .filter { $0.endAt > now }
            .sorted { $0.startAt < $1.startAt }
            .first
        let nextTodo = todos
            .filter { !$0.completed }
            .sorted { left, right in
                switch (left.dueAt, right.dueAt) {
                case let (lhs?, rhs?): return lhs < rhs
                case (_?, nil): return true
                case (nil, _?): return false
                default: return left.title < right.title
                }
            }
            .first

        let nextTitle: String
        let nextDetail: String
        if let nextEvent, let todo = nextTodo,
           let due = todo.dueAt, due < nextEvent.startAt {
            nextTitle = todo.title
            nextDetail = due.formatted(.dateTime.month().day().hour().minute()) + " 截止"
        } else if let nextEvent {
            nextTitle = nextEvent.title
            nextDetail = nextEvent.startAt.formatted(.dateTime.month().day().hour().minute())
        } else if let nextTodo {
            nextTitle = nextTodo.title
            nextDetail = nextTodo.dueAt?.formatted(.dateTime.month().day().hour().minute()) ?? "收件箱"
        } else {
            nextTitle = "今天暂时没有安排"
            nextDetail = "可以告诉鲸鱼接下来要做什么"
        }

        let failed = records.first { $0.status == "failed" || $0.status == "completed_with_limits" }
        let needsTitle: String
        let needsDetail: String
        let warning: Bool
        if let pendingConfirmation {
            needsTitle = ToolPresentation.title(pendingConfirmation.tool)
            needsDetail = "需要你确认后才会执行"
            warning = true
        } else if let failed {
            needsTitle = failed.goal
            needsDetail = failed.reply ?? "上一轮没有完成，可以继续核对"
            warning = true
        } else {
            needsTitle = "没有卡住的任务"
            needsDetail = "写操作仍会先给你看预览"
            warning = false
        }

        let latest = records.first
        return [
            AssistantCommandItem(
                id: "next",
                kind: .next,
                title: nextTitle,
                detail: nextDetail,
                isWarning: false,
                isActionable: nextEvent != nil || nextTodo != nil
            ),
            AssistantCommandItem(
                id: "needs-you",
                kind: .needsYou,
                title: needsTitle,
                detail: needsDetail,
                isWarning: warning,
                isActionable: warning
            ),
            AssistantCommandItem(
                id: "resume",
                kind: .resume,
                title: latest?.goal ?? "开始第一轮任务",
                detail: latest.map { $0.updatedAt.formatted(.relative(presentation: .named)) } ?? "任务记录会从这里继续",
                isWarning: false,
                isActionable: latest != nil
            )
        ]
    }
}
