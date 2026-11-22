import Foundation

enum WhaleChatMessageSide: String, Equatable {
    case incoming
    case outgoing
}

enum WhaleChatAvatar: String, Equatable {
    case whale
    case person
}

struct WhaleChatMessageLayout: Equatable {
    let side: WhaleChatMessageSide
    let avatar: WhaleChatAvatar

    var bubblePointsRight: Bool {
        side == .outgoing
    }

    var avatarIsLeading: Bool {
        side == .incoming
    }

    static func resolve(isCurrentUser: Bool) -> WhaleChatMessageLayout {
        isCurrentUser
            ? WhaleChatMessageLayout(side: .outgoing, avatar: .person)
            : WhaleChatMessageLayout(side: .incoming, avatar: .whale)
    }
}
