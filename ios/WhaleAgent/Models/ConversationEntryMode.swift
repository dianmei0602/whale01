import Foundation

enum ConversationEntryMode: Equatable {
    case home
    case chat

    static let defaultMode: ConversationEntryMode = .home

    static func transition(
        _ mode: ConversationEntryMode,
        action: ConversationEntryAction
    ) -> ConversationEntryMode {
        switch action {
        case .startChat:
            return .chat
        case .returnHome:
            return .home
        }
    }
}

enum ConversationEntryAction {
    case startChat
    case returnHome
}
