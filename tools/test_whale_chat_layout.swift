import Foundation

@main
struct WhaleChatLayoutTest {
    static func main() {
        let incoming = WhaleChatMessageLayout.resolve(isCurrentUser: false)
        precondition(incoming.side == .incoming)
        precondition(incoming.avatar == .whale)
        precondition(incoming.bubblePointsRight == false)
        precondition(incoming.avatarIsLeading)

        let outgoing = WhaleChatMessageLayout.resolve(isCurrentUser: true)
        precondition(outgoing.side == .outgoing)
        precondition(outgoing.avatar == .person)
        precondition(outgoing.bubblePointsRight)
        precondition(outgoing.avatarIsLeading == false)

        print("WHALE_CHAT_LAYOUT_OK")
    }
}
