import Foundation

enum WhaleWorkspaceSurface: String, CaseIterable, Identifiable {
    case todos
    case notes
    case brief

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todos: return "待办"
        case .notes: return "记事"
        case .brief: return "晨晚报"
        }
    }

    var icon: String {
        switch self {
        case .todos: return "checklist"
        case .notes: return "note.text"
        case .brief: return "sun.horizon"
        }
    }

    var accessibilityIdentifier: String {
        "workspace-section-\(rawValue)"
    }
}
