import Foundation

enum TodoBoard: String, CaseIterable, Identifiable {
    case inbox
    case today
    case planned
    case projects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox: return "收件箱"
        case .today: return "今天"
        case .planned: return "计划"
        case .projects: return "项目"
        }
    }

    var icon: String {
        switch self {
        case .inbox: return "tray"
        case .today: return "calendar.day.timeline.left"
        case .planned: return "calendar.badge.clock"
        case .projects: return "square.stack.3d.up"
        }
    }

    func includes(_ item: TodoReminder, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard !item.completed else { return false }
        guard let due = item.dueAt else { return self == .inbox }
        if calendar.isDateInToday(due) || due < now { return self == .today }
        return self == .planned
    }
}

struct TodoMetadata: Codable, Equatable {
    var project: String?
    var priority: Int
    var estimatedMinutes: Int?
    var createdAt: Date
    var source: String

    init(
        project: String? = nil,
        priority: Int = 2,
        estimatedMinutes: Int? = nil,
        createdAt: Date = Date(),
        source: String = "local"
    ) {
        self.project = project
        self.priority = priority
        self.estimatedMinutes = estimatedMinutes
        self.createdAt = createdAt
        self.source = source
    }
}

final class TodoMetadataStore {
    static let shared = TodoMetadataStore()
    private let storageKey = "whale.todo.metadata.v2"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func metadata(for id: String) -> TodoMetadata {
        values()[id] ?? TodoMetadata(project: nil, priority: 2, estimatedMinutes: nil)
    }

    func set(_ metadata: TodoMetadata, for id: String) {
        var rows = values()
        rows[id] = metadata
        persist(rows)
    }

    func remove(_ id: String) {
        var rows = values()
        rows.removeValue(forKey: id)
        persist(rows)
    }

    private func values() -> [String: TodoMetadata] {
        guard let data = defaults.data(forKey: storageKey),
              let rows = try? JSONDecoder().decode([String: TodoMetadata].self, from: data) else {
            return [:]
        }
        return rows
    }

    private func persist(_ values: [String: TodoMetadata]) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

extension TodoReminder {
    var projectName: String? {
        let project = TodoMetadataStore.shared.metadata(for: id).project
        return project?.isEmpty == false ? project : nil
    }

    var priority: Int {
        TodoMetadataStore.shared.metadata(for: id).priority
    }

    var estimatedMinutes: Int? {
        TodoMetadataStore.shared.metadata(for: id).estimatedMinutes
    }
}

struct TodoQuickPreview: Equatable {
    let title: String
    let dueAt: Date?
    let project: String?
    let estimatedMinutes: Int?
    let originalText: String

    var dueText: String {
        dueAt?.formatted(.dateTime.month().day().hour().minute()) ?? "收件箱"
    }
}

extension TodoQuickParser {
    static func parsePreview(
        _ raw: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TodoQuickPreview {
        let added = parseAdd(raw, now: now, calendar: calendar)
        var title = added.title
        var project: String?
        if let match = firstMatch(pattern: #"(?:项目[:：]\s*|#)([^#，,。\s]{1,24})"#, in: title),
           let range = Range(match.range(at: 1), in: title) {
            project = String(title[range])
            title.removeSubrange(match.range(at: 0).range(in: title) ?? Range(match.range, in: title)!)
        }
        var estimate: Int?
        if let match = firstMatch(pattern: #"(?:预计|需要|大概|约)?\s*([0-9]{1,3})\s*分钟"#, in: title),
           let valueRange = Range(match.range(at: 1), in: title),
           let value = Int(title[valueRange]) {
            estimate = min(600, max(1, value))
            if let full = Range(match.range, in: title) {
                title.removeSubrange(full)
            }
        }
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: " ，,。.:："))
        return TodoQuickPreview(
            title: title.isEmpty ? added.title : title,
            dueAt: added.dueAt,
            project: project,
            estimatedMinutes: estimate,
            originalText: raw
        )
    }

    private static func firstMatch(pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
    }
}

extension NSRange {
    func range(in text: String) -> Range<String.Index>? {
        Range(self, in: text)
    }
}

struct TodoScheduleCandidate: Identifiable, Equatable {
    let start: Date
    let end: Date
    var id: Date { start }
}

enum TodoSchedulePlanner {
    static func candidates(
        for item: TodoReminder,
        events: [CalendarEventPreview],
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 3
    ) -> [TodoScheduleCandidate] {
        let minutes = max(15, item.estimatedMinutes ?? 30)
        let startOfToday = calendar.startOfDay(for: now)
        let dayStart = now > startOfToday.addingTimeInterval(8 * 3600)
            ? now.addingTimeInterval(15 * 60)
            : startOfToday.addingTimeInterval(9 * 3600)
        let dayEnd = startOfToday.addingTimeInterval(21 * 3600)
        let occupied = events
            .filter { $0.endAt > startOfToday && $0.startAt < dayEnd }
            .sorted { $0.startAt < $1.startAt }
        var cursor = dayStart
        var result: [TodoScheduleCandidate] = []
        for event in occupied {
            if let candidate = addCandidate(
                from: cursor,
                before: event.startAt,
                minutes: minutes,
                limit: dayEnd
            ) {
                result.append(candidate)
                if result.count >= limit { return result }
            }
            cursor = max(cursor, event.endAt.addingTimeInterval(10 * 60))
        }
        if let candidate = addCandidate(from: cursor, before: dayEnd, minutes: minutes, limit: dayEnd) {
            result.append(candidate)
        }
        return Array(result.prefix(limit))
    }

    private static func addCandidate(
        from start: Date,
        before boundary: Date,
        minutes: Int,
        limit: Date
    ) -> TodoScheduleCandidate? {
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        guard end <= min(boundary, limit) else { return nil }
        return TodoScheduleCandidate(start: start, end: end)
    }
}
