import Foundation

enum WhaleWorkspaceHubMode: String, CaseIterable, Identifiable {
    case tasks
    case workspace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks: return "待办"
        case .workspace: return "资料"
        }
    }

    var icon: String {
        switch self {
        case .tasks: return "checklist"
        case .workspace: return "square.stack.3d.up.fill"
        }
    }

    static let defaultMode: WhaleWorkspaceHubMode = .tasks

    static func transition(
        _ mode: WhaleWorkspaceHubMode,
        action: WhaleWorkspaceHubAction
    ) -> WhaleWorkspaceHubMode {
        switch action {
        case .showTasks:
            return .tasks
        case .showWorkspace:
            return .workspace
        }
    }
}

enum WhaleWorkspaceHubAction {
    case showTasks
    case showWorkspace
}
