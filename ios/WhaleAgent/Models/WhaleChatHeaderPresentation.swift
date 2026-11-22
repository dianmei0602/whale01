import Foundation

struct WhaleChatHeaderState: Equatable {
    let statusText: String
    let showsMusicIcon: Bool
}

enum WhaleChatHeaderPresenter {
    static func content(
        isExecutingTool: Bool,
        isBusy: Bool,
        backendOnline: Bool,
        isPlayingMusic: Bool
    ) -> WhaleChatHeaderState {
        let statusText: String
        if isExecutingTool {
            statusText = "鲸鱼正在执行…"
        } else if isBusy {
            statusText = "鲸鱼正在处理…"
        } else if !backendOnline {
            statusText = "鲸鱼当前离线"
        } else {
            statusText = "鲸鱼随时在"
        }
        return WhaleChatHeaderState(
            statusText: statusText,
            showsMusicIcon: isPlayingMusic
        )
    }
}
