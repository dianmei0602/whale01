import Foundation

@main
struct ChatHeaderStateTest {
    static func main() {
        let idle = WhaleChatHeaderPresenter.content(
            isExecutingTool: false,
            isBusy: false,
            backendOnline: true,
            isPlayingMusic: false
        )
        precondition(idle.statusText == "鲸鱼随时在")
        precondition(!idle.showsMusicIcon)

        let playing = WhaleChatHeaderPresenter.content(
            isExecutingTool: false,
            isBusy: false,
            backendOnline: true,
            isPlayingMusic: true
        )
        precondition(playing.showsMusicIcon)

        let busy = WhaleChatHeaderPresenter.content(
            isExecutingTool: false,
            isBusy: true,
            backendOnline: true,
            isPlayingMusic: true
        )
        precondition(busy.statusText == "鲸鱼正在处理…")
        precondition(busy.showsMusicIcon)

        let offline = WhaleChatHeaderPresenter.content(
            isExecutingTool: false,
            isBusy: false,
            backendOnline: false,
            isPlayingMusic: false
        )
        precondition(offline.statusText == "鲸鱼当前离线")

        print("CHAT_HEADER_STATE_OK")
    }
}
