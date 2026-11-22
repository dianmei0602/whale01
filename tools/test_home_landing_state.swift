import Foundation

@main
struct HomeLandingStateTest {
    static func main() {
        precondition(ConversationEntryMode.defaultMode == .home)
        precondition(
            ConversationEntryMode.transition(.home, action: .startChat) == .chat
        )
        precondition(
            ConversationEntryMode.transition(.chat, action: .returnHome) == .home
        )
        precondition(
            ConversationEntryMode.transition(.chat, action: .startChat) == .chat
        )
        precondition(
            ConversationEntryMode.transition(.home, action: .returnHome) == .home
        )
        print("HOME_LANDING_STATE_OK")
    }
}
