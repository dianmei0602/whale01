import Foundation

@main
struct HomeHeaderStateContract {
    static func main() {
        let idle = WhaleHomeHeaderPresentation.content(
            isPlayingMusic: false,
            trackTitle: nil
        )
        require(
            !idle.showsMusicIcon,
            "没有播放音乐时，首页页眉不应显示唱片图标"
        )
        require(
            idle.musicAccessibilityLabel == nil,
            "没有播放音乐时，首页页眉不应播报音乐状态"
        )

        let playing = WhaleHomeHeaderPresentation.content(
            isPlayingMusic: true,
            trackTitle: "晴天"
        )
        require(
            playing.showsMusicIcon,
            "播放音乐时，首页页眉必须显示唱片图标"
        )
        require(
            playing.musicAccessibilityLabel == "正在播放 晴天",
            "首页页眉的音乐图标必须向辅助功能说明当前曲目"
        )

        print("HOME_HEADER_STATE_CONTRACT_OK")
    }

    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
