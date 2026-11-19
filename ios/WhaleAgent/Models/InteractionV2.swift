import Foundation

enum AgentInteractionPhase: String, Codable, CaseIterable, Equatable {
    case idle
    case listening
    case editable
    case understanding
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
                isWarning: false
            ),
            AssistantCommandItem(
                id: "needs-you",
                kind: .needsYou,
                title: needsTitle,
                detail: needsDetail,
                isWarning: warning
            ),
            AssistantCommandItem(
                id: "resume",
                kind: .resume,
                title: latest?.goal ?? "开始第一轮任务",
                detail: latest.map { $0.updatedAt.formatted(.relative(presentation: .named)) } ?? "任务记录会从这里继续",
                isWarning: false
            )
        ]
    }
}
