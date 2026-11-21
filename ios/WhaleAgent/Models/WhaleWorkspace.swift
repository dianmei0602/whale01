import Combine
import Foundation

enum WorkspaceCaptureKind: String, Codable, CaseIterable, Identifiable {
    case note
    case link
    case document
    case image
    case chat
    case reading

    var id: String { rawValue }

    var title: String {
        switch self {
        case .note: return "记录"
        case .link: return "网页"
        case .document: return "文件"
        case .image: return "图片"
        case .chat: return "对话"
        case .reading: return "阅读"
        }
    }

    var icon: String {
        switch self {
        case .note: return "note.text"
        case .link: return "link"
        case .document: return "doc.text"
        case .image: return "photo"
        case .chat: return "bubble.left.and.text.bubble.right"
        case .reading: return "book"
        }
    }
}

struct WorkspaceCapture: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var body: String
    var kind: WorkspaceCaptureKind
    var sourceURL: String?
    var projectID: String?
    var isKnowledge: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct WorkspaceProject: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var summary: String
    let createdAt: Date
    var updatedAt: Date
}

struct WorkspaceFollowUp: Identifiable, Codable, Equatable {
    let id: String
    var subject: String
    var detail: String
    var dueAt: Date?
    var projectID: String?
    var isCompleted: Bool
    let createdAt: Date
    var updatedAt: Date
}

struct WorkspaceDailyReview: Identifiable, Codable, Equatable {
    let id: String
    var morningFocus: String
    var eveningNote: String
    let createdAt: Date
    var updatedAt: Date
}

enum WorkspaceFocusMode: String, Codable, CaseIterable, Identifiable {
    case commute
    case writing
    case workout
    case bedtime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commute: return "通勤"
        case .writing: return "写作"
        case .workout: return "运动"
        case .bedtime: return "睡前"
        }
    }

    var icon: String {
        switch self {
        case .commute: return "tram.fill"
        case .writing: return "square.and.pencil"
        case .workout: return "figure.run"
        case .bedtime: return "moon.stars.fill"
        }
    }

    var suggestion: String {
        switch self {
        case .commute:
            return "看下一项安排，只处理适合在路上完成的事。"
        case .writing:
            return "收起内容频道，把待办中的写作任务放到当前上下文。"
        case .workout:
            return "查看真实日程空档，不从健康数据推断你已经运动。"
        case .bedtime:
            return "回看今天真实完成和未完成的事项，再决定要不要阅读。"
        }
    }
}

struct WorkspaceFocusSession: Identifiable, Codable, Equatable {
    let id: String
    let mode: WorkspaceFocusMode
    let startedAt: Date
    var endedAt: Date?
}

private struct WhaleWorkspaceArchive: Codable {
    var captures: [WorkspaceCapture] = []
    var projects: [WorkspaceProject] = []
    var followUps: [WorkspaceFollowUp] = []
    var reviews: [String: WorkspaceDailyReview] = [:]
    var focusSessions: [WorkspaceFocusSession] = []
    var activeFocusMode: WorkspaceFocusMode?
    var focusStartedAt: Date?
}

@MainActor
final class WhaleWorkspaceStore: ObservableObject {
    static let shared = WhaleWorkspaceStore()

    @Published private(set) var captures: [WorkspaceCapture]
    @Published private(set) var projects: [WorkspaceProject]
    @Published private(set) var followUps: [WorkspaceFollowUp]
    @Published private(set) var focusSessions: [WorkspaceFocusSession]
    @Published private(set) var activeFocusMode: WorkspaceFocusMode?
    @Published private(set) var focusStartedAt: Date?

    private let defaults: UserDefaults
    private let storageKey: String
    private var reviews: [String: WorkspaceDailyReview]

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "whale.workspace.archive.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        let archive = Self.load(defaults: defaults, key: storageKey)
        captures = archive.captures
        projects = archive.projects
        followUps = archive.followUps
        reviews = archive.reviews
        focusSessions = archive.focusSessions
        activeFocusMode = archive.activeFocusMode
        focusStartedAt = archive.focusStartedAt
    }

    var inbox: [WorkspaceCapture] {
        captures
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var knowledge: [WorkspaceCapture] {
        captures
            .filter { $0.isKnowledge && !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var pendingFollowUps: [WorkspaceFollowUp] {
        followUps
            .filter { !$0.isCompleted }
            .sorted { left, right in
                (left.dueAt ?? .distantFuture) < (right.dueAt ?? .distantFuture)
            }
    }

    @discardableResult
    func capture(
        title: String,
        body: String,
        kind: WorkspaceCaptureKind,
        sourceURL: String? = nil,
        projectID: String? = nil,
        isKnowledge: Bool = false
    ) -> WorkspaceCapture {
        let cleanedBody = String(body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(12_000))
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = cleanedBody
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let item = WorkspaceCapture(
            id: UUID().uuidString,
            title: cleanedTitle.isEmpty ? String(fallback.prefix(36)) : String(cleanedTitle.prefix(120)),
            body: cleanedBody,
            kind: kind,
            sourceURL: sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines),
            projectID: cleanProjectID(projectID),
            isKnowledge: isKnowledge,
            isArchived: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        captures.insert(item, at: 0)
        trimStorage()
        persist()
        return item
    }

    @discardableResult
    func captureShared(
        text: String,
        url: String?,
        title: String?
    ) -> WorkspaceCapture {
        let kind: WorkspaceCaptureKind = (url?.isEmpty == false) ? .link : .note
        return capture(
            title: title ?? "",
            body: text,
            kind: kind,
            sourceURL: url
        )
    }

    func update(_ item: WorkspaceCapture) {
        guard let index = captures.firstIndex(where: { $0.id == item.id }) else { return }
        var next = item
        next.body = String(item.body.prefix(12_000))
        next.projectID = cleanProjectID(item.projectID)
        next.updatedAt = Date()
        captures[index] = next
        persist()
    }

    func toggleKnowledge(_ item: WorkspaceCapture) {
        guard let index = captures.firstIndex(where: { $0.id == item.id }) else { return }
        captures[index].isKnowledge.toggle()
        captures[index].updatedAt = Date()
        persist()
    }

    func archive(_ item: WorkspaceCapture) {
        guard let index = captures.firstIndex(where: { $0.id == item.id }) else { return }
        captures[index].isArchived.toggle()
        captures[index].updatedAt = Date()
        persist()
    }

    func delete(_ item: WorkspaceCapture) {
        captures.removeAll { $0.id == item.id }
        persist()
    }

    @discardableResult
    func addProject(name: String, summary: String = "") -> WorkspaceProject? {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let project = WorkspaceProject(
            id: UUID().uuidString,
            name: String(cleaned.prefix(40)),
            summary: String(summary.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240)),
            createdAt: Date(),
            updatedAt: Date()
        )
        projects.insert(project, at: 0)
        persist()
        return project
    }

    func assign(_ item: WorkspaceCapture, to projectID: String?) {
        var next = item
        next.projectID = projectID
        update(next)
    }

    @discardableResult
    func addFollowUp(
        subject: String,
        detail: String,
        dueAt: Date?,
        projectID: String? = nil
    ) -> WorkspaceFollowUp? {
        let cleaned = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let followUp = WorkspaceFollowUp(
            id: UUID().uuidString,
            subject: String(cleaned.prefix(120)),
            detail: String(detail.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_000)),
            dueAt: dueAt,
            projectID: cleanProjectID(projectID),
            isCompleted: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        followUps.insert(followUp, at: 0)
        persist()
        return followUp
    }

    func toggleFollowUp(_ item: WorkspaceFollowUp) {
        guard let index = followUps.firstIndex(where: { $0.id == item.id }) else { return }
        followUps[index].isCompleted.toggle()
        followUps[index].updatedAt = Date()
        persist()
    }

    func deleteFollowUp(_ item: WorkspaceFollowUp) {
        followUps.removeAll { $0.id == item.id }
        persist()
    }

    func searchKnowledge(_ query: String) -> [WorkspaceCapture] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return knowledge }
        return knowledge.filter { item in
            item.title.lowercased().contains(needle)
                || item.body.lowercased().contains(needle)
                || (item.sourceURL?.lowercased().contains(needle) ?? false)
        }
    }

    func searchAll(_ query: String) -> [WorkspaceCapture] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }
        return captures.filter { item in
            !item.isArchived && (
                item.title.lowercased().contains(needle)
                    || item.body.lowercased().contains(needle)
                    || (item.sourceURL?.lowercased().contains(needle) ?? false)
            )
        }
    }

    func review(on date: Date = Date()) -> WorkspaceDailyReview {
        let key = Self.dayKey(date)
        if let existing = reviews[key] { return existing }
        let review = WorkspaceDailyReview(
            id: key,
            morningFocus: "",
            eveningNote: "",
            createdAt: Date(),
            updatedAt: Date()
        )
        reviews[key] = review
        return review
    }

    func saveReview(
        _ current: WorkspaceDailyReview,
        morningFocus: String,
        eveningNote: String
    ) {
        var next = current
        next.morningFocus = String(morningFocus.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        next.eveningNote = String(eveningNote.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_200))
        next.updatedAt = Date()
        reviews[next.id] = next
        persist()
    }

    func startFocus(_ mode: WorkspaceFocusMode) {
        if let activeFocusMode, activeFocusMode != mode {
            endFocus()
        }
        activeFocusMode = mode
        focusStartedAt = Date()
        persist()
    }

    func endFocus() {
        guard let mode = activeFocusMode, let startedAt = focusStartedAt else { return }
        focusSessions.insert(
            WorkspaceFocusSession(
                id: UUID().uuidString,
                mode: mode,
                startedAt: startedAt,
                endedAt: Date()
            ),
            at: 0
        )
        if focusSessions.count > 40 {
            focusSessions.removeLast(focusSessions.count - 40)
        }
        activeFocusMode = nil
        focusStartedAt = nil
        persist()
    }

    private func cleanProjectID(_ value: String?) -> String? {
        guard let value, projects.contains(where: { $0.id == value }) else { return nil }
        return value
    }

    private func trimStorage() {
        if captures.count > 240 {
            captures.removeLast(captures.count - 240)
        }
        if followUps.count > 160 {
            followUps.removeLast(followUps.count - 160)
        }
    }

    private func persist() {
        let archive = WhaleWorkspaceArchive(
            captures: captures,
            projects: projects,
            followUps: followUps,
            reviews: reviews,
            focusSessions: focusSessions,
            activeFocusMode: activeFocusMode,
            focusStartedAt: focusStartedAt
        )
        guard let data = try? JSONEncoder().encode(archive) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func load(defaults: UserDefaults, key: String) -> WhaleWorkspaceArchive {
        guard let data = defaults.data(forKey: key),
              let archive = try? JSONDecoder().decode(WhaleWorkspaceArchive.self, from: data) else {
            return WhaleWorkspaceArchive()
        }
        return archive
    }

    private static func dayKey(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
