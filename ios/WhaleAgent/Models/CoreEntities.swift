import Foundation

enum ChatRole: String, Codable {
    case user
    case assistant
    case tool
}

struct ResultLink: Identifiable, Equatable, Codable {
    let title: String
    let url: String

    var id: String { url }
}

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: ChatRole
    let text: String
    var detail: String?
    var places: [PlaceSummary] = []
    var links: [ResultLink]? = nil
    var weather: [WeatherDaySummary]? = nil
    var tool: String? = nil
    var executionStatus: String? = nil
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        detail: String? = nil,
        places: [PlaceSummary] = [],
        links: [ResultLink]? = nil,
        weather: [WeatherDaySummary]? = nil,
        tool: String? = nil,
        executionStatus: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.detail = detail
        self.places = places
        self.links = links
        self.weather = weather
        self.tool = tool
        self.executionStatus = executionStatus
        self.createdAt = createdAt
    }
}

struct TaskRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    var goal: String
    var conversationId: String
    var sourceMessageId: String? = nil
    var status: String
    var reply: String?
    let createdAt: Date
    var updatedAt: Date
    var executionState: JSONValue? = nil
}

struct TodoReminder: Identifiable, Equatable {
    let id: String
    let title: String
    let completed: Bool
    let listName: String
    let dueAt: Date?
    let notes: String?
    let deduplicated: Bool

    init(
        id: String,
        title: String,
        completed: Bool,
        listName: String,
        dueAt: Date?,
        notes: String?,
        deduplicated: Bool
    ) {
        self.id = id
        self.title = title
        self.completed = completed
        self.listName = listName
        self.dueAt = dueAt
        self.notes = notes
        self.deduplicated = deduplicated
    }

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

#if DEBUG
extension TodoReminder {
    static func demo(
        id: String,
        title: String,
        completed: Bool
    ) -> TodoReminder {
        TodoReminder(
            id: id,
            title: title,
            completed: completed,
            listName: "演示",
            dueAt: nil,
            notes: nil,
            deduplicated: false
        )
    }
}
#endif
